import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class BackupHelper {
  /// Sao lưu database ra file .db và chia sẻ
  static Future<File?> backupDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final dbFilePath = p.join(dbPath, 'expense_manager.db');
      final dbFile = File(dbFilePath);

      if (!await dbFile.exists()) return null;

      final dir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupPath = '${dir.path}/onemorecoin_backup_$timestamp.db';

      final backupFile = await dbFile.copy(backupPath);
      return backupFile;
    } catch (e) {
      return null;
    }
  }

  /// Chia sẻ file backup
  static Future<void> shareBackup(File file) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  /// Khôi phục database từ file .db được chọn
  /// Trả về true nếu thành công
  static Future<bool> restoreDatabase() async {
    try {
      // Chọn file backup
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) return false;

      final pickedFile = result.files.first;
      if (pickedFile.path == null) return false;

      final sourceFile = File(pickedFile.path!);
      if (!await sourceFile.exists()) return false;

      // Đóng database hiện tại
      await DatabaseHelper.instance.close();

      // Copy file backup đè lên database hiện tại
      final dbPath = await getDatabasesPath();
      final dbFilePath = p.join(dbPath, 'expense_manager.db');

      await sourceFile.copy(dbFilePath);

      // Database sẽ tự mở lại khi được truy cập lần tiếp theo
      // qua DatabaseHelper.instance.database

      return true;
    } catch (e) {
      return false;
    }
  }
}
