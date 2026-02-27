// PUT /api/categories/:id    — update category
// DELETE /api/categories/:id — delete category
const sql = require('../_db');
const { setCors, handleOptions } = require('../_cors');

// Neon returns BIGINT columns as strings; normalize numeric fields for the Swift client
function normalizeCategoryRow(row) {
  return {
    ...row,
    sort_order: parseInt(row.sort_order ?? 0, 10),
    target_amount: row.target_amount === null || row.target_amount === undefined
      ? null
      : parseInt(row.target_amount, 10),
  };
}

module.exports = async (req, res) => {
  setCors(res);
  if (handleOptions(req, res)) return;

  const { id } = req.query;

  try {
    if (req.method === 'PUT') {
      const { name, group_id, is_savings, sort_order, due_day, recurrence, target_amount, notes } = req.body;
      const [category] = await sql`
        UPDATE categories SET
          name = COALESCE(${name ?? null}, name),
          group_id = COALESCE(${group_id ?? null}, group_id),
          is_savings = COALESCE(${is_savings ?? null}, is_savings),
          sort_order = COALESCE(${sort_order ?? null}, sort_order),
          due_day = CASE WHEN ${Object.prototype.hasOwnProperty.call(req.body, 'due_day')} THEN ${due_day ?? null} ELSE due_day END,
          recurrence = CASE WHEN ${Object.prototype.hasOwnProperty.call(req.body, 'recurrence')} THEN ${recurrence ?? null} ELSE recurrence END,
          target_amount = CASE WHEN ${Object.prototype.hasOwnProperty.call(req.body, 'target_amount')} THEN ${target_amount ?? null} ELSE target_amount END,
          notes = CASE WHEN ${Object.prototype.hasOwnProperty.call(req.body, 'notes')} THEN ${notes ?? null} ELSE notes END
        WHERE id = ${id}
        RETURNING *
      `;
      if (!category) return res.status(404).json({ error: 'Category not found' });
      return res.status(200).json(normalizeCategoryRow(category));
    }

    if (req.method === 'DELETE') {
      await sql`DELETE FROM categories WHERE id = ${id}`;
      return res.status(204).end();
    }

    res.status(405).json({ error: 'Method not allowed' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};
