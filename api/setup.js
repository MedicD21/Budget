// Run once to initialize the database schema
// GET /api/setup
const sql = require('./_db');
const { setCors, handleOptions } = require('./_cors');

module.exports = async (req, res) => {
  setCors(res);
  if (handleOptions(req, res)) return;

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Accounts: checking, savings, credit card, cash
    await sql`
      CREATE TABLE IF NOT EXISTS accounts (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('checking', 'savings', 'credit_card', 'cash')),
        starting_balance BIGINT NOT NULL DEFAULT 0,
        is_savings_bucket BOOLEAN NOT NULL DEFAULT FALSE,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;

    // Category groups (Housing, Food, Transportation, etc.)
    await sql`
      CREATE TABLE IF NOT EXISTS category_groups (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;

    // Categories within groups
    await sql`
      CREATE TABLE IF NOT EXISTS categories (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        group_id UUID REFERENCES category_groups(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        is_savings BOOLEAN NOT NULL DEFAULT FALSE,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    // Idempotent migration — add new columns if they don't exist yet
    await sql`ALTER TABLE categories ADD COLUMN IF NOT EXISTS due_day INTEGER`;
    await sql`ALTER TABLE categories ADD COLUMN IF NOT EXISTS recurrence TEXT`;
    await sql`ALTER TABLE categories ADD COLUMN IF NOT EXISTS target_amount BIGINT`;
    await sql`ALTER TABLE categories ADD COLUMN IF NOT EXISTS notes TEXT`;

    // Monthly budget allocations per category
    await sql`
      CREATE TABLE IF NOT EXISTS category_months (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        category_id UUID REFERENCES categories(id) ON DELETE CASCADE,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        allocated BIGINT NOT NULL DEFAULT 0,
        UNIQUE(category_id, year, month)
      )
    `;

    // Payees (merchants, people, etc.)
    await sql`
      CREATE TABLE IF NOT EXISTS payees (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name TEXT NOT NULL UNIQUE,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;

    // Transactions (positive = inflow/income, negative = outflow/spending)
    await sql`
      CREATE TABLE IF NOT EXISTS transactions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        account_id UUID REFERENCES accounts(id) ON DELETE CASCADE,
        category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
        payee_id UUID REFERENCES payees(id) ON DELETE SET NULL,
        payee_name TEXT,
        amount BIGINT NOT NULL,
        date DATE NOT NULL,
        memo TEXT,
        cleared BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;

    // Seed default category groups and categories
    const existingGroups = await sql`SELECT COUNT(*) as count FROM category_groups`;
    if (parseInt(existingGroups[0].count) === 0) {
      const [billsGroup] = await sql`
        INSERT INTO category_groups (name, sort_order) VALUES ('Monthly Bills', 0) RETURNING id
      `;
      const [foodGroup] = await sql`
        INSERT INTO category_groups (name, sort_order) VALUES ('Everyday Expenses', 1) RETURNING id
      `;
      const [savingsGroup] = await sql`
        INSERT INTO category_groups (name, sort_order) VALUES ('Savings Goals', 2) RETURNING id
      `;

      await sql`
        INSERT INTO categories (group_id, name, sort_order) VALUES
          (${billsGroup.id}, 'Rent / Mortgage', 0),
          (${billsGroup.id}, 'Internet', 1),
          (${billsGroup.id}, 'Phone', 2),
          (${billsGroup.id}, 'Utilities', 3)
      `;
      await sql`
        INSERT INTO categories (group_id, name, sort_order) VALUES
          (${foodGroup.id}, 'Groceries', 0),
          (${foodGroup.id}, 'Dining Out', 1),
          (${foodGroup.id}, 'Transportation', 2),
          (${foodGroup.id}, 'Entertainment', 3),
          (${foodGroup.id}, 'Personal Care', 4)
      `;
      await sql`
        INSERT INTO categories (group_id, name, sort_order, is_savings) VALUES
          (${savingsGroup.id}, 'Emergency Fund', 0, TRUE),
          (${savingsGroup.id}, 'Vacation', 1, TRUE),
          (${savingsGroup.id}, 'New Car', 2, TRUE)
      `;
    }

    res.status(200).json({
      success: true,
      message: 'Database schema created and seeded successfully'
    });
  } catch (err) {
    console.error('Setup error:', err);
    res.status(500).json({ error: err.message });
  }
};
