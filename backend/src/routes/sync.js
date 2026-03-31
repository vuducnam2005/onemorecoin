const express = require('express');
const { pool } = require('../config/database');
const authMiddleware = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

// POST /sync/upload - Upload all local data to server
router.post('/upload', async (req, res) => {
  try {
    const { wallets, groups, transactions, budgets, loans, loanPayments, reminders } = req.body;
    let stats = { wallets: 0, groups: 0, transactions: 0, budgets: 0, loans: 0, loanPayments: 0, reminders: 0 };

    // Sync Wallets
    if (Array.isArray(wallets)) {
      for (const w of wallets) {
        await pool.query(
          `INSERT INTO wallets (name, icon, currency, balance, "isReport", "index", "userId", "updatedAt")
           VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
          [w.name, w.icon, w.currency || 'VND', w.balance || 0, w.isReport !== undefined ? w.isReport : true, w.index || 0, req.userId]
        );
        stats.wallets++;
      }
    }

    // Sync Groups
    if (Array.isArray(groups)) {
      for (const g of groups) {
        await pool.query(
          `INSERT INTO groups (name, type, icon, color, "parentId", "index", "userId", "updatedAt")
           VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
          [g.name, g.type, g.icon, g.color, g.parentId, g.index || 1, req.userId]
        );
        stats.groups++;
      }
    }

    // Sync Transactions
    if (Array.isArray(transactions)) {
      for (const t of transactions) {
        await pool.query(
          `INSERT INTO transactions_table (id, title, amount, unit, type, date, note, "addToReport", "notifyDate", "walletId", "groupId", "userId", "updatedAt")
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW())
           ON CONFLICT (id) DO NOTHING`,
          [t.id, t.title, t.amount, t.unit || 'VND', t.type, t.date, t.note, t.addToReport !== undefined ? t.addToReport : true, t.notifyDate, t.walletId, t.groupId, req.userId]
        );
        stats.transactions++;
      }
    }

    // Sync Budgets
    if (Array.isArray(budgets)) {
      for (const b of budgets) {
        await pool.query(
          `INSERT INTO budgets (title, budget, unit, type, "fromDate", "toDate", note, "isRepeat", "walletId", "groupId", "budgetType", "userId", "updatedAt")
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW())`,
          [b.title, b.budget, b.unit || 'VND', b.type, b.fromDate, b.toDate, b.note, b.isRepeat || false, b.walletId, b.groupId, b.budgetType || 'month', req.userId]
        );
        stats.budgets++;
      }
    }

    // Sync Loans
    if (Array.isArray(loans)) {
      for (const l of loans) {
        await pool.query(
          `INSERT INTO loans (id, "personName", amount, "paidAmount", type, date, "dueDate", note, status, currency, "walletId", "phoneNumber", "remindBeforeDays", "remindTime", "userId", "updatedAt")
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, NOW())
           ON CONFLICT (id) DO NOTHING`,
          [l.id, l.personName, l.amount, l.paidAmount || 0, l.type, l.date, l.dueDate, l.note, l.status || 'unpaid', l.currency || 'VND', l.walletId, l.phoneNumber, l.remindBeforeDays, l.remindTime, req.userId]
        );
        stats.loans++;
      }
    }

    // Sync Loan Payments
    if (Array.isArray(loanPayments)) {
      for (const p of loanPayments) {
        await pool.query(
          `INSERT INTO loan_payments (id, "loanId", amount, date, note, "walletId", "userId", "updatedAt")
           VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
           ON CONFLICT (id) DO NOTHING`,
          [p.id, p.loanId, p.amount, p.date, p.note, p.walletId, req.userId]
        );
        stats.loanPayments++;
      }
    }

    // Sync Reminders
    if (Array.isArray(reminders)) {
      for (const r of reminders) {
        await pool.query(
          `INSERT INTO reminders (id, title, amount, type, "dueDate", "remindBeforeDays", "remindTime", "isPaid", note, "userId", "updatedAt")
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW())
           ON CONFLICT (id) DO NOTHING`,
          [r.id, r.title, r.amount, r.type, r.dueDate, r.remindBeforeDays || 0, r.remindTime || '08:00', r.isPaid || false, r.note, req.userId]
        );
        stats.reminders++;
      }
    }

    res.json({ message: 'Đồng bộ dữ liệu thành công', stats });
  } catch (err) {
    console.error('Sync upload error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// GET /sync/download - Delta sync via ?since=ISO8601
router.get('/download', async (req, res) => {
  try {
    const { since } = req.query;

    let timeFilter = '';
    const params = [req.userId];
    if (since) {
      timeFilter = ' AND "updatedAt" > $2';
      params.push(new Date(since));
    }

    const [wallets, groups, transactions, budgets, loans, loanPayments, reminders] = await Promise.all([
      pool.query(`SELECT * FROM wallets WHERE "userId" = $1${timeFilter}`, params),
      pool.query(`SELECT * FROM groups WHERE "userId" = $1${timeFilter}`, params),
      pool.query(`SELECT * FROM transactions_table WHERE "userId" = $1${timeFilter}`, params),
      pool.query(`SELECT * FROM budgets WHERE "userId" = $1${timeFilter}`, params),
      pool.query(`SELECT * FROM loans WHERE "userId" = $1${timeFilter}`, params),
      pool.query(`SELECT * FROM loan_payments WHERE "userId" = $1${timeFilter}`, params),
      pool.query(`SELECT * FROM reminders WHERE "userId" = $1${timeFilter}`, params),
    ]);

    res.json({
      wallets: wallets.rows,
      groups: groups.rows,
      transactions: transactions.rows,
      budgets: budgets.rows,
      loans: loans.rows,
      loanPayments: loanPayments.rows,
      reminders: reminders.rows,
      syncedAt: new Date().toISOString(),
    });
  } catch (err) {
    console.error('Sync download error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

module.exports = router;
