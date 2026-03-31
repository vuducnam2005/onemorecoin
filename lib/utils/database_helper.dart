import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expense_manager.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 10,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT';
    const integerType = 'INTEGER';
    const realType = 'REAL';

    if (oldVersion < 3) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS reminders (
  id $idType,
  title $textType,
  amount $realType,
  type $textType,
  dueDate $textType,
  remindBeforeDays $integerType,
  remindTime $textType,
  isPaid $integerType,
  note $textType
)
''');
    }
    if (oldVersion < 4) {
       // Allow adding remindTime to an existing reminders table in case it was created without it
      try {
        await db.execute('ALTER TABLE reminders ADD COLUMN remindTime $textType DEFAULT "08:00"');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 5) {
      // Loans table
      await db.execute('''
CREATE TABLE IF NOT EXISTS loans (
  id $idType,
  personName $textType,
  amount $realType,
  paidAmount $realType,
  type $textType,
  date $textType,
  dueDate $textType,
  note $textType,
  status $textType,
  currency $textType
)
''');

      // Loan payments table
      await db.execute('''
CREATE TABLE IF NOT EXISTS loan_payments (
  id $idType,
  loanId $textType,
  amount $realType,
  date $textType,
  note $textType
)
''');

      // Add color and parentId to groups table
      try {
        await db.execute('ALTER TABLE groups ADD COLUMN color $textType');
      } catch (e) {
        // Column might already exist
      }
      try {
        await db.execute('ALTER TABLE groups ADD COLUMN parentId $integerType');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 6) {
      // Add walletId to loans and loan_payments tables
      try {
        await db.execute('ALTER TABLE loans ADD COLUMN walletId $integerType');
      } catch (e) {
        // Column might already exist
      }
      try {
        await db.execute('ALTER TABLE loan_payments ADD COLUMN walletId $integerType');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 7) {
      // Add phoneNumber to loans table
      try {
        await db.execute('ALTER TABLE loans ADD COLUMN phoneNumber $textType');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 8) {
      // Add remindBeforeDays and remindTime to loans table
      try {
        await db.execute('ALTER TABLE loans ADD COLUMN remindBeforeDays $integerType');
      } catch (e) {
        // Column might already exist
      }
      try {
        await db.execute('ALTER TABLE loans ADD COLUMN remindTime $textType');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 9) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS app_notifications (
  id $idType,
  title $textType,
  body $textType,
  type $textType,
  date $textType,
  isRead $integerType,
  referenceId $textType
)
''');
    }
    if (oldVersion < 10) {
      // Pending Actions queue for offline sync
      await db.execute('''
CREATE TABLE IF NOT EXISTS pending_actions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tableName $textType,
  actionType $textType,
  recordId $textType,
  payload $textType,
  requestId $textType,
  status $textType DEFAULT 'pending',
  retryCount $integerType DEFAULT 0,
  createdAt $textType,
  lastAttempt $textType
)
''');

      // Add isDeleted and updatedAt to all data tables
      final tables = ['wallets', 'groups', 'transactions_table', 'budgets', 'reminders', 'loans', 'loan_payments'];
      for (final table in tables) {
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN isDeleted $integerType DEFAULT 0');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN updatedAt $textType');
        } catch (_) {}
      }
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const integerIdType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT';
    const integerType = 'INTEGER';
    const realType = 'REAL';

    // Users table
    await db.execute('''
CREATE TABLE users (
  id $textType PRIMARY KEY,
  username $textType,
  email $textType,
  password $textType
)
''');

    // Wallets table
    await db.execute('''
CREATE TABLE wallets (
  id $integerIdType,
  name $textType,
  icon $textType,
  currency $textType,
  balance $realType,
  isReport $integerType,
  "index" $integerType,
  isDeleted $integerType DEFAULT 0,
  updatedAt $textType
)
''');

    // Groups table
    await db.execute('''
CREATE TABLE groups (
  id $integerIdType,
  name $textType,
  icon $textType,
  type $textType,
  "index" $integerType,
  color $textType,
  parentId $integerType,
  isDeleted $integerType DEFAULT 0,
  updatedAt $textType
)
''');

    // Transactions table
    await db.execute('''
CREATE TABLE transactions_table (
  id $idType,
  title $textType,
  amount $realType,
  unit $textType,
  type $textType,
  date $textType,
  note $textType,
  addToReport $integerType,
  notifyDate $textType,
  walletId $integerType,
  groupId $integerType,
  isDeleted $integerType DEFAULT 0,
  updatedAt $textType,
  FOREIGN KEY (walletId) REFERENCES wallets (id),
  FOREIGN KEY (groupId) REFERENCES groups (id)
)
''');

    // Budgets table
    await db.execute('''
CREATE TABLE budgets (
  id $integerIdType,
  title $textType,
  budget $realType,
  unit $textType,
  type $textType,
  fromDate $textType,
  toDate $textType,
  note $textType,
  isRepeat $integerType,
  walletId $integerType,
  groupId $integerType,
  budgetType $textType,
  isDeleted $integerType DEFAULT 0,
  updatedAt $textType,
  FOREIGN KEY (walletId) REFERENCES wallets (id),
  FOREIGN KEY (groupId) REFERENCES groups (id)
)
''');

    // Reminders table
    await db.execute('''
CREATE TABLE reminders (
  id $idType,
  title $textType,
  amount $realType,
  type $textType,
  dueDate $textType,
  remindBeforeDays $integerType,
  remindTime $textType,
  isPaid $integerType,
  note $textType,
  isDeleted $integerType DEFAULT 0,
  updatedAt $textType
)
''');

    // Loans table
    await db.execute('''
CREATE TABLE loans (
  id $idType,
  personName $textType,
  amount $realType,
  paidAmount $realType,
  type $textType,
  date $textType,
  dueDate $textType,
  note $textType,
  status $textType,
  currency $textType,
  walletId $integerType,
  phoneNumber $textType,
  remindBeforeDays $integerType,
  remindTime $textType,
  isDeleted $integerType DEFAULT 0,
  updatedAt $textType
)
''');

    // Loan payments table
    await db.execute('''
CREATE TABLE loan_payments (
  id $idType,
  loanId $textType,
  amount $realType,
  date $textType,
  note $textType,
  walletId $integerType,
  isDeleted $integerType DEFAULT 0,
  updatedAt $textType
)
''');

    // App Notifications table
    await db.execute('''
CREATE TABLE app_notifications (
  id $idType,
  title $textType,
  body $textType,
  type $textType,
  date $textType,
  isRead $integerType,
  referenceId $textType
)
''');

    // Pending Actions queue for offline sync
    await db.execute('''
CREATE TABLE pending_actions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tableName $textType,
  actionType $textType,
  recordId $textType,
  payload $textType,
  requestId $textType,
  status $textType DEFAULT 'pending',
  retryCount $integerType DEFAULT 0,
  createdAt $textType,
  lastAttempt $textType
)
''');
  }

  /// Xoá toàn bộ dữ liệu (trừ bảng users)
  /// Dùng khi đăng xuất hoặc chuyển tài khoản để tránh lộ dữ liệu
  Future<void> clearUserData() async {
    final db = await instance.database;
    await db.delete('pending_actions');
    await db.delete('loan_payments');
    await db.delete('loans');
    await db.delete('transactions_table');
    await db.delete('budgets');
    await db.delete('reminders');
    await db.delete('groups');
    await db.delete('wallets');
    await db.delete('app_notifications');
  }

  Future close() async {
    final db = await instance.database;
    _database = null;
    await db.close();
  }
}
