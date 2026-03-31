const jwt = require('jsonwebtoken');
const { pool } = require('../config/database');

async function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Không có token xác thực' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Check if user is locked to immediately invalidate active sessions
    const result = await pool.query('SELECT "isLocked" FROM users WHERE id = $1', [decoded.userId]);
    if (result.rows.length === 0 || result.rows[0].isLocked) {
      return res.status(403).json({ error: 'Tài khoản đã bị khóa.' });
    }

    req.userId = decoded.userId;
    req.username = decoded.username;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Token không hợp lệ hoặc đã hết hạn' });
  }
}

module.exports = authMiddleware;
