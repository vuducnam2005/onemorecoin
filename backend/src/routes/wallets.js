const express = require('express');
const { pool } = require('../config/database');
const authMiddleware = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

// GET /wallets
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM wallets WHERE "userId" = $1 AND ("isDeleted" = false OR "isDeleted" IS NULL) ORDER BY "index" ASC',
      [req.userId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Get wallets error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// GET /wallets/:id
router.get('/:id', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM wallets WHERE id = $1 AND "userId" = $2 AND ("isDeleted" = false OR "isDeleted" IS NULL)',
      [req.params.id, req.userId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy ví' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Get wallet error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// POST /wallets
router.post('/', async (req, res) => {
  try {
    if (req.checkIdempotency && await req.checkIdempotency()) {
      return res.status(409).json({ message: 'Request đã được xử lý' });
    }

    const { name, icon, currency, balance, isReport } = req.body;

    const result = await pool.query(
      `INSERT INTO wallets (name, icon, currency, balance, "isReport", "userId", "index", "updatedAt")
       VALUES ($1, $2, $3, $4, $5, $6, 0, NOW())
       RETURNING *`,
      [name, icon, currency || 'VND', balance || 0, isReport !== undefined ? isReport : true, req.userId]
    );

    if (req.markProcessed) await req.markProcessed();
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Create wallet error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// PUT /wallets/:id
router.put('/:id', async (req, res) => {
  try {
    if (req.checkIdempotency && await req.checkIdempotency()) {
      return res.status(409).json({ message: 'Request đã được xử lý' });
    }

    const { name, icon, currency, balance, isReport, isDeleted } = req.body;

    await pool.query(
      `UPDATE wallets SET
        name = COALESCE($1, name),
        icon = COALESCE($2, icon),
        currency = COALESCE($3, currency),
        balance = COALESCE($4, balance),
        "isReport" = COALESCE($5, "isReport"),
        "isDeleted" = COALESCE($6, "isDeleted"),
        "updatedAt" = NOW()
       WHERE id = $7 AND "userId" = $8`,
      [name, icon, currency, balance, isReport, isDeleted, req.params.id, req.userId]
    );

    if (req.markProcessed) await req.markProcessed();
    res.json({ message: 'Cập nhật ví thành công' });
  } catch (err) {
    console.error('Update wallet error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// DELETE /wallets/:id - Soft delete
router.delete('/:id', async (req, res) => {
  try {
    const walletId = req.params.id;

    await pool.query(
      `UPDATE wallets SET "isDeleted" = true, "updatedAt" = NOW() WHERE id = $1 AND "userId" = $2`,
      [walletId, req.userId]
    );
    await pool.query(
      `UPDATE transactions_table SET "isDeleted" = true, "updatedAt" = NOW() WHERE "walletId" = $1 AND "userId" = $2`,
      [walletId, req.userId]
    );
    await pool.query(
      `UPDATE budgets SET "isDeleted" = true, "updatedAt" = NOW() WHERE "walletId" = $1 AND "userId" = $2`,
      [walletId, req.userId]
    );

    res.json({ message: 'Xóa ví thành công' });
  } catch (err) {
    console.error('Delete wallet error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

module.exports = router;
