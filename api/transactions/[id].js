// GET /api/transactions/:id    — get one transaction
// PUT /api/transactions/:id    — update transaction
// DELETE /api/transactions/:id — delete transaction
const sql = require('../_db');
const { setCors, handleOptions } = require('../_cors');

// Neon returns BIGINT columns as strings; normalize to numbers for the Swift client
function normalizeTransactionRow(row) {
  return {
    ...row,
    amount: parseInt(row.amount ?? 0, 10),
  };
}

module.exports = async (req, res) => {
  setCors(res);
  if (handleOptions(req, res)) return;

  const { id } = req.query;

  try {
    if (req.method === 'GET') {
      const [transaction] = await sql`
        SELECT
          t.*,
          a.name AS account_name,
          c.name AS category_name,
          COALESCE(t.payee_name, p.name) AS payee_name
        FROM transactions t
        LEFT JOIN accounts a ON a.id = t.account_id
        LEFT JOIN categories c ON c.id = t.category_id
        LEFT JOIN payees p ON p.id = t.payee_id
        WHERE t.id = ${id}
      `;
      if (!transaction) return res.status(404).json({ error: 'Transaction not found' });
      return res.status(200).json(normalizeTransactionRow(transaction));
    }

    if (req.method === 'PUT') {
      const { account_id, category_id, payee_name, amount, date, memo, cleared } = req.body;

      let payee_id = undefined;
      if (payee_name !== undefined) {
        if (payee_name && payee_name.trim()) {
          const [payee] = await sql`
            INSERT INTO payees (name) VALUES (${payee_name.trim()})
            ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
            RETURNING id
          `;
          payee_id = payee.id;
        } else {
          payee_id = null;
        }
      }

      const [transaction] = await sql`
        UPDATE transactions SET
          account_id = COALESCE(${account_id ?? null}, account_id),
          category_id = CASE WHEN ${category_id !== undefined} THEN ${category_id ?? null} ELSE category_id END,
          payee_id = CASE WHEN ${payee_id !== undefined} THEN ${payee_id ?? null} ELSE payee_id END,
          payee_name = CASE WHEN ${payee_name !== undefined} THEN ${payee_name ?? null} ELSE payee_name END,
          amount = COALESCE(${amount ?? null}, amount),
          date = COALESCE(${date ?? null}::date, date),
          memo = CASE WHEN ${memo !== undefined} THEN ${memo ?? null} ELSE memo END,
          cleared = COALESCE(${cleared ?? null}, cleared)
        WHERE id = ${id}
        RETURNING *
      `;
      if (!transaction) return res.status(404).json({ error: 'Transaction not found' });
      return res.status(200).json(normalizeTransactionRow(transaction));
    }

    if (req.method === 'DELETE') {
      await sql`DELETE FROM transactions WHERE id = ${id}`;
      return res.status(204).end();
    }

    res.status(405).json({ error: 'Method not allowed' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};
