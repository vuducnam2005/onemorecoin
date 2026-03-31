const jwt = require('jsonwebtoken');
const { pool } = require('../config/database');

/**
 * Admin Authorization Middleware
 * Verifies JWT token AND checks that user has role === 'admin'
 */
async function adminAuth(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Không có token xác thực' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = decoded.userId;
    req.username = decoded.username;

    // Check role in database
    const result = await pool.query(
      'SELECT role, "isLocked" FROM users WHERE id = $1',
      [decoded.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Người dùng không tồn tại' });
    }

    const user = result.rows[0];

    if (user.isLocked) {
      return res.status(403).json({ error: 'Tài khoản đã bị khóa' });
    }

    if (user.role !== 'admin') {
      return res.status(403).json({ error: 'Bạn không có quyền truy cập' });
    }

    next();
  } catch (err) {
    return res.status(401).json({ error: 'Token không hợp lệ hoặc đã hết hạn' });
  }
}

module.exports = adminAuth;
