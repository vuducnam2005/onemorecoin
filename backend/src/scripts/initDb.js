/**
 * Database Initialization Script (PostgreSQL / Supabase)
 * Run this once to create all tables:
 *   node src/scripts/initDb.js
 */
require('dotenv').config();
const { pool } = require('../config/database');

async function initDatabase() {
  const client = await pool.connect();
  try {
    console.log('Connected to PostgreSQL. Creating tables...');

    // Users table
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(255) PRIMARY KEY,
        username VARCHAR(100) UNIQUE NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        "displayName" VARCHAR(255),
        role VARCHAR(20) DEFAULT 'user',
        "isLocked" BOOLEAN DEFAULT false,
        "createdAt" TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('✅ Table: users');

    // Wallets table
    await client.query(`
      CREATE TABLE IF NOT EXISTS wallets (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255),
        icon VARCHAR(255),
        currency VARCHAR(10) DEFAULT 'VND',
        balance DOUBLE PRECISION DEFAULT 0,
        "isReport" BOOLEAN DEFAULT true,
        "index" INT DEFAULT 0,
        "userId" VARCHAR(255) NOT NULL REFERENCES users(id),
        "isDeleted" BOOLEAN DEFAULT false,
        "updatedAt" TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('✅ Table: wallets');

    // Groups table
    await client.query(`
      CREATE TABLE IF NOT EXISTS groups (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255),
        type VARCHAR(50),
        icon VARCHAR(255),
        color VARCHAR(20),
        "parentId" INT,
        "index" INT DEFAULT 1,
        "userId" VARCHAR(255) NOT NULL REFERENCES users(id),
        "isDeleted" BOOLEAN DEFAULT false,
        "updatedAt" TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('✅ Table: groups');

    // Transactions table
    await client.query(`
      CREATE TABLE IF NOT EXISTS transactions_table (
        id VARCHAR(255) PRIMARY KEY,
        title VARCHAR(255),
        amount DOUBLE PRECISION,
        unit VARCHAR(10) DEFAULT 'VND',
        type VARCHAR(50),
        date VARCHAR(50),
        note TEXT,
        "addToReport" BOOLEAN DEFAULT true,
        "notifyDate" VARCHAR(50),
        "walletId" INT,
        "groupId" INT,
        "userId" VARCHAR(255) NOT NULL REFERENCES users(id),
        "isDeleted" BOOLEAN DEFAULT false,
        "updatedAt" TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('✅ Table: transactions_table');

    // Budgets table
    await client.query(`
      CREATE TABLE IF NOT EXISTS budgets (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255),
        budget DOUBLE PRECISION,
        unit VARCHAR(10) DEFAULT 'VND',
        type VARCHAR(50),
        "fromDate" VARCHAR(50),
        "toDate" VARCHAR(50),
        note TEXT,
        "isRepeat" BOOLEAN DEFAULT false,
        "walletId" INT,
        "groupId" INT,
        "budgetType" VARCHAR(50) DEFAULT 'month',
        "userId" VARCHAR(255) NOT NULL REFERENCES users(id),
        "isDeleted" BOOLEAN DEFAULT false,
        "updatedAt" TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('✅ Table: budgets');

    // Reminders table
    await client.query(`
      CREATE TABLE IF NOT EXISTS reminders (
        id VARCHAR(255) PRIMARY KEY,
        title VARCHAR(255),
        amount DOUBLE PRECISION,
        type VARCHAR(50),
        "dueDate" VARCHAR(50),
        "remindBeforeDays" INT DEFAULT 0,
        "remindTime" VARCHAR(10) DEFAULT '08:00',
        "isPaid" BOOLEAN DEFAULT false,
        note TEXT,
        "userId" VARCHAR(255) NOT NULL REFERENCES users(id),
        "isDeleted" BOOLEAN DEFAULT false,
        "updatedAt" TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('✅ Table: reminders');

    // Loans table
    await client.query(`
      CREATE TABLE IF NOT EXISTS loans (
        id VARCHAR(255) PRIMARY KEY,
        "personName" VARCHAR(255),
        amount DOUBLE PRECISION,
        "paidAmount" DOUBLE PRECISION DEFAULT 0,
        type VARCHAR(50),
        date VARCHAR(50),
        "dueDate" VARCHAR(50),
        note TEXT,
        status VARCHAR(50) DEFAULT 'unpaid',
        currency VARCHAR(10) DEFAULT 'VND',
        "walletId" INT,
        "phoneNumber" VARCHAR(50),
        "remindBeforeDays" INT,
        "remindTime" VARCHAR(10),
        "userId" VARCHAR(255) NOT NULL REFERENCES users(id),
        "isDeleted" BOOLEAN DEFAULT false,
        "updatedAt" TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('✅ Table: loans');

    // Loan Payments table
    await client.query(`
      CREATE TABLE IF NOT EXISTS loan_payments (
        id VARCHAR(255) PRIMARY KEY,
        "loanId" VARCHAR(255) REFERENCES loans(id),
        amount DOUBLE PRECISION,
        date VARCHAR(50),
        note TEXT,
        "walletId" INT,
        "userId" VARCHAR(255) NOT NULL REFERENCES users(id),
        "isDeleted" BOOLEAN DEFAULT false,
        "updatedAt" TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('✅ Table: loan_payments');

    // App Notifications table
    await client.query(`
      CREATE TABLE IF NOT EXISTS app_notifications (
        id VARCHAR(255) PRIMARY KEY,
        title VARCHAR(255),
        body TEXT,
        type VARCHAR(50),
        date VARCHAR(50),
        "isRead" BOOLEAN DEFAULT false,
        "referenceId" VARCHAR(255),
        "userId" VARCHAR(255) NOT NULL REFERENCES users(id)
      )
    `);
    console.log('✅ Table: app_notifications');

    // Processed Requests table (Idempotency)
    await client.query(`
      CREATE TABLE IF NOT EXISTS processed_requests (
        id SERIAL PRIMARY KEY,
        "requestId" VARCHAR(255) UNIQUE NOT NULL,
        "userId" VARCHAR(255),
        endpoint VARCHAR(500),
        "processedAt" TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('✅ Table: processed_requests');

    // Refresh Tokens table
    await client.query(`
      CREATE TABLE IF NOT EXISTS refresh_tokens (
        id SERIAL PRIMARY KEY,
        "userId" VARCHAR(255) NOT NULL REFERENCES users(id),
        token VARCHAR(255) UNIQUE NOT NULL,
        "deviceId" VARCHAR(255),
        "userAgent" VARCHAR(500),
        "expiresAt" TIMESTAMP,
        "createdAt" TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('✅ Table: refresh_tokens');

    // Data Deletion Requests table
    await client.query(`
      CREATE TABLE IF NOT EXISTS data_deletion_requests (
        id SERIAL PRIMARY KEY,
        "userId" VARCHAR(255) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        status VARCHAR(20) DEFAULT 'pending',
        "createdAt" TIMESTAMP DEFAULT NOW(),
        "processedAt" TIMESTAMP
      )
    `);
    console.log('✅ Table: data_deletion_requests');

    console.log('\n🎉 All tables created successfully!');
    process.exit(0);
  } catch (err) {
    console.error('❌ Database initialization failed:', err);
    process.exit(1);
  } finally {
    client.release();
  }
}

initDatabase();
