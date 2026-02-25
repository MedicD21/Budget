// GET /api/category-groups        — list all groups
// POST /api/category-groups       — create group
const sql = require('../_db');
const { setCors, handleOptions } = require('../_cors');

module.exports = async (req, res) => {
  setCors(res);
  if (handleOptions(req, res)) return;

  try {
    if (req.method === 'GET') {
      const groups = await sql`
        SELECT * FROM category_groups ORDER BY sort_order, created_at
      `;
      return res.status(200).json(groups);
    }

    if (req.method === 'POST') {
      const { name, sort_order = 0 } = req.body;
      if (!name) return res.status(400).json({ error: 'name is required' });
      const [group] = await sql`
        INSERT INTO category_groups (name, sort_order) VALUES (${name}, ${sort_order}) RETURNING *
      `;
      return res.status(201).json(group);
    }

    res.status(405).json({ error: 'Method not allowed' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};
