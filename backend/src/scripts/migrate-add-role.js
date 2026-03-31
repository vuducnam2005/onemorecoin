/**
 * Migration: Add role and isLocked columns to users table
 * Run: node src/scripts/migrate-add-role.js
 */
require('dotenv').config();
const { pool } = require('../config/database');

async function migrate() {
  const client = await pool.connect();
  try {
    console.log('Adding role column to users...');
    await client.query(`
      ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) DEFAULT 'user'
    `);
    console.log('✅ Added role column');

    console.log('Adding isLocked column to users...');
    await client.query(`
      ALTER TABLE users ADD COLUMN IF NOT EXISTS "isLocked" BOOLEAN DEFAULT false
    `);
    console.log('✅ Added isLocked column');

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
