const { v4: uuidv4 } = require('uuid');

/**
 * Request ID Middleware
 * 
 * Tạo unique requestId cho mỗi request đến API.
 * Gắn vào header x-request-id để dùng trong logging.
 */
function requestIdMiddleware(req, res, next) {
  req.id = req.headers['x-request-id'] || uuidv4();
  res.setHeader('x-request-id', req.id);
  next();
}

module.exports = requestIdMiddleware;
