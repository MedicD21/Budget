// GET /api/accounts        — list all accounts with computed balance
// POST /api/accounts       — create account
const sql = require('../_db');
const { setCors, handleOptions } = require('../_cors');

module.exports = async (req, res) => {
  setCors(res);
  if (handleOptions(req, res)) return;

  try {
    if (req.method === 'GET') {
      const accounts = await sql`
        SELECT
          a.id,
          a.name,
          a.type,
          a.starting_balance,
          a.is_savings_bucket,
          a.sort_order,
          a.created_at,
          COALESCE(a.starting_balance + SUM(t.amount), a.starting_balance) AS computed_balance,
          COALESCE(a.starting_balance + SUM(CASE WHEN t.cleared THEN t.amount ELSE 0 END), a.starting_balance) AS cleared_balance
        FROM accounts a
        LEFT JOIN transactions t ON t.account_id = a.id
        GROUP BY a.id
        ORDER BY a.sort_order, a.created_at
      `;
      return res.status(200).json(accounts);
    }

    if (req.method === 'POST') {
      const { name, type, starting_balance = 0, is_savings_bucket = false } = req.body;
      if (!name || !type) {
        return res.status(400).json({ error: 'name and type are required' });
      }
      const [account] = await sql`
        INSERT INTO accounts (name, type, starting_balance, is_savings_bucket)
        VALUES (${name}, ${type}, ${starting_balance}, ${is_savings_bucket})
        RETURNING *
      `;
      return res.status(201).json(account);
    }

    res.status(405).json({ error: 'Method not allowed' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};
