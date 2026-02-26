// POST /api/ai/chat
// Full agentic budget assistant — Claude can read your budget AND take actions on it
const Anthropic = require('@anthropic-ai/sdk');
const sql = require('../_db');
const { setCors, handleOptions } = require('../_cors');

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

// ─── Tool definitions ─────────────────────────────────────────────────────────

const TOOLS = [
  {
    name: 'assign_to_category',
    description: 'Assign (budget) money to a single category for the current month. Use this to set how much is budgeted for a category.',
    input_schema: {
      type: 'object',
      properties: {
        category_id: { type: 'string', description: 'UUID of the category' },
        amount_cents: { type: 'integer', description: 'Amount in cents (e.g. 50000 = $500.00)' },
        category_name: { type: 'string', description: 'Human-readable name for the confirmation message' },
      },
      required: ['category_id', 'amount_cents', 'category_name'],
    },
  },
  {
    name: 'bulk_assign',
    description: 'Assign money to multiple categories at once. Useful for "distribute my budget" type requests.',
    input_schema: {
      type: 'object',
      properties: {
        assignments: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              category_id: { type: 'string' },
              amount_cents: { type: 'integer' },
              category_name: { type: 'string' },
            },
            required: ['category_id', 'amount_cents', 'category_name'],
          },
        },
      },
      required: ['assignments'],
    },
  },
  {
    name: 'create_transaction',
    description: 'Record a new financial transaction (spending or income).',
    input_schema: {
      type: 'object',
      properties: {
        account_id: { type: 'string', description: 'UUID of the account' },
        category_id: { type: 'string', description: 'UUID of the category (null for income)' },
        payee_name: { type: 'string', description: 'Who was paid or paid you' },
        amount_cents: { type: 'integer', description: 'Positive for income, negative for spending' },
        date: { type: 'string', description: 'YYYY-MM-DD format' },
        memo: { type: 'string', description: 'Optional note' },
      },
      required: ['account_id', 'amount_cents', 'date'],
    },
  },
  {
    name: 'get_transactions',
    description: 'Fetch transaction history for analysis. Use when the user asks about spending patterns.',
    input_schema: {
      type: 'object',
      properties: {
        category_id: { type: 'string', description: 'Filter by category UUID' },
        account_id: { type: 'string', description: 'Filter by account UUID' },
        year: { type: 'integer' },
        month: { type: 'integer', description: '1-12' },
      },
    },
  },
];

// ─── Tool execution ───────────────────────────────────────────────────────────

async function executeTool(name, input, year, month) {
  const actions = [];
  let data = {};

  if (name === 'assign_to_category') {
    await sql`
      INSERT INTO category_months (category_id, year, month, allocated)
      VALUES (${input.category_id}, ${year}, ${month}, ${input.amount_cents})
      ON CONFLICT (category_id, year, month) DO UPDATE SET allocated = EXCLUDED.allocated
    `;
    const label = `Assigned ${formatCents(input.amount_cents)} to ${input.category_name}`;
    actions.push(label);
    data = { success: true, message: label };
  }

  else if (name === 'bulk_assign') {
    for (const a of input.assignments) {
      await sql`
        INSERT INTO category_months (category_id, year, month, allocated)
        VALUES (${a.category_id}, ${year}, ${month}, ${a.amount_cents})
        ON CONFLICT (category_id, year, month) DO UPDATE SET allocated = EXCLUDED.allocated
      `;
      actions.push(`Assigned ${formatCents(a.amount_cents)} to ${a.category_name}`);
    }
    data = { success: true, count: input.assignments.length };
  }

  else if (name === 'create_transaction') {
    // Upsert payee
    let payee_id = null;
    if (input.payee_name) {
      const [p] = await sql`
        INSERT INTO payees (name) VALUES (${input.payee_name})
        ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name RETURNING id
      `;
      payee_id = p.id;
    }
    const [tx] = await sql`
      INSERT INTO transactions (account_id, category_id, payee_id, payee_name, amount, date, memo, cleared)
      VALUES (${input.account_id}, ${input.category_id ?? null}, ${payee_id}, ${input.payee_name ?? null},
              ${input.amount_cents}, ${input.date}::date, ${input.memo ?? null}, FALSE)
      RETURNING *
    `;
    const sign = input.amount_cents >= 0 ? '+' : '';
    actions.push(`Recorded transaction: ${input.payee_name ?? 'Unknown'} ${sign}${formatCents(input.amount_cents)}`);
    data = tx;
  }

  else if (name === 'get_transactions') {
    const rows = await sql`
      SELECT t.*, a.name AS account_name, c.name AS category_name,
             COALESCE(t.payee_name, p.name) AS payee_name
      FROM transactions t
      LEFT JOIN accounts a ON a.id = t.account_id
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN payees p ON p.id = t.payee_id
      WHERE (${input.category_id ?? null}::uuid IS NULL OR t.category_id = ${input.category_id ?? null}::uuid)
        AND (${input.account_id ?? null}::uuid IS NULL OR t.account_id = ${input.account_id ?? null}::uuid)
        AND (${input.year ?? null}::int IS NULL OR EXTRACT(YEAR FROM t.date) = ${input.year ?? null}::int)
        AND (${input.month ?? null}::int IS NULL OR EXTRACT(MONTH FROM t.date) = ${input.month ?? null}::int)
      ORDER BY t.date DESC LIMIT 100
    `;
    data = rows;
  }

  return { actions, data };
}

