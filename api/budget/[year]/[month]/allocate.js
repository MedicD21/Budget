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
  const { category_id, allocated } = req.body;

  if (!category_id || allocated === undefined) {
    return res.status(400).json({ error: 'category_id and allocated are required' });
  }
  if (!year || !month || month < 1 || month > 12) {
    return res.status(400).json({ error: 'Invalid year or month' });
  }

  try {
    const [record] = await sql`
      INSERT INTO category_months (category_id, year, month, allocated)
      VALUES (${category_id}, ${year}, ${month}, ${allocated})
      ON CONFLICT (category_id, year, month)
      DO UPDATE SET allocated = EXCLUDED.allocated
      RETURNING *
    `;
    res.status(200).json(record);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};
