/**
 * Script to promote a user to admin role
 * Usage: node src/scripts/make-admin.js <username_or_email>
 */
require('dotenv').config();
const { pool } = require('../config/database');

async function makeAdmin() {
  const identifier = process.argv[2];

  if (!identifier) {
    console.error('❌ Vui lòng cung cấp username hoặc email của user muốn cấp quyền admin.');
    console.log('Ví dụ: node src/scripts/make-admin.js admin_user');
    process.exit(1);
  }

  const client = await pool.connect();
  try {
    const result = await client.query(
      `UPDATE users 
       SET role = 'admin' 
       WHERE username = $1 OR email = $1 
       RETURNING id, username, email, role`,
      [identifier]
    );

    if (result.rows.length === 0) {
      console.error(`❌ Không tìm thấy user với username hoặc email: ${identifier}`);
      process.exit(1);
    }

    const user = result.rows[0];
    console.log(`✅ Thành công! Đã cấp quyền admin cho:`);
    console.log(`   - ID: ${user.id}`);
    console.log(`   - Username: ${user.username}`);
    console.log(`   - Email: ${user.email}`);
    process.exit(0);
  } catch (err) {
    console.error('❌ Lỗi cập nhật:', err);
    process.exit(1);
  } finally {
    client.release();
  }
}

makeAdmin();
