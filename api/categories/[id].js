// PUT /api/categories/:id    — update category
// DELETE /api/categories/:id — delete category
const sql = require('../_db');
const { setCors, handleOptions } = require('../_cors');

module.exports = async (req, res) => {
  setCors(res);
  if (handleOptions(req, res)) return;

  const { id } = req.query;

  try {
    if (req.method === 'PUT') {
      const { name, group_id, is_savings, sort_order } = req.body;
      const [category] = await sql`
        UPDATE categories SET
          name = COALESCE(${name}, name),
          group_id = COALESCE(${group_id}, group_id),
          is_savings = COALESCE(${is_savings}, is_savings),
          sort_order = COALESCE(${sort_order}, sort_order)
        WHERE id = ${id}
        RETURNING *
      `;
      if (!category) return res.status(404).json({ error: 'Category not found' });
      return res.status(200).json(category);
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
