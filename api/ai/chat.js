// POST /api/ai/chat
// Full agentic budget assistant — full read/write access to all app data
const Anthropic = require('@anthropic-ai/sdk');
const sql = require('../_db');
const { setCors, handleOptions } = require('../_cors');

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

// ─── Tool definitions ──────────────────────────────────────────────────────────

const TOOLS = [
  // ── Budget allocation ──
  {
    name: 'assign_to_category',
    description: 'Assign (budget) money to a single category for the current month.',
    input_schema: {
      type: 'object',
      properties: {
        category_id: { type: 'string', description: 'UUID of the category' },
        amount_cents: { type: 'integer', description: 'Amount in cents (e.g. 50000 = $500.00)' },
        category_name: { type: 'string', description: 'Human-readable name for confirmation' },
      },
      required: ['category_id', 'amount_cents', 'category_name'],
    },
  },
  {
    name: 'bulk_assign',
    description: 'Assign money to multiple categories at once. Prefer this over repeated assign_to_category calls.',
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
    name: 'reset_month_allocations',
    description: 'Zero out all category allocations for the current month. Use with caution.',
    input_schema: { type: 'object', properties: {} },
  },

  // ── Categories ──
  {
    name: 'create_category',
    description: 'Create a new budget category inside an existing group.',
    input_schema: {
      type: 'object',
      properties: {
        group_id: { type: 'string', description: 'UUID of the parent group' },
        name: { type: 'string', description: 'Category name' },
        is_savings: { type: 'boolean', description: 'true if this is a savings goal' },
        due_day: { type: 'integer', description: 'Day of month payment is due (1-31), if recurring bill' },
        recurrence: { type: 'string', enum: ['monthly', 'yearly', 'once'], description: 'How often the bill recurs' },
        target_amount: { type: 'integer', description: 'Savings goal or known payment amount in cents' },
        notes: { type: 'string', description: 'Optional notes' },
      },
      required: ['group_id', 'name'],
    },
  },
  {
    name: 'update_category',
    description: 'Edit a category — rename it, change its group, toggle savings, set or clear due date, recurrence, target amount, or notes.',
    input_schema: {
      type: 'object',
      properties: {
        category_id: { type: 'string', description: 'UUID of the category to edit' },
        name: { type: 'string', description: 'New name (omit to keep current)' },
        group_id: { type: 'string', description: 'Move to a different group (omit to keep current)' },
        is_savings: { type: 'boolean', description: 'Toggle savings flag' },
        due_day: { type: ['integer', 'null'], description: 'Day of month (1-31), or null to clear' },
        recurrence: { type: ['string', 'null'], description: 'monthly/yearly/once, or null to clear' },
        target_amount: { type: ['integer', 'null'], description: 'Cents, or null to clear' },
        notes: { type: ['string', 'null'], description: 'Notes text, or null to clear' },
      },
      required: ['category_id'],
    },
  },
  {
    name: 'delete_category',
    description: 'Permanently delete a category. Any transactions assigned to it will become uncategorized.',
    input_schema: {
      type: 'object',
      properties: {
        category_id: { type: 'string', description: 'UUID of the category' },
        category_name: { type: 'string', description: 'Name for confirmation message' },
      },
      required: ['category_id', 'category_name'],
    },
  },

  // ── Category groups ──
  {
    name: 'create_category_group',
    description: 'Create a new top-level category group (e.g. "Housing", "Transportation").',
    input_schema: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Group name' },
      },
      required: ['name'],
    },
  },
  {
    name: 'update_category_group',
    description: 'Rename an existing category group.',
    input_schema: {
      type: 'object',
      properties: {
        group_id: { type: 'string', description: 'UUID of the group' },
        name: { type: 'string', description: 'New name for the group' },
      },
      required: ['group_id', 'name'],
    },
  },
  {
    name: 'delete_category_group',
    description: 'Delete a category group and all its categories. Use with caution.',
    input_schema: {
      type: 'object',
      properties: {
        group_id: { type: 'string', description: 'UUID of the group' },
        group_name: { type: 'string', description: 'Name for confirmation message' },
      },
      required: ['group_id', 'group_name'],
    },
  },

  // ── Accounts ──
  {
    name: 'create_account',
    description: 'Create a new financial account (checking, savings, credit card, or cash).',
    input_schema: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Account name' },
        type: { type: 'string', enum: ['checking', 'savings', 'credit_card', 'cash'], description: 'Account type' },
        starting_balance: { type: 'integer', description: 'Opening balance in cents (can be negative for credit cards with existing debt)' },
        is_savings_bucket: { type: 'boolean', description: 'true if this is a savings bucket (excluded from daily allowance)' },
      },
      required: ['name', 'type'],
    },
  },
  {
    name: 'update_account',
    description: 'Rename an account, change its type, or update its starting balance.',
    input_schema: {
      type: 'object',
      properties: {
        account_id: { type: 'string', description: 'UUID of the account' },
        name: { type: 'string', description: 'New name (omit to keep current)' },
        type: { type: 'string', enum: ['checking', 'savings', 'credit_card', 'cash'] },
        starting_balance: { type: 'integer', description: 'New starting balance in cents' },
        is_savings_bucket: { type: 'boolean' },
      },
      required: ['account_id'],
    },
  },
  {
    name: 'delete_account',
    description: 'Permanently delete an account and all its transactions.',
    input_schema: {
      type: 'object',
      properties: {
        account_id: { type: 'string', description: 'UUID of the account' },
        account_name: { type: 'string', description: 'Name for confirmation message' },
      },
      required: ['account_id', 'account_name'],
    },
  },

  // ── Transactions ──
  {
    name: 'create_transaction',
    description: 'Record a new financial transaction (spending or income).',
    input_schema: {
      type: 'object',
      properties: {
        account_id: { type: 'string', description: 'UUID of the account' },
        category_id: { type: 'string', description: 'UUID of the category (omit for income/transfers)' },
        payee_name: { type: 'string', description: 'Who was paid or paid you' },
        amount_cents: { type: 'integer', description: 'Positive for income, negative for spending' },
        date: { type: 'string', description: 'YYYY-MM-DD' },
        memo: { type: 'string', description: 'Optional note' },
        cleared: { type: 'boolean', description: 'true if transaction has cleared the bank' },
      },
      required: ['account_id', 'amount_cents', 'date'],
    },
  },
  {
    name: 'update_transaction',
    description: 'Edit an existing transaction — change amount, date, payee, category, memo, or cleared status.',
    input_schema: {
      type: 'object',
      properties: {
        transaction_id: { type: 'string', description: 'UUID of the transaction' },
        category_id: { type: ['string', 'null'], description: 'New category UUID, or null to uncategorize' },
        payee_name: { type: 'string', description: 'New payee name' },
        amount_cents: { type: 'integer', description: 'New amount in cents' },
        date: { type: 'string', description: 'New date YYYY-MM-DD' },
        memo: { type: 'string', description: 'New memo' },
        cleared: { type: 'boolean', description: 'Update cleared status' },
      },
      required: ['transaction_id'],
    },
  },
  {
    name: 'delete_transaction',
    description: 'Permanently delete a transaction.',
    input_schema: {
      type: 'object',
      properties: {
        transaction_id: { type: 'string', description: 'UUID of the transaction' },
        description: { type: 'string', description: 'Brief description for confirmation message' },
      },
      required: ['transaction_id', 'description'],
    },
  },
  {
    name: 'get_transactions',
    description: 'Fetch transaction history for analysis. Use when user asks about spending patterns or needs transaction IDs.',
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

// ─── Tool execution ────────────────────────────────────────────────────────────

async function executeTool(name, input, year, month) {
  const actions = [];
  let data = {};

  // ── Budget allocation ──

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

  else if (name === 'reset_month_allocations') {
    await sql`DELETE FROM category_months WHERE year = ${year} AND month = ${month}`;
    actions.push(`Reset all allocations for ${year}-${String(month).padStart(2,'0')}`);
    data = { success: true };
  }

  // ── Categories ──

  else if (name === 'create_category') {
    const [row] = await sql`
      INSERT INTO categories (group_id, name, is_savings, due_day, recurrence, target_amount, notes)
      VALUES (
        ${input.group_id},
        ${input.name},
        ${input.is_savings ?? false},
        ${input.due_day ?? null},
        ${input.recurrence ?? null},
        ${input.target_amount ?? null},
        ${input.notes ?? null}
      )
      RETURNING *
    `;
    actions.push(`Created category "${input.name}"`);
    data = row;
  }

  else if (name === 'update_category') {
    const [row] = await sql`
      UPDATE categories SET
        name          = COALESCE(${input.name ?? null}, name),
        group_id      = COALESCE(${input.group_id ?? null}::uuid, group_id),
        is_savings    = COALESCE(${input.is_savings ?? null}, is_savings),
        due_day       = CASE WHEN ${Object.hasOwn(input, 'due_day')} THEN ${input.due_day ?? null} ELSE due_day END,
        recurrence    = CASE WHEN ${Object.hasOwn(input, 'recurrence')} THEN ${input.recurrence ?? null} ELSE recurrence END,
        target_amount = CASE WHEN ${Object.hasOwn(input, 'target_amount')} THEN ${input.target_amount ?? null} ELSE target_amount END,
        notes         = CASE WHEN ${Object.hasOwn(input, 'notes')} THEN ${input.notes ?? null} ELSE notes END
      WHERE id = ${input.category_id}
      RETURNING *
    `;
    if (!row) throw new Error(`Category ${input.category_id} not found`);
    actions.push(`Updated category "${row.name}"`);
    data = row;
  }

  else if (name === 'delete_category') {
    await sql`DELETE FROM categories WHERE id = ${input.category_id}`;
    actions.push(`Deleted category "${input.category_name}"`);
    data = { success: true };
  }

  // ── Category groups ──

  else if (name === 'create_category_group') {
    const [existing] = await sql`SELECT MAX(sort_order) AS max FROM category_groups`;
    const sortOrder = (parseInt(existing.max) || -1) + 1;
    const [row] = await sql`
      INSERT INTO category_groups (name, sort_order) VALUES (${input.name}, ${sortOrder}) RETURNING *
    `;
    actions.push(`Created group "${input.name}"`);
    data = row;
  }

  else if (name === 'update_category_group') {
    const [row] = await sql`
      UPDATE category_groups SET name = ${input.name} WHERE id = ${input.group_id} RETURNING *
    `;
    if (!row) throw new Error(`Group ${input.group_id} not found`);
    actions.push(`Renamed group to "${input.name}"`);
    data = row;
  }

  else if (name === 'delete_category_group') {
    await sql`DELETE FROM category_groups WHERE id = ${input.group_id}`;
    actions.push(`Deleted group "${input.group_name}" and all its categories`);
    data = { success: true };
  }

  // ── Accounts ──

  else if (name === 'create_account') {
    const [existing] = await sql`SELECT MAX(sort_order) AS max FROM accounts`;
    const sortOrder = (parseInt(existing.max) || -1) + 1;
    const [row] = await sql`
      INSERT INTO accounts (name, type, starting_balance, is_savings_bucket, sort_order)
      VALUES (
        ${input.name},
        ${input.type},
        ${input.starting_balance ?? 0},
        ${input.is_savings_bucket ?? false},
        ${sortOrder}
      )
      RETURNING *
    `;
    actions.push(`Created account "${input.name}" (${input.type})`);
    data = row;
  }

  else if (name === 'update_account') {
    const [row] = await sql`
      UPDATE accounts SET
        name             = COALESCE(${input.name ?? null}, name),
        type             = COALESCE(${input.type ?? null}, type),
        starting_balance = COALESCE(${input.starting_balance ?? null}, starting_balance),
        is_savings_bucket = COALESCE(${input.is_savings_bucket ?? null}, is_savings_bucket)
      WHERE id = ${input.account_id}
      RETURNING *
    `;
    if (!row) throw new Error(`Account ${input.account_id} not found`);
    actions.push(`Updated account "${row.name}"`);
    data = row;
  }

  else if (name === 'delete_account') {
    await sql`DELETE FROM accounts WHERE id = ${input.account_id}`;
    actions.push(`Deleted account "${input.account_name}"`);
    data = { success: true };
  }

  // ── Transactions ──

  else if (name === 'create_transaction') {
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
      VALUES (
        ${input.account_id}, ${input.category_id ?? null}, ${payee_id},
        ${input.payee_name ?? null}, ${input.amount_cents}, ${input.date}::date,
        ${input.memo ?? null}, ${input.cleared ?? false}
      )
      RETURNING *
    `;
    const sign = input.amount_cents >= 0 ? '+' : '';
    actions.push(`Recorded transaction: ${input.payee_name ?? 'Unknown'} ${sign}${formatCents(input.amount_cents)}`);
    data = tx;
  }

  else if (name === 'update_transaction') {
    const updates = {};
    if (input.amount_cents !== undefined) updates.amount = input.amount_cents;
    if (input.date !== undefined) updates.date = input.date;
    if (input.memo !== undefined) updates.memo = input.memo;
    if (input.cleared !== undefined) updates.cleared = input.cleared;

    // Handle payee update
    let payee_id;
    if (input.payee_name !== undefined) {
      if (input.payee_name) {
        const [p] = await sql`
          INSERT INTO payees (name) VALUES (${input.payee_name})
          ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name RETURNING id
        `;
        payee_id = p.id;
      } else {
        payee_id = null;
      }
    }

    const [tx] = await sql`
      UPDATE transactions SET
        category_id = CASE WHEN ${Object.hasOwn(input, 'category_id')} THEN ${input.category_id ?? null}::uuid ELSE category_id END,
        payee_id    = CASE WHEN ${Object.hasOwn(input, 'payee_name')} THEN ${payee_id ?? null}::uuid ELSE payee_id END,
        payee_name  = CASE WHEN ${Object.hasOwn(input, 'payee_name')} THEN ${input.payee_name ?? null} ELSE payee_name END,
        amount      = COALESCE(${input.amount_cents ?? null}, amount),
        date        = COALESCE(${input.date ? `${input.date}::date` : null}, date),
        memo        = COALESCE(${input.memo ?? null}, memo),
        cleared     = COALESCE(${input.cleared ?? null}, cleared)
      WHERE id = ${input.transaction_id}
      RETURNING *
    `;
    if (!tx) throw new Error(`Transaction ${input.transaction_id} not found`);
    actions.push(`Updated transaction ${formatCents(tx.amount)} on ${tx.date}`);
    data = tx;
  }

  else if (name === 'delete_transaction') {
    await sql`DELETE FROM transactions WHERE id = ${input.transaction_id}`;
    actions.push(`Deleted transaction: ${input.description}`);
    data = { success: true };
  }

  else if (name === 'get_transactions') {
    const rows = await sql`
      SELECT t.*, a.name AS account_name, c.name AS category_name,
             COALESCE(t.payee_name, p.name) AS payee_display_name
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

// ─── Context builder ───────────────────────────────────────────────────────────

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
      FROM accounts a LEFT JOIN transactions t ON t.account_id = a.id
      GROUP BY a.id ORDER BY a.sort_order
    `,
    sql`
      SELECT t.id, t.amount, t.date, t.memo, t.cleared,
             a.name AS account_name, a.id AS account_id,
             c.name AS category_name, c.id AS category_id,
             COALESCE(t.payee_name, p.name) AS payee_name
      FROM transactions t
      LEFT JOIN accounts a ON a.id = t.account_id
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN payees p ON p.id = t.payee_id
      ORDER BY t.date DESC, t.created_at DESC LIMIT 30
    `,
  ]);

  const [totalInflow] = await sql`SELECT COALESCE(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END),0) AS v FROM transactions`;
  const [totalStarting] = await sql`SELECT COALESCE(SUM(starting_balance),0) AS v FROM accounts`;
  const [totalAllocated] = await sql`SELECT COALESCE(SUM(allocated),0) AS v FROM category_months`;
  const readyToAssign = parseInt(totalStarting.v) + parseInt(totalInflow.v) - parseInt(totalAllocated.v);

  return { budgetRows, accounts, recentTxs, readyToAssign };
}

function buildSystemPrompt({ budgetRows, accounts, recentTxs, readyToAssign }, year, month) {
  const today = new Date();
  const monthName = new Date(year, month - 1, 1).toLocaleString('en-US', { month: 'long', year: 'numeric' });

  // Budget section
  const groupMap = new Map();
  for (const r of budgetRows) {
    if (!groupMap.has(r.group_id)) {
      groupMap.set(r.group_id, { id: r.group_id, name: r.group_name, categories: [] });
    }
    if (r.category_id) {
      const available = parseInt(r.allocated) + parseInt(r.activity);
      groupMap.get(r.group_id).categories.push({
        id: r.category_id, name: r.category_name, is_savings: r.is_savings,
        due_day: r.due_day, recurrence: r.recurrence,
        target_amount: r.target_amount ? parseInt(r.target_amount) : null,
        notes: r.notes,
        allocated: parseInt(r.allocated), activity: parseInt(r.activity), available,
      });
    }
  }

  let budgetText = '';
  const bills = [];

  for (const [, g] of groupMap) {
    budgetText += `\n[Group: ${g.name}  id:${g.id}]\n`;
    for (const c of g.categories) {
      const dueStr = c.due_day ? ` due:${c.due_day}${c.recurrence ? '/'+c.recurrence : ''}` : '';
      const targetStr = c.target_amount ? ` goal:${formatCents(c.target_amount)}` : '';
      const savingsStr = c.is_savings ? ' [savings]' : '';
      const notesStr = c.notes ? ` note:"${c.notes}"` : '';
      const statusStr = c.available < 0 ? ' ⚠️OVERSPENT' : '';
      budgetText += `  • ${c.name}${savingsStr}${dueStr}${targetStr}${notesStr}  assigned:${formatCents(c.allocated)} activity:${formatCents(c.activity)} available:${formatCents(c.available)}${statusStr}  [id:${c.id}]\n`;
      if (c.due_day) bills.push(c);
    }
  }

  // Upcoming bills
  const todayDay = today.getDate();
  bills.sort((a, b) => {
    const da = a.due_day >= todayDay ? a.due_day - todayDay : 31 - todayDay + a.due_day;
    const db = b.due_day >= todayDay ? b.due_day - todayDay : 31 - todayDay + b.due_day;
    return da - db;
  });
  const billsText = bills.map(b => {
    const daysUntil = b.due_day >= todayDay ? b.due_day - todayDay : 31 - todayDay + b.due_day;
    return `  • ${b.name}: due day ${b.due_day} (${daysUntil === 0 ? 'TODAY' : `in ${daysUntil}d`})  assigned:${formatCents(b.allocated)} available:${formatCents(b.available)}  [id:${b.id}]`;
  }).join('\n');

  const accountText = accounts.map(a =>
    `  • ${a.name} (${a.type}${a.is_savings_bucket ? ', savings bucket' : ''})  balance:${formatCents(parseInt(a.balance))}  [id:${a.id}]`
  ).join('\n');

  const txText = recentTxs.slice(0, 20).map(t =>
    `  ${t.date} | ${t.payee_name ?? 'No payee'} | ${t.category_name ?? 'Uncategorized'} | ${formatCents(t.amount)} | acct:${t.account_name}  [id:${t.id}]`
  ).join('\n');

  return `You are a smart, proactive personal budget assistant with FULL control over the user's budget app.

Today: ${today.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}.
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

═══ FULL CAPABILITIES ═══
You have complete read/write access to everything in this budget app:

BUDGET: assign_to_category, bulk_assign, reset_month_allocations
CATEGORIES: create_category, update_category, delete_category
GROUPS: create_category_group, update_category_group, delete_category_group
ACCOUNTS: create_account, update_account, delete_account
TRANSACTIONS: create_transaction, update_transaction, delete_transaction, get_transactions

RULES:
- When asked to DO something, USE THE TOOLS immediately — don't just explain.
- Always confirm what you did after taking actions.
- Be friendly and concise, not overly formal.
- For bulk changes, use bulk_assign instead of repeated single calls.
- IDs are shown in brackets [id:...] throughout this context — use them.
- All monetary amounts in tools are in CENTS (dollars × 100).
- If unsure about a destructive action (delete), ask for confirmation first.`;
}

// ─── Main handler ──────────────────────────────────────────────────────────────

module.exports = async (req, res) => {
  setCors(res);
  if (handleOptions(req, res)) return;
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const { messages = [], year, month } = req.body;
  if (!year || !month) return res.status(400).json({ error: 'year and month required' });

  try {
    const context = await fetchContext(year, month);
    const systemPrompt = buildSystemPrompt(context, year, month);

    const apiMessages = messages.map(m => ({ role: m.role, content: m.content }));
    const actionsLog = [];

    // Agentic loop — Claude calls tools, we execute, repeat until done
    let finalText = '';
    let loopCount = 0;

    while (loopCount < 8) {
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
            try {
              const result = await executeTool(block.name, block.input, year, month);
              actionsLog.push(...result.actions);
              toolResults.push({
                type: 'tool_result',
                tool_use_id: block.id,
                content: JSON.stringify(result.data),
              });
            } catch (toolErr) {
              toolResults.push({
                type: 'tool_result',
                tool_use_id: block.id,
                is_error: true,
                content: `Error: ${toolErr.message}`,
              });
            }
          }
        }
        apiMessages.push({ role: 'assistant', content: response.content });
        apiMessages.push({ role: 'user', content: toolResults });
      } else {
        finalText = response.content.filter(b => b.type === 'text').map(b => b.text).join('');
        break;
      }
    }

    if (!finalText) {
      finalText = actionsLog.length > 0
        ? `Done! Here's what I did:\n${actionsLog.map(a => `• ${a}`).join('\n')}`
        : "I wasn't able to complete that request. Please try again or rephrase your question.";
    }

    // Determine what needs refreshing on the client
    const refreshBudget = actionsLog.some(a =>
      a.startsWith('Assigned') || a.startsWith('Created') || a.startsWith('Updated') ||
      a.startsWith('Deleted') || a.startsWith('Renamed') || a.startsWith('Reset')
    );
    const refreshTransactions = actionsLog.some(a =>
      a.startsWith('Recorded') || a.startsWith('Updated transaction') || a.startsWith('Deleted transaction')
    );
    const refreshAccounts = actionsLog.some(a =>
      a.includes('account')
    );

    res.status(200).json({
      content: finalText,
      actions_taken: actionsLog,
      refresh_budget: refreshBudget,
      refresh_transactions: refreshTransactions,
      refresh_accounts: refreshAccounts,
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