// ─── Context builders ─────────────────────────────────────────────────────────

async function fetchContext(year, month) {
  const [budgetRows, accounts, recentTxs] = await Promise.all([
    sql`
      SELECT cg.id AS group_id, cg.name AS group_name, cg.sort_order AS group_sort,
             c.id AS category_id, c.name AS category_name, c.is_savings,
             c.due_day, c.recurrence, c.target_amount, c.notes,
             COALESCE(cm.allocated, 0) AS allocated,
             COALESCE(SUM(t.amount), 0) AS activity
      FROM category_groups cg
      LEFT JOIN categories c ON c.group_id = cg.id
      LEFT JOIN category_months cm ON cm.category_id = c.id AND cm.year = ${year} AND cm.month = ${month}
      LEFT JOIN transactions t ON t.category_id = c.id
        AND EXTRACT(YEAR FROM t.date) = ${year}
        AND EXTRACT(MONTH FROM t.date) = ${month}
      GROUP BY cg.id, cg.name, cg.sort_order, c.id, c.name, c.is_savings,
               c.due_day, c.recurrence, c.target_amount, c.notes, cm.allocated
      ORDER BY cg.sort_order, c.sort_order
    `,
    sql`
      SELECT a.*, COALESCE(a.starting_balance + SUM(t.amount), a.starting_balance) AS balance
      FROM accounts a LEFT JOIN transactions t ON t.account_id = a.id GROUP BY a.id ORDER BY a.sort_order
    `,
    sql`
      SELECT t.*, a.name AS account_name, c.name AS category_name,
             COALESCE(t.payee_name, p.name) AS payee_name
      FROM transactions t
      LEFT JOIN accounts a ON a.id = t.account_id
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN payees p ON p.id = t.payee_id
      ORDER BY t.date DESC, t.created_at DESC LIMIT 30
    `,
  ]);

  const [totalInflow] = await sql`SELECT COALESCE(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END),0) AS v FROM transactions`;
  const [totalAllocated] = await sql`SELECT COALESCE(SUM(allocated),0) AS v FROM category_months`;
  const readyToAssign = parseInt(totalInflow.v) - parseInt(totalAllocated.v);

  return { budgetRows, accounts, recentTxs, readyToAssign };
}

