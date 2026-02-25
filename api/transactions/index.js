// GET /api/transactions        — list transactions (supports ?account_id=, ?category_id=, ?year=, ?month=)
// POST /api/transactions       — create transaction
const sql = require('../_db');
const { setCors, handleOptions } = require('../_cors');

module.exports = async (req, res) => {
  setCors(res);
  if (handleOptions(req, res)) return;

  try {
    if (req.method === 'GET') {
      const { account_id, category_id, year, month } = req.query;

      // Build dynamic filter conditions
      const transactions = await sql`
        SELECT
          t.id,
          t.account_id,
          a.name AS account_name,
          t.category_id,
          c.name AS category_name,
          cg.name AS category_group_name,
          t.payee_id,
          COALESCE(t.payee_name, p.name) AS payee_name,
          t.amount,
          t.date,
          t.memo,
          t.cleared,
          t.created_at
        FROM transactions t
        LEFT JOIN accounts a ON a.id = t.account_id
        LEFT JOIN categories c ON c.id = t.category_id
        LEFT JOIN category_groups cg ON cg.id = c.group_id
        LEFT JOIN payees p ON p.id = t.payee_id
        WHERE
          (${account_id ?? null}::uuid IS NULL OR t.account_id = ${account_id ?? null}::uuid)
          AND (${category_id ?? null}::uuid IS NULL OR t.category_id = ${category_id ?? null}::uuid)
          AND (${year ?? null}::int IS NULL OR EXTRACT(YEAR FROM t.date) = ${year ?? null}::int)
          AND (${month ?? null}::int IS NULL OR EXTRACT(MONTH FROM t.date) = ${month ?? null}::int)
        ORDER BY t.date DESC, t.created_at DESC
        LIMIT 500
      `;
      return res.status(200).json(transactions);
    }

    if (req.method === 'POST') {
      const { account_id, category_id, payee_name, amount, date, memo, cleared = false } = req.body;
      if (!account_id || amount === undefined || !date) {
        return res.status(400).json({ error: 'account_id, amount, and date are required' });
      }

      // Upsert payee if name provided
      let payee_id = null;
      if (payee_name && payee_name.trim()) {
        const [payee] = await sql`
          INSERT INTO payees (name) VALUES (${payee_name.trim()})
          ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
          RETURNING id
        `;
        payee_id = payee.id;
      }

      const [transaction] = await sql`
        INSERT INTO transactions (account_id, category_id, payee_id, payee_name, amount, date, memo, cleared)
        VALUES (${account_id}, ${category_id ?? null}, ${payee_id}, ${payee_name ?? null}, ${amount}, ${date}, ${memo ?? null}, ${cleared})
        RETURNING *
      `;
      return res.status(201).json(transaction);
    }

    res.status(405).json({ error: 'Method not allowed' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};
