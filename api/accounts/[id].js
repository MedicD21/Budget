// PUT /api/accounts/:id    — update account
// DELETE /api/accounts/:id — delete account
const sql = require('../_db');
const { setCors, handleOptions } = require('../_cors');

module.exports = async (req, res) => {
  setCors(res);
  if (handleOptions(req, res)) return;

  const { id } = req.query;

  try {
    if (req.method === 'PUT') {
      const { name, type, starting_balance, is_savings_bucket, sort_order } = req.body;
      const [account] = await sql`
        UPDATE accounts SET
          name = COALESCE(${name}, name),
          type = COALESCE(${type}, type),
          starting_balance = COALESCE(${starting_balance}, starting_balance),
          is_savings_bucket = COALESCE(${is_savings_bucket}, is_savings_bucket),
          sort_order = COALESCE(${sort_order}, sort_order)
        WHERE id = ${id}
        RETURNING *
      `;
      if (!account) return res.status(404).json({ error: 'Account not found' });
      return res.status(200).json(account);
    }

    if (req.method === 'DELETE') {
      await sql`DELETE FROM accounts WHERE id = ${id}`;
      return res.status(204).end();
    }

    res.status(405).json({ error: 'Method not allowed' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};
