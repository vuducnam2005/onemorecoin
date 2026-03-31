import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:onemorecoin/services/api_service.dart';
import 'package:onemorecoin/services/sync_queue.dart';
import 'package:onemorecoin/services/sync_service.dart';

/// Background Sync Manager
///
/// Handles:
/// - Sync khi app vào foreground (AppLifecycleState.resumed)
/// - Flush queue khi app vào background (AppLifecycleState.paused)
/// - Periodic sync every 5 minutes
/// - Manual sync trigger
class BackgroundSync with WidgetsBindingObserver {
  static final BackgroundSync instance = BackgroundSync._();
  BackgroundSync._();

  Timer? _periodicTimer;
  bool _initialized = false;
  DateTime? _lastSyncTime;

  /// Khởi tạo background sync
  void init() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    // Periodic sync mỗi 5 phút
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _processQueueIfOnline(),
    );

    // Sync ngay lần đầu
    _processQueueIfOnline();
  }

  /// Dọn dẹp
  void dispose() {
    _periodicTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _initialized = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App quay lại foreground → pull updates + process queue
        print('[BackgroundSync] 📱 App resumed → syncing...');
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        // App vào background → flush pending queue
        print('[BackgroundSync] 💤 App paused → flushing queue...');
        _onAppPaused();
        break;
      default:
        break;
    }
  }

  /// Khi app trở lại foreground
  Future<void> _onAppResumed() async {
    await _processQueueIfOnline();
  }

  /// Khi app vào background - cố gắng flush queue
  Future<void> _onAppPaused() async {
    await _processQueueIfOnline();
  }

  /// Process queue nếu có mạng
  Future<void> _processQueueIfOnline() async {
    try {
      final isOnline = await ApiService.instance.isServerReachable();
      if (!isOnline) {
        print('[BackgroundSync] ❌ Offline, skipping sync');
        return;
      }

      await SyncQueue.instance.processQueue();
      _lastSyncTime = DateTime.now();
    } catch (e) {
      print('[BackgroundSync] ❌ Sync error: $e');
    }
  }

  /// Sync thủ công (từ UI nút "Sync Now")
  Future<Map<String, dynamic>> syncNow() async {
    try {
      final isOnline = await ApiService.instance.isServerReachable();
      if (!isOnline) {
        return {'success': false, 'error': 'Không có kết nối mạng'};
      }

      // 1. Push local changes lên server
      await SyncQueue.instance.processQueue();

      // 2. Pull server data về local
      await SyncService.instance.downloadAllData();

      _lastSyncTime = DateTime.now();

      final pendingCount = await SyncQueue.instance.getPendingCount();
      final failedCount = await SyncQueue.instance.getFailedCount();

      return {
        'success': true,
        'message': 'Đồng bộ thành công',
        'pendingCount': pendingCount,
        'failedCount': failedCount,
        'lastSync': _lastSyncTime?.toIso8601String(),
      };
    } catch (e) {
      return {'success': false, 'error': 'Lỗi đồng bộ: $e'};
    }
  }

  /// Lấy thời gian sync cuối cùng
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Kiểm tra có đang online không
  Future<bool> get isOnline => ApiService.instance.isServerReachable();
}
