// GET /api/payees — list all payees (for autocomplete)
const sql = require('../_db');
const { setCors, handleOptions } = require('../_cors');

module.exports = async (req, res) => {
  setCors(res);
  if (handleOptions(req, res)) return;

  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const payees = await sql`SELECT * FROM payees ORDER BY name`;
    res.status(200).json(payees);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};
