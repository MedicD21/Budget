// GET /api/categories        — list all categories with their group
// POST /api/categories       — create category
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
          c.due_day,
          c.recurrence,
          c.target_amount,
          c.notes,
          c.created_at
        FROM categories c
        JOIN category_groups cg ON cg.id = c.group_id
        ORDER BY cg.sort_order, c.sort_order
      `;
      return res.status(200).json(categories.map(normalizeCategoryRow));
    }

    if (req.method === 'POST') {
      const { group_id, name, is_savings = false, sort_order = 0, due_day = null, recurrence = null, target_amount = null, notes = null } = req.body;
      if (!group_id || !name) {
        return res.status(400).json({ error: 'group_id and name are required' });
      }
      const [category] = await sql`
        INSERT INTO categories (group_id, name, is_savings, sort_order, due_day, recurrence, target_amount, notes)
        VALUES (${group_id}, ${name}, ${is_savings}, ${sort_order}, ${due_day}, ${recurrence}, ${target_amount}, ${notes})
        RETURNING *
      `;
      return res.status(201).json(normalizeCategoryRow(category));
    }

    res.status(405).json({ error: 'Method not allowed' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};
