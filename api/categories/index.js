// GET /api/categories        — list all categories with their group
// POST /api/categories       — create category
const sql = require('../_db');
const { setCors, handleOptions } = require('../_cors');

module.exports = async (req, res) => {
  setCors(res);
  if (handleOptions(req, res)) return;

  try {
    if (req.method === 'GET') {
      const categories = await sql`
        SELECT
          c.id,
          c.group_id,
          cg.name AS group_name,
          c.name,
          c.is_savings,
          c.sort_order,
          c.created_at
        FROM categories c
        JOIN category_groups cg ON cg.id = c.group_id
        ORDER BY cg.sort_order, c.sort_order
      `;
      return res.status(200).json(categories);
    }

    if (req.method === 'POST') {
      const { group_id, name, is_savings = false, sort_order = 0 } = req.body;
      if (!group_id || !name) {
        return res.status(400).json({ error: 'group_id and name are required' });
      }
      const [category] = await sql`
        INSERT INTO categories (group_id, name, is_savings, sort_order)
        VALUES (${group_id}, ${name}, ${is_savings}, ${sort_order})
        RETURNING *
      `;
      return res.status(201).json(category);
    }

    res.status(405).json({ error: 'Method not allowed' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};
