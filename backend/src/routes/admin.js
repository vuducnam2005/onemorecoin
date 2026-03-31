const express = require('express');
const { pool } = require('../config/database');
const adminAuth = require('../middleware/adminAuth');

const router = express.Router();

// All admin routes require admin authentication
router.use(adminAuth);

// ========================
// DASHBOARD
// ========================

// GET /admin/dashboard
router.get('/dashboard', async (req, res) => {
  try {
    const [usersCount, transactionsCount, totalExpense, totalIncome, recentUsers] = await Promise.all([
      pool.query('SELECT COUNT(*) as count FROM users'),
      pool.query('SELECT COUNT(*) as count FROM transactions_table WHERE "isDeleted" = false'),
      pool.query(`SELECT COALESCE(SUM(amount), 0) as total FROM transactions_table WHERE type = 'expense' AND "isDeleted" = false`),
      pool.query(`SELECT COALESCE(SUM(amount), 0) as total FROM transactions_table WHERE type = 'income' AND "isDeleted" = false`),
      pool.query('SELECT id, username, email, "displayName", role, "isLocked", "createdAt" FROM users ORDER BY "createdAt" DESC LIMIT 5'),
    ]);

    // Transactions per day (last 7 days)
    const dailyStats = await pool.query(`
      SELECT 
        date,
        COUNT(*) as count,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as expense,
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as income
      FROM transactions_table 
      WHERE "isDeleted" = false 
        AND date >= TO_CHAR(NOW() - INTERVAL '7 days', 'YYYY-MM-DD')
      GROUP BY date 
      ORDER BY date DESC
    `);

    res.json({
      stats: {
        totalUsers: parseInt(usersCount.rows[0].count),
        totalTransactions: parseInt(transactionsCount.rows[0].count),
        totalExpense: parseFloat(totalExpense.rows[0].total),
        totalIncome: parseFloat(totalIncome.rows[0].total),
      },
      dailyStats: dailyStats.rows,
      recentUsers: recentUsers.rows,
    });
  } catch (err) {
    console.error('Dashboard error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// ========================
// USER MANAGEMENT
// ========================

// GET /admin/users?page=1&limit=20&search=keyword
router.get('/users', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const search = req.query.search || '';
    const offset = (page - 1) * limit;

    let whereClause = '';
    let params = [];

    if (search) {
      whereClause = `WHERE username ILIKE $1 OR email ILIKE $1 OR "displayName" ILIKE $1`;
      params = [`%${search}%`];
    }

    const countQuery = `SELECT COUNT(*) as count FROM users ${whereClause}`;
    const countResult = await pool.query(countQuery, params);
    const total = parseInt(countResult.rows[0].count);

    const dataParams = search
      ? [`%${search}%`, limit, offset]
      : [limit, offset];

    const dataQuery = `
      SELECT id, username, email, "displayName", role, "isLocked", "createdAt"
      FROM users 
      ${whereClause}
      ORDER BY "createdAt" DESC
      LIMIT $${search ? 2 : 1} OFFSET $${search ? 3 : 2}
    `;

    const result = await pool.query(dataQuery, dataParams);

    // Get transaction count per user
    const userIds = result.rows.map(u => u.id);
    let userStats = {};
    
    if (userIds.length > 0) {
      const statsQuery = await pool.query(`
        SELECT "userId", COUNT(*) as "transactionCount", 
               COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as "totalExpense"
        FROM transactions_table 
        WHERE "userId" = ANY($1) AND "isDeleted" = false
        GROUP BY "userId"
      `, [userIds]);

      statsQuery.rows.forEach(s => {
        userStats[s.userId] = {
          transactionCount: parseInt(s.transactionCount),
          totalExpense: parseFloat(s.totalExpense),
        };
      });
    }

    const users = result.rows.map(user => ({
      ...user,
      transactionCount: userStats[user.id]?.transactionCount || 0,
      totalExpense: userStats[user.id]?.totalExpense || 0,
    }));

    res.json({
      users,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    });
  } catch (err) {
    console.error('Get users error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// GET /admin/users/:id
router.get('/users/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const userResult = await pool.query(
      'SELECT id, username, email, "displayName", role, "isLocked", "createdAt" FROM users WHERE id = $1',
      [id]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy user' });
    }

    const [wallets, transactions, groups, budgets, loans] = await Promise.all([
      pool.query('SELECT COUNT(*) as count FROM wallets WHERE "userId" = $1 AND "isDeleted" = false', [id]),
      pool.query(`
        SELECT COUNT(*) as count, 
               COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as "totalExpense",
               COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as "totalIncome"
        FROM transactions_table WHERE "userId" = $1 AND "isDeleted" = false
      `, [id]),
      pool.query('SELECT COUNT(*) as count FROM groups WHERE "userId" = $1 AND "isDeleted" = false', [id]),
      pool.query('SELECT COUNT(*) as count FROM budgets WHERE "userId" = $1 AND "isDeleted" = false', [id]),
      pool.query('SELECT COUNT(*) as count FROM loans WHERE "userId" = $1 AND "isDeleted" = false', [id]),
    ]);

    res.json({
      user: userResult.rows[0],
      stats: {
        wallets: parseInt(wallets.rows[0].count),
        transactions: parseInt(transactions.rows[0].count),
        totalExpense: parseFloat(transactions.rows[0].totalExpense),
        totalIncome: parseFloat(transactions.rows[0].totalIncome),
        groups: parseInt(groups.rows[0].count),
        budgets: parseInt(budgets.rows[0].count),
        loans: parseInt(loans.rows[0].count),
      },
    });
  } catch (err) {
    console.error('Get user detail error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// PUT /admin/users/:id/lock
router.put('/users/:id/lock', async (req, res) => {
  try {
    const { id } = req.params;
    const { isLocked } = req.body;

    // Prevent locking yourself
    if (id === req.userId) {
      return res.status(400).json({ error: 'Không thể khóa chính mình' });
    }

    const result = await pool.query(
      'UPDATE users SET "isLocked" = $1 WHERE id = $2 RETURNING id, username, "isLocked"',
      [isLocked, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy user' });
    }

    // If locking, revoke all refresh tokens
    if (isLocked) {
      await pool.query('DELETE FROM refresh_tokens WHERE "userId" = $1', [id]);
    }

    res.json({
      message: isLocked ? 'Đã khóa tài khoản' : 'Đã mở khóa tài khoản',
      user: result.rows[0],
    });
  } catch (err) {
    console.error('Lock user error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// DELETE /admin/users/:id
router.delete('/users/:id', async (req, res) => {
  try {
    const { id } = req.params;

    // Prevent deleting yourself
    if (id === req.userId) {
      return res.status(400).json({ error: 'Không thể xóa chính mình' });
    }

    // Check user exists
    const userCheck = await pool.query('SELECT id, role FROM users WHERE id = $1', [id]);
    if (userCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy user' });
    }

    if (userCheck.rows[0].role === 'admin') {
      return res.status(400).json({ error: 'Không thể xóa tài khoản admin khác' });
    }

    // Delete all user data (cascade)
    await pool.query('DELETE FROM loan_payments WHERE "userId" = $1', [id]);
    await pool.query('DELETE FROM loans WHERE "userId" = $1', [id]);
    await pool.query('DELETE FROM app_notifications WHERE "userId" = $1', [id]);
    await pool.query('DELETE FROM reminders WHERE "userId" = $1', [id]);
    await pool.query('DELETE FROM budgets WHERE "userId" = $1', [id]);
    await pool.query('DELETE FROM transactions_table WHERE "userId" = $1', [id]);
    await pool.query('DELETE FROM groups WHERE "userId" = $1', [id]);
    await pool.query('DELETE FROM wallets WHERE "userId" = $1', [id]);
    await pool.query('DELETE FROM refresh_tokens WHERE "userId" = $1', [id]);
    await pool.query('DELETE FROM processed_requests WHERE "userId" = $1', [id]);
    await pool.query('DELETE FROM users WHERE id = $1', [id]);

    res.json({ message: 'Đã xóa user và toàn bộ dữ liệu' });
  } catch (err) {
    console.error('Delete user error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// ========================
// TRANSACTION MANAGEMENT
// ========================

// GET /admin/transactions?page=1&limit=20&userId=xxx&type=expense&dateFrom=2024-01-01&dateTo=2024-12-31
router.get('/transactions', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const { userId, type, dateFrom, dateTo, search } = req.query;

    let conditions = ['"isDeleted" = false'];
    let params = [];
    let paramIndex = 1;

    if (userId) {
      conditions.push(`t."userId" = $${paramIndex++}`);
      params.push(userId);
    }
    if (type) {
      conditions.push(`t.type = $${paramIndex++}`);
      params.push(type);
    }
    if (dateFrom) {
      conditions.push(`t.date >= $${paramIndex++}`);
      params.push(dateFrom);
    }
    if (dateTo) {
      conditions.push(`t.date <= $${paramIndex++}`);
      params.push(dateTo);
    }
    if (search) {
      conditions.push(`(t.title ILIKE $${paramIndex} OR t.note ILIKE $${paramIndex})`);
      params.push(`%${search}%`);
      paramIndex++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const countResult = await pool.query(
      `SELECT COUNT(*) as count FROM transactions_table t ${whereClause}`,
      params
    );
    const total = parseInt(countResult.rows[0].count);

    const dataResult = await pool.query(
      `SELECT t.*, u.username, u."displayName"
       FROM transactions_table t
       LEFT JOIN users u ON t."userId" = u.id
       ${whereClause}
       ORDER BY t.date DESC, t."updatedAt" DESC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      [...params, limit, offset]
    );

    res.json({
      transactions: dataResult.rows,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    });
  } catch (err) {
    console.error('Get transactions error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// DELETE /admin/transactions/:id
router.delete('/transactions/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query(
      'UPDATE transactions_table SET "isDeleted" = true WHERE id = $1 RETURNING id',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy giao dịch' });
    }

    res.json({ message: 'Đã xóa giao dịch' });
  } catch (err) {
    console.error('Delete transaction error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// ========================
// DATA DELETION REQUESTS
// ========================

// GET /admin/delete-requests — Danh sách yêu cầu xoá dữ liệu
router.get('/delete-requests', async (req, res) => {
  try {
    const status = req.query.status || 'pending';

    const result = await pool.query(`
      SELECT dr.*, u.username, u.email, u."displayName"
      FROM data_deletion_requests dr
      JOIN users u ON dr."userId" = u.id
      ${status !== 'all' ? `WHERE dr.status = $1` : ''}
      ORDER BY dr."createdAt" DESC
    `, status !== 'all' ? [status] : []);

    res.json({ requests: result.rows });
  } catch (err) {
    console.error('Get delete requests error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// POST /admin/delete-requests/:id/approve — Admin duyệt xoá dữ liệu
router.post('/delete-requests/:id/approve', async (req, res) => {
  try {
    const { id } = req.params;

    // Get request info
    const reqResult = await pool.query(
      `SELECT * FROM data_deletion_requests WHERE id = $1 AND status = 'pending'`,
      [id]
    );

    if (reqResult.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy yêu cầu hoặc đã được xử lý' });
    }

    const userId = reqResult.rows[0].userId;

    // Delete all user DATA (but keep the user account)
    await pool.query('DELETE FROM loan_payments WHERE "userId" = $1', [userId]);
    await pool.query('DELETE FROM loans WHERE "userId" = $1', [userId]);
    await pool.query('DELETE FROM app_notifications WHERE "userId" = $1', [userId]);
    await pool.query('DELETE FROM reminders WHERE "userId" = $1', [userId]);
    await pool.query('DELETE FROM budgets WHERE "userId" = $1', [userId]);
    await pool.query('DELETE FROM transactions_table WHERE "userId" = $1', [userId]);
    await pool.query('DELETE FROM groups WHERE "userId" = $1', [userId]);
    await pool.query('DELETE FROM wallets WHERE "userId" = $1', [userId]);
    await pool.query('DELETE FROM processed_requests WHERE "userId" = $1', [userId]);

    // Mark request as approved
    await pool.query(
      `UPDATE data_deletion_requests SET status = 'approved', "processedAt" = NOW() WHERE id = $1`,
      [id]
    );

    res.json({ message: 'Đã phê duyệt và xoá toàn bộ dữ liệu của user' });
  } catch (err) {
    console.error('Approve delete request error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// POST /admin/delete-requests/:id/reject — Admin từ chối yêu cầu
router.post('/delete-requests/:id/reject', async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query(
      `UPDATE data_deletion_requests SET status = 'rejected', "processedAt" = NOW() WHERE id = $1 AND status = 'pending' RETURNING id`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy yêu cầu hoặc đã được xử lý' });
    }

    res.json({ message: 'Đã từ chối yêu cầu xoá dữ liệu' });
  } catch (err) {
    console.error('Reject delete request error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

module.exports = router;
