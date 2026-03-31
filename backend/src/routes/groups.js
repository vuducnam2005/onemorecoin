const express = require('express');
const { pool } = require('../config/database');
const authMiddleware = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

// GET /groups
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM groups WHERE "userId" = $1 AND ("isDeleted" = false OR "isDeleted" IS NULL) ORDER BY "index" DESC',
      [req.userId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Get groups error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// POST /groups
router.post('/', async (req, res) => {
  try {
    if (req.checkIdempotency && await req.checkIdempotency()) {
      return res.status(409).json({ message: 'Request đã được xử lý' });
    }

    const { name, type, icon, color, parentId, index } = req.body;

    const result = await pool.query(
      `INSERT INTO groups (name, type, icon, color, "parentId", "index", "userId", "updatedAt")
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
       RETURNING *`,
      [name, type || 'expense', icon, color, parentId, index || 1, req.userId]
    );

    if (req.markProcessed) await req.markProcessed();
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Create group error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// PUT /groups/:id
router.put('/:id', async (req, res) => {
  try {
    if (req.checkIdempotency && await req.checkIdempotency()) {
      return res.status(409).json({ message: 'Request đã được xử lý' });
    }

    const { name, type, icon, color, parentId, isDeleted } = req.body;

    await pool.query(
      `UPDATE groups SET
        name = COALESCE($1, name),
        type = COALESCE($2, type),
        icon = COALESCE($3, icon),
        color = COALESCE($4, color),
        "parentId" = COALESCE($5, "parentId"),
        "isDeleted" = COALESCE($6, "isDeleted"),
        "updatedAt" = NOW()
       WHERE id = $7 AND "userId" = $8`,
      [name, type, icon, color, parentId, isDeleted, req.params.id, req.userId]
    );

    if (req.markProcessed) await req.markProcessed();
    res.json({ message: 'Cập nhật nhóm thành công' });
  } catch (err) {
    console.error('Update group error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// DELETE /groups/:id - Soft delete
router.delete('/:id', async (req, res) => {
  try {
    await pool.query(
      'UPDATE groups SET "isDeleted" = true, "updatedAt" = NOW() WHERE id = $1 AND "userId" = $2',
      [req.params.id, req.userId]
    );
    res.json({ message: 'Xóa nhóm thành công' });
  } catch (err) {
    console.error('Delete group error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// POST /groups/init
router.post('/init', async (req, res) => {
  try {
    const existing = await pool.query(
      'SELECT COUNT(*) as count FROM groups WHERE "userId" = $1 AND ("isDeleted" = false OR "isDeleted" IS NULL)',
      [req.userId]
    );

    if (parseInt(existing.rows[0].count) > 0) {
      return res.json({ message: 'Nhóm mặc định đã được tạo' });
    }

    const defaultGroups = [
      { name: 'Ăn uống', type: 'expense', icon: '59555', color: '#FF5722' },
      { name: 'Di chuyển', type: 'expense', icon: '57756', color: '#2196F3' },
      { name: 'Mua sắm', type: 'expense', icon: '59597', color: '#E91E63' },
      { name: 'Sức khỏe', type: 'expense', icon: '59518', color: '#F44336' },
      { name: 'Giải trí', type: 'expense', icon: '58923', color: '#9C27B0' },
      { name: 'Tiền nhà', type: 'expense', icon: '59530', color: '#795548' },
      { name: 'Tiền nước', type: 'expense', icon: '60048', color: '#00BCD4' },
      { name: 'Tiền internet', type: 'expense', icon: '58956', color: '#3F51B5' },
      { name: 'Tiền điện thoại', type: 'expense', icon: '59473', color: '#607D8B' },
      { name: 'Tiền học', type: 'expense', icon: '59583', color: '#FF9800' },
      { name: 'Tiền khác', type: 'expense', icon: '57424', color: '#9E9E9E' },
      { name: 'Lương', type: 'income', icon: '57739', color: '#4CAF50' },
      { name: 'Thưởng', type: 'income', icon: '58260', color: '#FFEB3B' },
      { name: 'Lãi', type: 'income', icon: '58893', color: '#8BC34A' },
      { name: 'Bán đồ', type: 'income', icon: '58737', color: '#FF9800' },
      { name: 'Khác', type: 'income', icon: '57424', color: '#9E9E9E' },
    ];

    for (const g of defaultGroups) {
      await pool.query(
        `INSERT INTO groups (name, type, icon, color, "index", "userId", "updatedAt")
         VALUES ($1, $2, $3, $4, 1, $5, NOW())`,
        [g.name, g.type, g.icon, g.color, req.userId]
      );
    }

    res.status(201).json({ message: 'Đã tạo nhóm mặc định' });
  } catch (err) {
    console.error('Init groups error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

module.exports = router;
