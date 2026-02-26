// GET /api/budget/:year/:month — full budget for a month
// Returns groups with categories, each with allocated/activity/available
// Also returns ready_to_assign at the top level
const sql = require('../../../_db');
const { setCors, handleOptions } = require('../../../_cors');

module.exports = async (req, res) => {
  setCors(res);
  if (handleOptions(req, res)) return;

  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  const year = parseInt(req.query.year);
  const month = parseInt(req.query.month);

  if (!year || !month || month < 1 || month > 12) {
    return res.status(400).json({ error: 'Invalid year or month' });
  }

  try {
    // Get all groups with their categories, allocations and activity for this month
    const rows = await sql`
      SELECT
        cg.id AS group_id,
        cg.name AS group_name,
        cg.sort_order AS group_sort,
        c.id AS category_id,
        c.group_id AS category_group_id,
        c.name AS category_name,
        c.is_savings,
        c.sort_order AS category_sort,
        c.due_day,
        c.recurrence,
        c.target_amount,
        c.notes,
        COALESCE(cm.allocated, 0) AS allocated,
        COALESCE(SUM(t.amount), 0) AS activity
      FROM category_groups cg
      LEFT JOIN categories c ON c.group_id = cg.id
      LEFT JOIN category_months cm
        ON cm.category_id = c.id AND cm.year = ${year} AND cm.month = ${month}
      LEFT JOIN transactions t
        ON t.category_id = c.id
        AND EXTRACT(YEAR FROM t.date) = ${year}
        AND EXTRACT(MONTH FROM t.date) = ${month}
      GROUP BY cg.id, cg.name, cg.sort_order, c.id, c.group_id, c.name, c.is_savings, c.sort_order,
               c.due_day, c.recurrence, c.target_amount, c.notes, cm.allocated
      ORDER BY cg.sort_order, c.sort_order
    `;

    // Total income (all inflow transactions ever = total funded)
    // Ready to assign = all inflows - all allocated (ever, across all months)
    // This is the simple "total money in - total budgeted" model
    const [fundingRow] = await sql`
      SELECT
        COALESCE(SUM(CASE WHEN t.amount > 0 THEN t.amount ELSE 0 END), 0) AS total_inflow,
        COALESCE(SUM(CASE WHEN t.amount < 0 THEN t.amount ELSE 0 END), 0) AS total_outflow
      FROM transactions t
    `;
    const [allocatedRow] = await sql`
      SELECT COALESCE(SUM(allocated), 0) AS total_allocated FROM category_months
    `;

    const totalInflow = parseInt(fundingRow.total_inflow);
    const totalAllocated = parseInt(allocatedRow.total_allocated);
    const readyToAssign = totalInflow - totalAllocated;

    // Build grouped structure
    const groupMap = new Map();
    for (const row of rows) {
      if (!groupMap.has(row.group_id)) {
        groupMap.set(row.group_id, {
          id: row.group_id,
          name: row.group_name,
          sort_order: row.group_sort,
          categories: [],
          total_allocated: 0,
          total_activity: 0,
          total_available: 0,
        });
      }
      if (row.category_id) {
        const allocated = parseInt(row.allocated);
        const activity = parseInt(row.activity);
        const available = allocated + activity;
        const group = groupMap.get(row.group_id);
        group.categories.push({
          id: row.category_id,
          group_id: row.category_group_id,
          name: row.category_name,
          is_savings: row.is_savings,
          sort_order: row.category_sort,
          due_day: row.due_day,
          recurrence: row.recurrence,
          target_amount: row.target_amount === null ? null : parseInt(row.target_amount),
          notes: row.notes,
          allocated,
          activity,
          available,
        });
        group.total_allocated += allocated;
        group.total_activity += activity;
        group.total_available += available;
      }
    }

    const groups = Array.from(groupMap.values());
    const thisMonthBudgeted = groups.reduce((sum, g) => sum + g.total_allocated, 0);

    res.status(200).json({
      year,
      month,
      ready_to_assign: readyToAssign,
      total_budgeted: thisMonthBudgeted,
      groups,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};
