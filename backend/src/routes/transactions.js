const express = require('express');
const { pool } = require('../config/database');
const authMiddleware = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

// GET /transactions
router.get('/', async (req, res) => {
  try {
    const { walletId, groupId, fromDate, toDate, limit } = req.query;
    let query = 'SELECT * FROM transactions_table WHERE "userId" = $1 AND ("isDeleted" = false OR "isDeleted" IS NULL)';
    const params = [req.userId];
    let paramIdx = 2;

    if (walletId) {
      query += ` AND "walletId" = $${paramIdx++}`;
      params.push(walletId);
    }
    if (groupId) {
      query += ` AND "groupId" = $${paramIdx++}`;
      params.push(groupId);
    }
    if (fromDate) {
      query += ` AND date >= $${paramIdx++}`;
      params.push(fromDate);
    }
    if (toDate) {
      query += ` AND date <= $${paramIdx++}`;
      params.push(toDate);
    }

    query += ' ORDER BY date DESC';

    if (limit) {
      query += ` LIMIT $${paramIdx++}`;
      params.push(parseInt(limit));
    }

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error('Get transactions error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// GET /transactions/:id
router.get('/:id', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM transactions_table WHERE id = $1 AND "userId" = $2 AND ("isDeleted" = false OR "isDeleted" IS NULL)',
      [req.params.id, req.userId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy giao dịch' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Get transaction error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// POST /transactions
router.post('/', async (req, res) => {
  try {
    if (req.checkIdempotency && await req.checkIdempotency()) {
      return res.status(409).json({ message: 'Request đã được xử lý' });
    }

    const { id, title, amount, unit, type, date, note, addToReport, notifyDate, walletId, groupId } = req.body;

    await pool.query(
      `INSERT INTO transactions_table (id, title, amount, unit, type, date, note, "addToReport", "notifyDate", "walletId", "groupId", "userId", "updatedAt")
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW())`,
      [id, title, amount, unit || 'VND', type || 'expense', date, note, addToReport !== undefined ? addToReport : true, notifyDate, walletId, groupId, req.userId]
    );

    if (req.markProcessed) await req.markProcessed();
    res.status(201).json({ message: 'Thêm giao dịch thành công', id });
  } catch (err) {
    console.error('Create transaction error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// PUT /transactions/:id
router.put('/:id', async (req, res) => {
  try {
    if (req.checkIdempotency && await req.checkIdempotency()) {
      return res.status(409).json({ message: 'Request đã được xử lý' });
    }

    const { title, amount, unit, type, date, note, addToReport, notifyDate, walletId, groupId, isDeleted } = req.body;

    await pool.query(
      `UPDATE transactions_table SET
        title = COALESCE($1, title),
        amount = COALESCE($2, amount),
        unit = COALESCE($3, unit),
        type = COALESCE($4, type),
        date = COALESCE($5, date),
        note = COALESCE($6, note),
        "addToReport" = COALESCE($7, "addToReport"),
        "notifyDate" = COALESCE($8, "notifyDate"),
        "walletId" = COALESCE($9, "walletId"),
        "groupId" = COALESCE($10, "groupId"),
        "isDeleted" = COALESCE($11, "isDeleted"),
        "updatedAt" = NOW()
       WHERE id = $12 AND "userId" = $13`,
      [title, amount, unit, type, date, note, addToReport, notifyDate, walletId, groupId, isDeleted, req.params.id, req.userId]
    );

    if (req.markProcessed) await req.markProcessed();
    res.json({ message: 'Cập nhật giao dịch thành công' });
  } catch (err) {
    console.error('Update transaction error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// DELETE /transactions/:id - Soft delete
router.delete('/:id', async (req, res) => {
  try {
    await pool.query(
      'UPDATE transactions_table SET "isDeleted" = true, "updatedAt" = NOW() WHERE id = $1 AND "userId" = $2',
      [req.params.id, req.userId]
    );
    res.json({ message: 'Xóa giao dịch thành công' });
  } catch (err) {
    console.error('Delete transaction error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// POST /transactions/sync - Bulk sync
router.post('/sync', async (req, res) => {
  try {
    const { transactions } = req.body;
    if (!Array.isArray(transactions)) {
      return res.status(400).json({ error: 'Dữ liệu không hợp lệ' });
    }

    let synced = 0;
    for (const t of transactions) {
      await pool.query(
        `INSERT INTO transactions_table (id, title, amount, unit, type, date, note, "addToReport", "notifyDate", "walletId", "groupId", "userId", "updatedAt")
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW())
         ON CONFLICT (id) DO UPDATE SET
           title = $2, amount = $3, unit = $4, type = $5, date = $6, note = $7,
           "addToReport" = $8, "notifyDate" = $9, "walletId" = $10, "groupId" = $11, "updatedAt" = NOW()`,
        [t.id, t.title, t.amount, t.unit || 'VND', t.type || 'expense', t.date, t.note, t.addToReport !== undefined ? t.addToReport : true, t.notifyDate, t.walletId, t.groupId, req.userId]
      );
      synced++;
    }

    res.json({ message: `Đồng bộ ${synced} giao dịch thành công` });
  } catch (err) {
    console.error('Sync transactions error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

module.exports = router;
