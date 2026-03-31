const express = require('express');
const { pool } = require('../config/database');
const authMiddleware = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

// GET /loans
router.get('/', async (req, res) => {
  try {
    const { type, status } = req.query;
    let query = 'SELECT * FROM loans WHERE "userId" = $1 AND ("isDeleted" = false OR "isDeleted" IS NULL)';
    const params = [req.userId];
    let paramIdx = 2;

    if (type) {
      query += ` AND type = $${paramIdx++}`;
      params.push(type);
    }
    if (status) {
      query += ` AND status = $${paramIdx++}`;
      params.push(status);
    }

    query += ' ORDER BY date DESC';
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error('Get loans error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// POST /loans
router.post('/', async (req, res) => {
  try {
    if (req.checkIdempotency && await req.checkIdempotency()) {
      return res.status(409).json({ message: 'Request đã được xử lý' });
    }

    const { id, personName, amount, paidAmount, type, date, dueDate, note, status, currency, walletId, phoneNumber, remindBeforeDays, remindTime } = req.body;

    await pool.query(
      `INSERT INTO loans (id, "personName", amount, "paidAmount", type, date, "dueDate", note, status, currency, "walletId", "phoneNumber", "remindBeforeDays", "remindTime", "userId", "updatedAt")
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, NOW())`,
      [id, personName, amount, paidAmount || 0, type || 'borrow', date, dueDate, note, status || 'unpaid', currency || 'VND', walletId, phoneNumber, remindBeforeDays, remindTime, req.userId]
    );

    if (req.markProcessed) await req.markProcessed();
    res.status(201).json({ message: 'Thêm khoản vay thành công', id });
  } catch (err) {
    console.error('Create loan error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// PUT /loans/:id
router.put('/:id', async (req, res) => {
  try {
    if (req.checkIdempotency && await req.checkIdempotency()) {
      return res.status(409).json({ message: 'Request đã được xử lý' });
    }

    const { personName, amount, paidAmount, type, date, dueDate, note, status, currency, walletId, phoneNumber, remindBeforeDays, remindTime, isDeleted } = req.body;

    await pool.query(
      `UPDATE loans SET
        "personName" = COALESCE($1, "personName"),
        amount = COALESCE($2, amount),
        "paidAmount" = COALESCE($3, "paidAmount"),
        type = COALESCE($4, type),
        date = COALESCE($5, date),
        "dueDate" = COALESCE($6, "dueDate"),
        note = COALESCE($7, note),
        status = COALESCE($8, status),
        currency = COALESCE($9, currency),
        "walletId" = COALESCE($10, "walletId"),
        "phoneNumber" = COALESCE($11, "phoneNumber"),
        "remindBeforeDays" = COALESCE($12, "remindBeforeDays"),
        "remindTime" = COALESCE($13, "remindTime"),
        "isDeleted" = COALESCE($14, "isDeleted"),
        "updatedAt" = NOW()
       WHERE id = $15 AND "userId" = $16`,
      [personName, amount, paidAmount, type, date, dueDate, note, status, currency, walletId, phoneNumber, remindBeforeDays, remindTime, isDeleted, req.params.id, req.userId]
    );

    if (req.markProcessed) await req.markProcessed();
    res.json({ message: 'Cập nhật khoản vay thành công' });
  } catch (err) {
    console.error('Update loan error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// DELETE /loans/:id - Soft delete
router.delete('/:id', async (req, res) => {
  try {
    await pool.query(
      `UPDATE loan_payments SET "isDeleted" = true, "updatedAt" = NOW() WHERE "loanId" = $1 AND "userId" = $2`,
      [req.params.id, req.userId]
    );
    await pool.query(
      `UPDATE loans SET "isDeleted" = true, "updatedAt" = NOW() WHERE id = $1 AND "userId" = $2`,
      [req.params.id, req.userId]
    );
    res.json({ message: 'Xóa khoản vay thành công' });
  } catch (err) {
    console.error('Delete loan error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// GET /loans/:id/payments
router.get('/:id/payments', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM loan_payments WHERE "loanId" = $1 AND "userId" = $2 AND ("isDeleted" = false OR "isDeleted" IS NULL) ORDER BY date DESC',
      [req.params.id, req.userId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Get loan payments error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// POST /loans/:id/payments
router.post('/:id/payments', async (req, res) => {
  try {
    if (req.checkIdempotency && await req.checkIdempotency()) {
      return res.status(409).json({ message: 'Request đã được xử lý' });
    }

    const { id: paymentId, amount, date, note, walletId } = req.body;

    await pool.query(
      `INSERT INTO loan_payments (id, "loanId", amount, date, note, "walletId", "userId", "updatedAt")
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
      [paymentId, req.params.id, amount, date, note, walletId, req.userId]
    );

    // Update loan paidAmount and status
    const loan = await pool.query(
      'SELECT amount, "paidAmount" FROM loans WHERE id = $1 AND "userId" = $2',
      [req.params.id, req.userId]
    );

    if (loan.rows.length > 0) {
      const newPaidAmount = (loan.rows[0].paidAmount || 0) + amount;
      const newStatus = newPaidAmount >= loan.rows[0].amount ? 'paid' : 'partial';

      await pool.query(
        'UPDATE loans SET "paidAmount" = $1, status = $2, "updatedAt" = NOW() WHERE id = $3 AND "userId" = $4',
        [Math.min(newPaidAmount, loan.rows[0].amount), newStatus, req.params.id, req.userId]
      );
    }

    if (req.markProcessed) await req.markProcessed();
    res.status(201).json({ message: 'Thêm thanh toán thành công' });
  } catch (err) {
    console.error('Create loan payment error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

module.exports = router;
