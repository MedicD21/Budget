// GET /api/category-groups        — list all groups
// POST /api/category-groups       — create group
// PUT /api/category-groups/:id    — update group
// DELETE /api/category-groups/:id — delete group (cascades to categories)
const sql = require('./_db');
const { setCors, handleOptions } = require('./_cors');

module.exports = async (req, res) => {
  setCors(res);
  if (handleOptions(req, res)) return;

  const rawId = req.query.id;
  const id = Array.isArray(rawId) ? rawId[0] : rawId;

  try {
    if (req.method === 'GET') {
      if (id) return res.status(405).json({ error: 'Method not allowed' });
      const groups = await sql`
        SELECT * FROM category_groups ORDER BY sort_order, created_at
      `;
      return res.status(200).json(groups);
    }

    if (req.method === 'POST') {
      if (id) return res.status(405).json({ error: 'Method not allowed' });
      const { name, sort_order = 0 } = req.body || {};
      if (!name) return res.status(400).json({ error: 'name is required' });
      const [group] = await sql`
        INSERT INTO category_groups (name, sort_order) VALUES (${name}, ${sort_order}) RETURNING *
      `;
      return res.status(201).json(group);
    }

    if (req.method === 'PUT') {
      if (!id) return res.status(405).json({ error: 'Method not allowed' });
      const { name, sort_order } = req.body || {};
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
      if (!id) return res.status(405).json({ error: 'Method not allowed' });
      await sql`DELETE FROM category_groups WHERE id = ${id}`;
      return res.status(204).end();
    }

    res.status(405).json({ error: 'Method not allowed' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};
