const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../config/database');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

const ACCESS_TOKEN_EXPIRY = '15m';
const REFRESH_TOKEN_EXPIRY_DAYS = 30;

function generateAccessToken(userId, username) {
  return jwt.sign(
    { userId, username },
    process.env.JWT_SECRET,
    { expiresIn: ACCESS_TOKEN_EXPIRY }
  );
}

async function generateRefreshToken(userId, deviceId, userAgent) {
  const token = uuidv4();
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + REFRESH_TOKEN_EXPIRY_DAYS);

  await pool.query(
    `INSERT INTO refresh_tokens ("userId", token, "deviceId", "userAgent", "expiresAt")
     VALUES ($1, $2, $3, $4, $5)`,
    [userId, token, deviceId || 'unknown', userAgent || 'unknown', expiresAt]
  );

  return token;
}

// POST /auth/register
router.post('/register', async (req, res) => {
  try {
    const { username, email, password, displayName, deviceId } = req.body;
    const userAgent = req.headers['user-agent'];

    if (!username || !email || !password) {
      return res.status(400).json({ error: 'Vui lòng điền đầy đủ thông tin' });
    }

    // Check existing username
    const usernameCheck = await pool.query('SELECT id FROM users WHERE username = $1', [username]);
    if (usernameCheck.rows.length > 0) {
      return res.status(409).json({ error: 'Tên đăng nhập đã tồn tại' });
    }

    // Check existing email
    const emailCheck = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
    if (emailCheck.rows.length > 0) {
      return res.status(409).json({ error: 'Email đã được sử dụng' });
    }

    let id;
    let isUnique = false;
    while (!isUnique) {
      const randomDigits = Math.floor(10000 + Math.random() * 90000);
      id = `17710${randomDigits}`;
      const idCheck = await pool.query('SELECT id FROM users WHERE id = $1', [id]);
      if (idCheck.rows.length === 0) {
        isUnique = true;
      }
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    await pool.query(
      `INSERT INTO users (id, username, email, password, "displayName")
       VALUES ($1, $2, $3, $4, $5)`,
      [id, username, email, hashedPassword, displayName || username]
    );

    const accessToken = generateAccessToken(id, username);
    const refreshToken = await generateRefreshToken(id, deviceId, userAgent);

    res.status(201).json({
      message: 'Đăng ký thành công',
      token: accessToken,
      refreshToken,
      user: { id, username, email, displayName: displayName || username, role: 'user' },
    });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// POST /auth/login
router.post('/login', async (req, res) => {
  try {
    const { username, password, deviceId } = req.body;
    const userAgent = req.headers['user-agent'];

    if (!username || !password) {
      return res.status(400).json({ error: 'Vui lòng điền đầy đủ thông tin' });
    }

    const result = await pool.query(
      'SELECT * FROM users WHERE username = $1 OR email = $1',
      [username]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Sai tên đăng nhập hoặc mật khẩu' });
    }

    const user = result.rows[0];

    // Check if account is locked
    if (user.isLocked) {
      return res.status(403).json({ error: 'Tài khoản đã bị khóa. Liên hệ admin để được hỗ trợ.' });
    }

    const isMatch = await bcrypt.compare(password, user.password);

    if (!isMatch) {
      return res.status(401).json({ error: 'Sai tên đăng nhập hoặc mật khẩu' });
    }

    const accessToken = generateAccessToken(user.id, user.username);
    const refreshToken = await generateRefreshToken(user.id, deviceId, userAgent);

    res.json({
      message: 'Đăng nhập thành công',
      token: accessToken,
      refreshToken,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        displayName: user.displayName,
        role: user.role,
      },
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// POST /auth/refresh
router.post('/refresh', async (req, res) => {
  try {
    const { refreshToken, deviceId } = req.body;
    const userAgent = req.headers['user-agent'];

    if (!refreshToken) {
      return res.status(400).json({ error: 'Thiếu refresh token' });
    }

    const result = await pool.query('SELECT * FROM refresh_tokens WHERE token = $1', [refreshToken]);

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Refresh token không hợp lệ' });
    }

    const tokenRecord = result.rows[0];

    if (new Date(tokenRecord.expiresAt) < new Date()) {
      await pool.query('DELETE FROM refresh_tokens WHERE id = $1', [tokenRecord.id]);
      return res.status(401).json({ error: 'Refresh token đã hết hạn' });
    }

    // Rotation: delete old, create new
    await pool.query('DELETE FROM refresh_tokens WHERE id = $1', [tokenRecord.id]);

    const userResult = await pool.query(
      'SELECT id, username, email, "displayName" FROM users WHERE id = $1',
      [tokenRecord.userId]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({ error: 'Người dùng không tồn tại' });
    }

    const user = userResult.rows[0];
    const newAccessToken = generateAccessToken(user.id, user.username);
    const newRefreshToken = await generateRefreshToken(user.id, deviceId, userAgent);

    res.json({
      message: 'Token đã được làm mới',
      token: newAccessToken,
      refreshToken: newRefreshToken,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        displayName: user.displayName,
      },
    });
  } catch (err) {
    console.error('Refresh token error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// POST /auth/logout
router.post('/logout', authMiddleware, async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (refreshToken) {
      await pool.query(
        'DELETE FROM refresh_tokens WHERE token = $1 AND "userId" = $2',
        [refreshToken, req.userId]
      );
    } else {
      await pool.query('DELETE FROM refresh_tokens WHERE "userId" = $1', [req.userId]);
    }

    res.json({ message: 'Đăng xuất thành công' });
  } catch (err) {
    console.error('Logout error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// PUT /auth/change-password
router.put('/change-password', authMiddleware, async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;

    const result = await pool.query('SELECT password FROM users WHERE id = $1', [req.userId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Người dùng không tồn tại' });
    }

    const isMatch = await bcrypt.compare(oldPassword, result.rows[0].password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Mật khẩu cũ không chính xác' });
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await pool.query('UPDATE users SET password = $1 WHERE id = $2', [hashedPassword, req.userId]);

    res.json({ message: 'Đổi mật khẩu thành công' });
  } catch (err) {
    console.error('Change password error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// GET /auth/profile
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, username, email, "displayName" FROM users WHERE id = $1',
      [req.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Người dùng không tồn tại' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Profile error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// PUT /auth/profile
router.put('/profile', authMiddleware, async (req, res) => {
  try {
    const { displayName, username: newUsername } = req.body;

    if (newUsername) {
      const check = await pool.query(
        'SELECT id FROM users WHERE username = $1 AND id != $2',
        [newUsername, req.userId]
      );
      if (check.rows.length > 0) {
        return res.status(409).json({ error: 'Tên đăng nhập đã tồn tại' });
      }
    }

    await pool.query(
      `UPDATE users SET
        "displayName" = COALESCE($1, "displayName"),
        username = COALESCE($2, username)
       WHERE id = $3`,
      [displayName, newUsername, req.userId]
    );

    res.json({ message: 'Cập nhật thành công' });
  } catch (err) {
    console.error('Update profile error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// ========================
// DATA DELETION REQUESTS
// ========================

// POST /auth/request-delete-data — User gửi yêu cầu xoá dữ liệu
router.post('/request-delete-data', authMiddleware, async (req, res) => {
  try {
    // Check if there's already a pending request
    const existing = await pool.query(
      `SELECT id, status, "createdAt" FROM data_deletion_requests WHERE "userId" = $1 AND status = 'pending'`,
      [req.userId]
    );

    if (existing.rows.length > 0) {
      return res.status(400).json({ 
        error: 'Bạn đã có yêu cầu đang chờ phê duyệt',
        request: existing.rows[0]
      });
    }

    const result = await pool.query(
      `INSERT INTO data_deletion_requests ("userId", status) VALUES ($1, 'pending') RETURNING *`,
      [req.userId]
    );

    res.status(201).json({
      message: 'Đã gửi yêu cầu xoá dữ liệu. Vui lòng chờ Admin phê duyệt.',
      request: result.rows[0],
    });
  } catch (err) {
    console.error('Request delete data error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// GET /auth/delete-request-status — User kiểm tra trạng thái yêu cầu
router.get('/delete-request-status', authMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, status, "createdAt", "processedAt" FROM data_deletion_requests WHERE "userId" = $1 ORDER BY "createdAt" DESC LIMIT 1`,
      [req.userId]
    );

    if (result.rows.length === 0) {
      return res.json({ hasRequest: false });
    }

    res.json({
      hasRequest: true,
      request: result.rows[0],
    });
  } catch (err) {
    console.error('Get delete request status error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

// DELETE /auth/withdraw-delete-request — User thu hồi yêu cầu
router.delete('/withdraw-delete-request', authMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `DELETE FROM data_deletion_requests WHERE "userId" = $1 AND status = 'pending' RETURNING id`,
      [req.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Không có yêu cầu nào đang chờ để thu hồi' });
    }

    res.json({ message: 'Đã thu hồi yêu cầu xoá dữ liệu' });
  } catch (err) {
    console.error('Withdraw delete request error:', err);
    res.status(500).json({ error: 'Lỗi hệ thống' });
  }
});

module.exports = router;
