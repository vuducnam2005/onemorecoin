import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../services/sync_queue.dart';
import 'TransactionModel.dart';
import 'WalletModel.dart';
import 'GroupModel.dart';

class Reminder {
  final String id;
  final String title;
  final double amount;
  final String type; // 'điện', 'nước', 'mạng', 'nhà', 'khác'
  final String dueDate; // ISO8601 string or similar
  final int remindBeforeDays;
  final String remindTime; // "HH:mm" format
  final int isPaid; // 0 or 1
  final String note;

  Reminder({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.dueDate,
    required this.remindBeforeDays,
    required this.remindTime,
    required this.isPaid,
    required this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      'dueDate': dueDate,
      'remindBeforeDays': remindBeforeDays,
      'remindTime': remindTime,
      'isPaid': isPaid,
      'note': note,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      type: map['type'],
      dueDate: map['dueDate'],
      remindBeforeDays: map['remindBeforeDays'],
      remindTime: map['remindTime'] ?? '08:00',
      isPaid: map['isPaid'],
      note: map['note'],
    );
  }
}

class ReminderProvider extends ChangeNotifier {
  List<Reminder> _reminders = [];

  List<Reminder> get reminders => _reminders;

  ReminderProvider() {
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> maps = await db.query('reminders', where: 'isDeleted = 0 OR isDeleted IS NULL');
      _reminders = List.generate(maps.length, (i) {
        return Reminder.fromMap(maps[i]);
      });
      notifyListeners();
    } catch (e) {
      print("Error loading reminders: $e");
    }
  }

  Future<void> addReminder(Reminder reminder) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('reminders', reminder.toMap());
    await SyncQueue.instance.enqueue(
      tableName: 'reminders',
      actionType: 'create',
      recordId: reminder.id,
      payload: reminder.toMap(),
    );
    _reminders.add(reminder);
    notifyListeners();
  }

  Future<void> updateReminder(Reminder reminder) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
    await SyncQueue.instance.enqueue(
      tableName: 'reminders',
      actionType: 'update',
      recordId: reminder.id,
      payload: reminder.toMap(),
    );
    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (index != -1) {
      _reminders[index] = reminder;
      notifyListeners();
    }
  }

  Future<void> deleteReminder(String id) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update('reminders', {'isDeleted': 1, 'updatedAt': now}, where: 'id = ?', whereArgs: [id]);
    await SyncQueue.instance.enqueue(
      tableName: 'reminders',
      actionType: 'delete',
      recordId: id,
      payload: {'id': id, 'isDeleted': 1},
    );
    _reminders.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  Future<void> deleteAll() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('reminders');
    _reminders.clear();
    notifyListeners();
  }

  /// Map reminder type to a matching expense group
  Future<int> _getGroupIdForType(String type, GroupModelProxy groupProxy) async {
    final nameMap = {
      'Điện': 'Tiền điện', // Actually, we should probably use Tien dien if it exists
      'Nước': 'Tiền nước',
      'Internet': 'Tiền internet',
      'Tiền nhà': 'Tiền nhà',
    };
    
    // The user specifically requested 'Thanh toán hóa đơn' for the generic fallback
    final targetName = nameMap[type] ?? 'Thanh toán hóa đơn';
    final groups = groupProxy.getAll();
    
    try {
      return groups.firstWhere((g) => g.name == targetName && g.type == 'expense').id;
    } catch (e) {
      // Create 'Thanh toán hóa đơn' or specific category if not found
      final newGroup = GroupModel(
        groupProxy.getId(),
        groups.length + 1,
        name: targetName,
        type: 'expense',
        icon: Icons.receipt_long.codePoint.toString(),
        color: "#E91E63", // Pinkish/Reddish for bills
      );
      await groupProxy.add(newGroup);
      return newGroup.id;
    }
  }

  Future<void> togglePaidStatus(
    String id,
    bool isPaid, {
    required TransactionModelProxy transactionProxy,
    required WalletModelProxy walletProxy,
    required GroupModelProxy groupProxy,
  }) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;

    final reminder = _reminders[index];
    final wallets = walletProxy.getAll();
    if (wallets.isEmpty) return;
    final wallet = wallets.first;

    final transactionId = 'reminder_${reminder.id}';

    if (isPaid) {
      // 1. Create expense transaction with dueDate as transaction date
      final groupId = await _getGroupIdForType(reminder.type, groupProxy);
      final transaction = TransactionModel(
        transactionId,
        title: reminder.title,
        amount: reminder.amount,
        unit: wallet.currency ?? 'VND',
        type: 'expense',
        date: DateTime.now().toString(),
        note: 'Thanh toán hoá đơn: ${reminder.title}',
        addToReport: true,
        walletId: wallet.id,
        groupId: groupId,
      );
      await transactionProxy.add(transaction);

      // 2. Deduct wallet balance
      wallet.balance = (wallet.balance ?? 0) - reminder.amount;
      await walletProxy.update(wallet);
    } else {
      // 1. Delete the auto-created transaction
      await transactionProxy.deleteById(transactionId);

      // 2. Refund wallet balance
      wallet.balance = (wallet.balance ?? 0) + reminder.amount;
      await walletProxy.update(wallet);
    }

    // 3. Update reminder paid status
    final updatedReminder = Reminder(
      id: reminder.id,
      title: reminder.title,
      amount: reminder.amount,
      type: reminder.type,
      dueDate: reminder.dueDate,
      remindBeforeDays: reminder.remindBeforeDays,
      remindTime: reminder.remindTime,
      isPaid: isPaid ? 1 : 0,
      note: reminder.note,
    );
    await updateReminder(updatedReminder);
  }
}
