const { pool } = require('../config/database');

/**
 * Idempotency Middleware (PostgreSQL)
 */
function idempotencyMiddleware(req, res, next) {
  const requestId = req.body?.requestId;

  if (!requestId) {
    return next();
  }

  req.requestId = requestId;

  req.checkIdempotency = async () => {
    try {
      const result = await pool.query(
        'SELECT id FROM processed_requests WHERE "requestId" = $1',
        [requestId]
      );
      return result.rows.length > 0;
    } catch (err) {
      console.error('Idempotency check error:', err);
      return false;
    }
  };

  req.markProcessed = async () => {
    try {
      await pool.query(
        `INSERT INTO processed_requests ("requestId", "userId", endpoint, "processedAt")
         VALUES ($1, $2, $3, NOW())
         ON CONFLICT ("requestId") DO NOTHING`,
        [requestId, req.userId || 'unknown', `${req.method} ${req.originalUrl}`]
      );
    } catch (err) {
      console.error('Mark processed error:', err);
    }
  };

  next();
}

module.exports = idempotencyMiddleware;
