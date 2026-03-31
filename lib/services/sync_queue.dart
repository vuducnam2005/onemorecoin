import 'dart:convert';
import 'dart:math';
import 'package:onemorecoin/services/api_service.dart';
import 'package:onemorecoin/services/api_config.dart';
import 'package:onemorecoin/utils/database_helper.dart';
import 'package:uuid/uuid.dart';

/// Sync Queue - Hàng đợi đồng bộ offline-first
///
/// Flow: User action → lưu local SQLite → push vào queue → background sync
/// Hỗ trợ: Merge actions, Retry + Jitter, Dead queue skip, Idempotency
class SyncQueue {
  static final SyncQueue instance = SyncQueue._();
  SyncQueue._();

  static const int _maxRetries = 5;
  static const int _baseDelayMs = 1000;
  static const int _maxJitterMs = 500;

  bool _isProcessing = false;
  final _uuid = const Uuid();

  /// Thêm action vào queue với logic merge thông minh
  ///
  /// Merge rules:
  /// - create → update → update = giữ 1 create (payload mới nhất)
  /// - update → update = giữ 1 update (payload mới nhất)
  /// - create → delete = xóa luôn khỏi queue (không cần sync)
  /// - update → delete = thay bằng 1 delete
  Future<void> enqueue({
    required String tableName,
    required String actionType, // 'create', 'update', 'delete'
    required String recordId,
    required Map<String, dynamic> payload,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // Tìm action cùng tableName + recordId đang pending
    final existing = await db.query(
      'pending_actions',
      where: 'tableName = ? AND recordId = ? AND status = ?',
      whereArgs: [tableName, recordId, 'pending'],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final existingAction = existing.first;
      final existingType = existingAction['actionType'] as String;
      final existingId = existingAction['id'] as int;

      // Merge logic
      if (actionType == 'delete') {
        if (existingType == 'create') {
          // create → delete = xóa luôn, không cần sync
          await db.delete('pending_actions', where: 'id = ?', whereArgs: [existingId]);
          return;
        } else {
          // update → delete = thay bằng delete
          await db.update(
            'pending_actions',
            {
              'actionType': 'delete',
              'payload': jsonEncode(payload),
              'requestId': _uuid.v4(),
              'lastAttempt': null,
              'retryCount': 0,
            },
            where: 'id = ?',
            whereArgs: [existingId],
          );
          return;
        }
      } else if (actionType == 'update') {
        if (existingType == 'create') {
          // create → update = giữ create, cập nhật payload
          await db.update(
            'pending_actions',
            {
              'payload': jsonEncode(payload),
              'requestId': _uuid.v4(),
            },
            where: 'id = ?',
            whereArgs: [existingId],
          );
          return;
        } else {
          // update → update = gộp, giữ payload mới nhất
          await db.update(
            'pending_actions',
            {
              'payload': jsonEncode(payload),
              'requestId': _uuid.v4(),
              'lastAttempt': null,
              'retryCount': 0,
            },
            where: 'id = ?',
            whereArgs: [existingId],
          );
          return;
        }
      }
    }

    // Không có gì để merge → insert mới
    await db.insert('pending_actions', {
      'tableName': tableName,
      'actionType': actionType,
      'recordId': recordId,
      'payload': jsonEncode(payload),
      'requestId': _uuid.v4(),
      'status': 'pending',
      'retryCount': 0,
      'createdAt': DateTime.now().toIso8601String(),
      'lastAttempt': null,
    });

    // Tự động trigger process queue
    processQueue();
  }

  /// Xử lý toàn bộ queue (FIFO, skip dead items)
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final isOnline = await ApiService.instance.isServerReachable();
      if (!isOnline) {
        _isProcessing = false;
        return;
      }

      while (true) {
        final db = await DatabaseHelper.instance.database;

        // Lấy item pending tiếp theo (FIFO)
        final items = await db.query(
          'pending_actions',
          where: 'status = ?',
          whereArgs: ['pending'],
          orderBy: 'id ASC',
          limit: 1,
        );

        if (items.isEmpty) break;

        final item = items.first;
        final id = item['id'] as int;
        final retryCount = item['retryCount'] as int? ?? 0;

        // Dead queue: skip nếu quá max retries
        if (retryCount >= _maxRetries) {
          await db.update(
            'pending_actions',
            {'status': 'failed'},
            where: 'id = ?',
            whereArgs: [id],
          );
          print('[SyncQueue] ❌ Skipped dead item #$id (${item['tableName']}/${item['recordId']}) after $_maxRetries retries');
          continue; // Xử lý item tiếp theo, KHÔNG kẹt
        }

        // Đánh dấu đang sync
        await db.update(
          'pending_actions',
          {'status': 'syncing', 'lastAttempt': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [id],
        );

        // Gửi lên server
        final success = await _sendToServer(item);

        if (success) {
          // Thành công → xóa khỏi queue
          await db.delete('pending_actions', where: 'id = ?', whereArgs: [id]);
        } else {
          // Thất bại → tăng retryCount, quay về pending
          final newRetryCount = retryCount + 1;
          await db.update(
            'pending_actions',
            {
              'status': 'pending',
              'retryCount': newRetryCount,
            },
            where: 'id = ?',
            whereArgs: [id],
          );

          // Exponential backoff + jitter
          final delay = _calculateDelay(newRetryCount);
          print('[SyncQueue] ⏳ Retry #$newRetryCount for item #$id in ${delay}ms');
          await Future.delayed(Duration(milliseconds: delay));
        }
      }
    } catch (e) {
      print('[SyncQueue] ❌ Queue processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Gửi 1 action lên server với requestId (idempotency)
  Future<bool> _sendToServer(Map<String, Object?> item) async {
    try {
      final tableName = item['tableName'] as String;
      final actionType = item['actionType'] as String;
      final recordId = item['recordId'] as String;
      final payload = jsonDecode(item['payload'] as String) as Map<String, dynamic>;
      final requestId = item['requestId'] as String;

      // Xác định endpoint + method
      final endpoint = _getEndpoint(tableName);
      if (endpoint == null) return false;

      Map<String, dynamic> result;

      // Gắn requestId vào payload để server check idempotency
      payload['requestId'] = requestId;

      switch (actionType) {
        case 'create':
          result = await ApiService.instance.post(endpoint, payload);
          break;
        case 'update':
          result = await ApiService.instance.put('$endpoint/$recordId', payload);
          break;
        case 'delete':
          // Soft delete = update isDeleted = true
          result = await ApiService.instance.put('$endpoint/$recordId', {
            'isDeleted': true,
            'requestId': requestId,
          });
          break;
        default:
          return false;
      }

      final statusCode = result['statusCode'] as int? ?? 0;

      // Xử lý theo HTTP status
      if (statusCode >= 200 && statusCode < 300) {
        return true; // Thành công
      } else if (statusCode == 401) {
        // Token hết hạn → thử refresh (sẽ xử lý ở ApiService)
        print('[SyncQueue] 🔒 Token expired, cần refresh');
        return false;
      } else if (statusCode == 409) {
        // Conflict hoặc đã xử lý (idempotent) → coi như thành công
        return true;
      } else if (statusCode == 429) {
        // Rate limited → retry
        return false;
      } else if (statusCode >= 500) {
        // Server error → retry
        return false;
      } else {
        // 4xx khác → lỗi client, không nên retry
        print('[SyncQueue] ⚠️ Client error $statusCode, skipping');
        return true; // Coi như "done" để không retry vô hạn
      }
    } catch (e) {
      print('[SyncQueue] ❌ Send error: $e');
      return false;
    }
  }

  /// Map tableName → API endpoint
  String? _getEndpoint(String tableName) {
    switch (tableName) {
      case 'wallets':
        return ApiConfig.wallets;
      case 'groups':
        return ApiConfig.groups;
      case 'transactions_table':
        return ApiConfig.transactions;
      case 'budgets':
        return ApiConfig.budgets;
      case 'loans':
        return ApiConfig.loans;
      case 'reminders':
        return ApiConfig.reminders;
      default:
        print('[SyncQueue] ⚠️ Unknown table: $tableName');
        return null;
    }
  }

  /// Exponential backoff + jitter
  /// Lần 1: ~1s, Lần 2: ~2s, Lần 3: ~4s, Lần 4: ~8s, Lần 5: ~16s
  int _calculateDelay(int retryCount) {
    final exponentialDelay = _baseDelayMs * pow(2, retryCount - 1).toInt();
    final jitter = Random().nextInt(_maxJitterMs);
    return exponentialDelay + jitter;
  }

  /// Lấy số lượng pending actions (dùng cho UI badge)
  Future<int> getPendingCount() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM pending_actions WHERE status = 'pending'",
    );
    return result.first['count'] as int? ?? 0;
  }

  /// Lấy số lượng failed actions
  Future<int> getFailedCount() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM pending_actions WHERE status = 'failed'",
    );
    return result.first['count'] as int? ?? 0;
  }

  /// Retry tất cả failed items (reset về pending)
  Future<void> retryFailed() async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'pending_actions',
      {'status': 'pending', 'retryCount': 0},
      where: 'status = ?',
      whereArgs: ['failed'],
    );
    processQueue();
  }

  /// Xóa tất cả failed items
  Future<void> clearFailed() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'pending_actions',
      where: 'status = ?',
      whereArgs: ['failed'],
    );
  }
}
