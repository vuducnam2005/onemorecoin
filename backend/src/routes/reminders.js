const express = require('express');
const { pool } = require('../config/database');
const authMiddleware = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

// GET /reminders
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM reminders WHERE "userId" = $1 AND ("isDeleted" = false OR "isDeleted" IS NULL) ORDER BY "dueDate" ASC',
      [req.userId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Get reminders error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// POST /reminders
router.post('/', async (req, res) => {
  try {
    if (req.checkIdempotency && await req.checkIdempotency()) {
      return res.status(409).json({ message: 'Request đã được xử lý' });
    }

    const { id, title, amount, type, dueDate, remindBeforeDays, remindTime, isPaid, note } = req.body;

    await pool.query(
      `INSERT INTO reminders (id, title, amount, type, "dueDate", "remindBeforeDays", "remindTime", "isPaid", note, "userId", "updatedAt")
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW())`,
      [id, title, amount, type, dueDate, remindBeforeDays || 0, remindTime || '08:00', isPaid || false, note, req.userId]
    );

    if (req.markProcessed) await req.markProcessed();
    res.status(201).json({ message: 'Thêm nhắc nhở thành công', id });
  } catch (err) {
    console.error('Create reminder error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// PUT /reminders/:id
router.put('/:id', async (req, res) => {
  try {
    if (req.checkIdempotency && await req.checkIdempotency()) {
      return res.status(409).json({ message: 'Request đã được xử lý' });
    }

    const { title, amount, type, dueDate, remindBeforeDays, remindTime, isPaid, note, isDeleted } = req.body;

    await pool.query(
      `UPDATE reminders SET
        title = COALESCE($1, title),
        amount = COALESCE($2, amount),
        type = COALESCE($3, type),
        "dueDate" = COALESCE($4, "dueDate"),
        "remindBeforeDays" = COALESCE($5, "remindBeforeDays"),
        "remindTime" = COALESCE($6, "remindTime"),
        "isPaid" = COALESCE($7, "isPaid"),
        note = COALESCE($8, note),
        "isDeleted" = COALESCE($9, "isDeleted"),
        "updatedAt" = NOW()
       WHERE id = $10 AND "userId" = $11`,
      [title, amount, type, dueDate, remindBeforeDays, remindTime, isPaid, note, isDeleted, req.params.id, req.userId]
    );

    if (req.markProcessed) await req.markProcessed();
    res.json({ message: 'Cập nhật nhắc nhở thành công' });
  } catch (err) {
    console.error('Update reminder error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// DELETE /reminders/:id - Soft delete
router.delete('/:id', async (req, res) => {
  try {
    await pool.query(
      'UPDATE reminders SET "isDeleted" = true, "updatedAt" = NOW() WHERE id = $1 AND "userId" = $2',
      [req.params.id, req.userId]
    );
    res.json({ message: 'Xóa nhắc nhở thành công' });
  } catch (err) {
    console.error('Delete reminder error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

module.exports = router;