function buildSystemPrompt({ budgetRows, accounts, recentTxs, readyToAssign }, year, month) {
  const today = new Date();
  const monthName = new Date(year, month - 1, 1).toLocaleString('en-US', { month: 'long', year: 'numeric' });

  // Build budget section
  const groupMap = new Map();
  for (const r of budgetRows) {
    if (!groupMap.has(r.group_id)) groupMap.set(r.group_id, { name: r.group_name, categories: [] });
    if (r.category_id) {
      const available = parseInt(r.allocated) + parseInt(r.activity);
      groupMap.get(r.group_id).categories.push({
        id: r.category_id, name: r.category_name, is_savings: r.is_savings,
        due_day: r.due_day, recurrence: r.recurrence, target_amount: r.target_amount, notes: r.notes,
        allocated: parseInt(r.allocated), activity: parseInt(r.activity), available,
      });
    }
  }

  let budgetText = '';
  let billsText = '';
  const bills = [];

  for (const [, g] of groupMap) {
    budgetText += `\n${g.name}:\n`;
    for (const c of g.categories) {
      const dueStr = c.due_day ? ` [due: ${c.due_day}${c.recurrence ? ', ' + c.recurrence : ''}]` : '';
      const targetStr = c.target_amount ? ` [goal: ${formatCents(c.target_amount)}]` : '';
      const statusStr = c.available < 0 ? ' ⚠️ OVERSPENT' : '';
      budgetText += `  • ${c.name}${dueStr}${targetStr}: assigned ${formatCents(c.allocated)}, activity ${formatCents(c.activity)}, available ${formatCents(c.available)}${statusStr}  [id: ${c.id}]\n`;
      if (c.due_day) bills.push(c);
    }
  }

  // Sort bills by days until due
  const todayDay = today.getDate();
  bills.sort((a, b) => {
    const daysA = a.due_day >= todayDay ? a.due_day - todayDay : 31 - todayDay + a.due_day;
    const daysB = b.due_day >= todayDay ? b.due_day - todayDay : 31 - todayDay + b.due_day;
    return daysA - daysB;
  });
  for (const b of bills) {
    const daysUntil = b.due_day >= todayDay ? b.due_day - todayDay : 31 - todayDay + b.due_day;
    billsText += `  • ${b.name}: due day ${b.due_day} (${daysUntil === 0 ? 'TODAY' : `in ${daysUntil} days`}), assigned ${formatCents(b.allocated)}, available ${formatCents(b.available)}\n`;
  }

  const accountText = accounts.map(a =>
    `  • ${a.name} (${a.type}): ${formatCents(parseInt(a.balance))}`
  ).join('\n');

  const txText = recentTxs.slice(0, 20).map(t =>
    `  ${t.date} | ${t.payee_name ?? 'No payee'} | ${t.category_name ?? 'Uncategorized'} | ${formatCents(t.amount)}`
  ).join('\n');

  return `You are a smart, proactive personal budget assistant built directly into a YNAB-style budgeting app.

Today is ${today.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}.
Current budget month: ${monthName}.

═══ FINANCIAL SNAPSHOT ═══
💰 Ready to Assign: ${formatCents(readyToAssign)}${readyToAssign < 0 ? ' ⚠️ OVER-BUDGETED' : ''}

ACCOUNTS:
${accountText || '  (none yet)'}

═══ BUDGET — ${monthName} ═══
${budgetText || '  (no categories yet)'}
${bills.length > 0 ? `\n═══ UPCOMING BILLS ═══\n${billsText}` : ''}
═══ RECENT TRANSACTIONS (last 20) ═══
${txText || '  (none yet)'}

═══ YOUR CAPABILITIES ═══
You can:
1. Answer questions about spending, balances, trends
2. Assign money to categories using assign_to_category or bulk_assign tools
3. Record transactions with create_transaction
4. Analyze spending patterns with get_transactions
5. Give budget advice based on upcoming bills and available money

IMPORTANT RULES:
- When the user asks you to DO something (assign money, record a transaction), USE THE TOOLS — don't just describe what to do.
- After taking actions, confirm clearly what you did (e.g., "Done! Assigned $500 to Rent and $80 to Internet.")
- Be conversational and friendly, not overly formal.
- If asked to "cover bills" or "fund upcoming bills", use bulk_assign to fill each bill category up to its needed amount from ready_to_assign.
- All amounts in tools are in CENTS (multiply dollars by 100).`;
}

// ─── Main handler ─────────────────────────────────────────────────────────────

module.exports = async (req, res) => {
  setCors(res);
  if (handleOptions(req, res)) return;
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const { messages = [], year, month } = req.body;
  if (!year || !month) return res.status(400).json({ error: 'year and month required' });

  try {
    const context = await fetchContext(year, month);
    const systemPrompt = buildSystemPrompt(context, year, month);

    // Convert iOS messages to Anthropic format
    const apiMessages = messages.map(m => ({ role: m.role, content: m.content }));
    const actionsLog = [];

    // Agentic loop — Claude calls tools, we execute them, repeat until done
    let finalText = '';
    let loopCount = 0;

    while (loopCount < 5) {
      loopCount++;
      const response = await anthropic.messages.create({
        model: 'claude-sonnet-4-6',
        max_tokens: 2048,
        system: systemPrompt,
        tools: TOOLS,
        messages: apiMessages,
      });

      if (response.stop_reason === 'end_turn') {
        finalText = response.content.filter(b => b.type === 'text').map(b => b.text).join('');
        break;
      }

      if (response.stop_reason === 'tool_use') {
        const toolResults = [];
        for (const block of response.content) {
          if (block.type === 'tool_use') {
            const result = await executeTool(block.name, block.input, year, month);
            actionsLog.push(...result.actions);
            toolResults.push({
              type: 'tool_result',
              tool_use_id: block.id,
              content: JSON.stringify(result.data),
            });
          }
        }
        // Add assistant turn (with tool calls) and user turn (with tool results)
        apiMessages.push({ role: 'assistant', content: response.content });
        apiMessages.push({ role: 'user', content: toolResults });
      } else {
        // max_tokens or unexpected stop — grab whatever text we have
        finalText = response.content.filter(b => b.type === 'text').map(b => b.text).join('');
        break;
      }
    }

    res.status(200).json({
      content: finalText,
      actions_taken: actionsLog,
      refresh_budget: actionsLog.some(a => a.startsWith('Assigned')),
      refresh_transactions: actionsLog.some(a => a.startsWith('Recorded')),
    });
  } catch (err) {
    console.error('AI chat error:', err);
    res.status(500).json({ error: err.message });
  }
};

function formatCents(cents) {
  const n = parseInt(cents) || 0;
  const abs = Math.abs(n) / 100;
  const str = abs.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  return n < 0 ? `-$${str}` : `$${str}`;
}
