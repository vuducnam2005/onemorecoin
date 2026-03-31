import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../utils/database_helper.dart';
import '../utils/Utils.dart';

class AppNotificationModel {
  String id;
  String title;
  String body;
  String type; // 'reminder', 'loan', 'system'
  String date; // ISO8601 string payload
  bool isRead;
  String? referenceId;

  AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.date,
    this.isRead = false,
    this.referenceId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'date': date,
      'isRead': isRead ? 1 : 0,
      'referenceId': referenceId,
    };
  }

  factory AppNotificationModel.fromMap(Map<String, dynamic> map) {
    return AppNotificationModel(
      id: map['id'],
      title: map['title'],
      body: map['body'],
      type: map['type'],
      date: map['date'],
      isRead: map['isRead'] == 1,
      referenceId: map['referenceId'],
    );
  }
}

class AppNotificationProvider extends ChangeNotifier {
  List<AppNotificationModel> _notifications = [];
  bool _isLoading = true;

  List<AppNotificationModel> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isLoading => _isLoading;

  AppNotificationProvider() {
    init();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    
    // First, sync any generated notifications behind the scenes
    await syncNotifications();
    
    await fetchAll();
  }

  Future<void> fetchAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('app_notifications', orderBy: 'date DESC');
    _notifications = maps.map((e) => AppNotificationModel.fromMap(e)).toList();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('app_notifications', {'isRead': 1}, where: 'id = ?', whereArgs: [id]);
    await fetchAll();
  }

  Future<void> markAllAsRead() async {
    final db = await DatabaseHelper.instance.database;
    await db.update('app_notifications', {'isRead': 1}, where: 'isRead = 0');
    await fetchAll();
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('app_notifications', where: 'id = ?', whereArgs: [id]);
    await fetchAll();
  }

  Future<void> deleteAll() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('app_notifications');
    await fetchAll();
  }

  Future<void> addNotification(AppNotificationModel notification) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('app_notifications', notification.toMap());
    await fetchAll();
  }

  Future<void> syncNotifications() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    bool hasNew = false;
    
    // 1. Check Reminders
    final reminders = await db.query('reminders', where: 'isPaid = 0 AND dueDate IS NOT NULL');
    for (var r in reminders) {
      final dueDateStr = r['dueDate'] as String?;
      if (dueDateStr == null || dueDateStr.isEmpty) continue;
      
      final dueDate = DateTime.parse(dueDateStr);
      final remindBeforeDays = (r['remindBeforeDays'] as int?) ?? 0;
      final remindTimeStr = (r['remindTime'] as String?) ?? '08:00';
      
      final reminderDate = dueDate.subtract(Duration(days: remindBeforeDays));
      final parts = remindTimeStr.split(':');
      final scheduleDate = DateTime(
        reminderDate.year, reminderDate.month, reminderDate.day,
        int.tryParse(parts[0]) ?? 8, int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      );
      
      // If the schedule date has passed, create an in-app notification
      if (now.isAfter(scheduleDate)) {
        final existing = await db.query('app_notifications', 
          where: 'referenceId = ? AND type = ? AND date = ?', 
          whereArgs: [r['id'], 'reminder', scheduleDate.toIso8601String()]
        );
        if (existing.isEmpty) {
          final title = r['title'] ?? 'Nhắc thanh toán hoá đơn';
          final amount = r['amount'] != null ? Utils.currencyFormat((r['amount'] as num).toDouble(), withoutUnit: true) : '0';
          await db.insert('app_notifications', {
            'id': const Uuid().v4(),
            'title': title,
            'body': 'Đến hạn thanh toán $title số tiền $amount',
            'type': 'reminder',
            'date': scheduleDate.toIso8601String(),
            'isRead': 0,
            'referenceId': r['id'],
          });
          hasNew = true;
        }
      }
    }
    
    // 2. Check Loans
    final loans = await db.query('loans', where: 'status != ? AND dueDate IS NOT NULL', whereArgs: ['paid']);
    for (var l in loans) {
      final dueDateStr = l['dueDate'] as String?;
      if (dueDateStr == null || dueDateStr.isEmpty) continue;
      
      final dueDate = DateTime.parse(dueDateStr);
      final remindBeforeDays = (l['remindBeforeDays'] as int?) ?? 0;
      final remindTimeStr = (l['remindTime'] as String?) ?? '08:00';
      
      final reminderDate = dueDate.subtract(Duration(days: remindBeforeDays));
      final parts = remindTimeStr.split(':');
      final scheduleDate = DateTime(
        reminderDate.year, reminderDate.month, reminderDate.day,
        int.tryParse(parts[0]) ?? 8, int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      );
      
      if (now.isAfter(scheduleDate)) {
        final existing = await db.query('app_notifications', 
          where: 'referenceId = ? AND type = ? AND date = ?', 
          whereArgs: [l['id'], 'loan', scheduleDate.toIso8601String()]
        );
        if (existing.isEmpty) {
          final bool isBorrow = l['type'] == 'borrow';
          final title = isBorrow ? 'Khoản nợ đến hạn' : 'Khoản cho vay đến hạn';
          final amount = l['amount'] != null ? Utils.currencyFormat((l['amount'] as num).toDouble(), withoutUnit: true) : '0';
          final person = l['personName'] ?? '';
          final body = isBorrow 
              ? 'Bạn cần trả $amount cho $person'
              : 'Đến hạn thu $amount từ $person';
              
          await db.insert('app_notifications', {
            'id': const Uuid().v4(),
            'title': title,
            'body': body,
            'type': 'loan',
            'date': scheduleDate.toIso8601String(),
            'isRead': 0,
            'referenceId': l['id'],
          });
          hasNew = true;
        }
      }
    }
    
    if (hasNew) {
      // Refresh list if new notifications were added silently
      await fetchAll();
    }
  }
}
