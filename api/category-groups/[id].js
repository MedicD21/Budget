// PUT /api/category-groups/:id    — update group
// DELETE /api/category-groups/:id — delete group (cascades to categories)
const sql = require('../_db');
const { setCors, handleOptions } = require('../_cors');

module.exports = async (req, res) => {
  setCors(res);
  if (handleOptions(req, res)) return;

  const { id } = req.query;

  try {
    if (req.method === 'PUT') {
      const { name, sort_order } = req.body;
      const [group] = await sql`
        UPDATE category_groups SET
          name = COALESCE(${name}, name),
          sort_order = COALESCE(${sort_order}, sort_order)
        WHERE id = ${id}
        RETURNING *
      `;
      if (!group) return res.status(404).json({ error: 'Group not found' });
      return res.status(200).json(group);
    }

    if (req.method === 'DELETE') {
      await sql`DELETE FROM category_groups WHERE id = ${id}`;
      return res.status(204).end();
    }

    res.status(405).json({ error: 'Method not allowed' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};
