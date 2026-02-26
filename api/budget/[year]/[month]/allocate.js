// PUT /api/budget/:year/:month/allocate
// Body: { category_id, allocated }  (allocated in cents)
// Upserts the category_month allocation
const sql = require('../../../_db');
const { setCors, handleOptions } = require('../../../_cors');

module.exports = async (req, res) => {
  setCors(res);
  if (handleOptions(req, res)) return;

  if (req.method !== 'PUT') return res.status(405).json({ error: 'Method not allowed' });

  const year = parseInt(req.query.year);
  const month = parseInt(req.query.month);
  const { category_id, allocated, assignments, reset_all } = req.body || {};

  if (!year || !month || month < 1 || month > 12) {
    return res.status(400).json({ error: 'Invalid year or month' });
  }

  try {
    // Reset all allocations for this month
    if (reset_all === true) {
      const deleted = await sql`
        DELETE FROM category_months
        WHERE year = ${year} AND month = ${month}
        RETURNING id
      `;
      return res.status(200).json({ success: true, cleared_count: deleted.length });
    }

    // Bulk upsert allocations
    if (Array.isArray(assignments)) {
      for (const item of assignments) {
        const a = Number(item?.allocated);
        if (!item?.category_id || !Number.isInteger(a)) {
          return res.status(400).json({ error: 'Each assignment needs category_id and integer allocated' });
        }
      }

      for (const item of assignments) {
        await sql`
          INSERT INTO category_months (category_id, year, month, allocated)
          VALUES (${item.category_id}, ${year}, ${month}, ${item.allocated})
          ON CONFLICT (category_id, year, month)
          DO UPDATE SET allocated = EXCLUDED.allocated
        `;
      }
      return res.status(200).json({ success: true, updated_count: assignments.length });
    }

    // Single-category upsert (existing behavior)
    const parsedAllocated = Number(allocated);
    if (!category_id || !Number.isInteger(parsedAllocated)) {
      return res.status(400).json({ error: 'category_id and integer allocated are required' });
    }

    const [record] = await sql`
      INSERT INTO category_months (category_id, year, month, allocated)
      VALUES (${category_id}, ${year}, ${month}, ${parsedAllocated})
      ON CONFLICT (category_id, year, month)
      DO UPDATE SET allocated = EXCLUDED.allocated
      RETURNING *
    `;
    return res.status(200).json(record);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};
