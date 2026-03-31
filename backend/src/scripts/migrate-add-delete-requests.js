/**
 * Migration: Add data_deletion_requests table
 * Run: node src/scripts/migrate-add-delete-requests.js
 */
require('dotenv').config();
const { pool } = require('../config/database');

async function migrate() {
  const client = await pool.connect();
  try {
    console.log('Creating data_deletion_requests table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS data_deletion_requests (
        id SERIAL PRIMARY KEY,
        "userId" VARCHAR(255) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        status VARCHAR(20) DEFAULT 'pending',
        "createdAt" TIMESTAMP DEFAULT NOW(),
        "processedAt" TIMESTAMP
      )
    `);
    console.log('✅ Table: data_deletion_requests created');

    console.log('\n🎉 Migration completed successfully!');
    process.exit(0);
  } catch (err) {
    console.error('❌ Migration failed:', err);
    process.exit(1);
  } finally {
    client.release();
  }
}

migrate();
