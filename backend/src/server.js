require('dotenv').config();
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const winston = require('winston');
const morgan = require('morgan');
const requestIdMiddleware = require('./middleware/requestId');
const idempotencyMiddleware = require('./middleware/idempotency');

const authRoutes = require('./routes/auth');
const walletRoutes = require('./routes/wallets');
const groupRoutes = require('./routes/groups');
const transactionRoutes = require('./routes/transactions');
const budgetRoutes = require('./routes/budgets');
const loanRoutes = require('./routes/loans');
const reminderRoutes = require('./routes/reminders');
const syncRoutes = require('./routes/sync');

const app = express();
const PORT = process.env.PORT || 3000;

// ========================
// WINSTON LOGGER
// ========================
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error',
      maxsize: 5 * 1024 * 1024, // 5MB
      maxFiles: 5,
    }),
    new winston.transports.File({
      filename: 'logs/combined.log',
      maxsize: 5 * 1024 * 1024, // 5MB
      maxFiles: 14,
    }),
  ],
});

// Console logging in development
if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    ),
  }));
}

// Make logger globally accessible
app.locals.logger = logger;

// ========================
// RATE LIMITING
// ========================

// Global rate limit: 100 req/min/IP
const globalLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Quá nhiều yêu cầu. Vui lòng thử lại sau.' },
  keyGenerator: (req) => {
    // Rate limit theo userId nếu đã xác thực, fallback về IP
    return req.userId || req.ip;
  },
});

// Auth rate limit: 5 req/min/IP (chống brute-force)
const authLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Quá nhiều lần thử đăng nhập. Vui lòng thử lại sau 1 phút.' },
});

// Sync rate limit: 10 req/min/user
const syncLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Đồng bộ quá thường xuyên. Vui lòng thử lại sau.' },
  keyGenerator: (req) => req.userId || req.ip,
});

// ========================
// MIDDLEWARE
// ========================
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(requestIdMiddleware);
app.use(globalLimiter);

// Morgan HTTP logging with requestId
const morganFormat = ':method :url :status :response-time ms - :req[x-request-id]';
app.use(morgan(morganFormat, {
  stream: {
    write: (message) => logger.info(message.trim()),
  },
}));

// Idempotency middleware (cho tất cả POST/PUT/DELETE routes)
app.use(idempotencyMiddleware);

// ========================
// ROUTES
// ========================
app.use('/auth', authLimiter, authRoutes);
app.use('/wallets', walletRoutes);
app.use('/groups', groupRoutes);
app.use('/transactions', transactionRoutes);
app.use('/budgets', budgetRoutes);
app.use('/loans', loanRoutes);
app.use('/reminders', reminderRoutes);
app.use('/sync', syncLimiter, syncRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    requestId: req.id,
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint không tồn tại' });
});

// Error handler
app.use((err, req, res, next) => {
  logger.error({
    message: err.message,
    stack: err.stack,
    requestId: req.id,
    userId: req.userId,
    method: req.method,
    url: req.originalUrl,
  });
  res.status(500).json({ error: 'Lỗi hệ thống', requestId: req.id });
});

app.listen(PORT, () => {
  logger.info(`🚀 OnMoreCoin API Server running on port ${PORT}`);
  logger.info(`📍 http://localhost:${PORT}`);
  logger.info(`❤️  Health check: http://localhost:${PORT}/health`);
});
