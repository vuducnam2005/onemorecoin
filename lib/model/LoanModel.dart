import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../utils/notification_helper.dart';
import '../services/sync_queue.dart';

class LoanModel {
  String id;
  String? personName;
  double? amount;
  double? paidAmount;
  String? type; // 'borrow' or 'lend'
  String? date;
  String? dueDate;
  String? note;
  String? status; // 'unpaid', 'partial', 'paid'
  String? currency;
  int? walletId;
  String? phoneNumber;
  int? remindBeforeDays;
  String? remindTime;

  LoanModel(
    this.id, {
    this.personName,
    this.amount,
    this.paidAmount = 0,
    this.type = 'borrow',
    this.date,
    this.dueDate,
    this.note,
    this.status = 'unpaid',
    this.currency = 'VND',
    this.walletId,
    this.phoneNumber,
    this.remindBeforeDays = 0,
    this.remindTime = '08:00',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personName': personName,
      'amount': amount,
      'paidAmount': paidAmount,
      'type': type,
      'date': date,
      'dueDate': dueDate,
      'note': note,
      'status': status,
      'currency': currency,
      'walletId': walletId,
      'phoneNumber': phoneNumber,
      'remindBeforeDays': remindBeforeDays,
      'remindTime': remindTime,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory LoanModel.fromMap(Map<String, dynamic> map) {
    return LoanModel(
      map['id'].toString(),
      personName: map['personName'],
      amount: map['amount']?.toDouble(),
      paidAmount: map['paidAmount']?.toDouble() ?? 0,
      type: map['type'],
      date: map['date'],
      dueDate: map['dueDate'],
      note: map['note'],
      status: map['status'] ?? 'unpaid',
      currency: map['currency'] ?? 'VND',
      walletId: map['walletId'],
      phoneNumber: map['phoneNumber'],
      remindBeforeDays: map['remindBeforeDays'],
      remindTime: map['remindTime'],
    );
  }

  double get remainingAmount => (amount ?? 0) - (paidAmount ?? 0);

  bool get isOverdue {
    if (dueDate == null || status == 'paid') return false;
    return DateTime.now().isAfter(DateTime.parse(dueDate!));
  }

  String get statusDisplay {
    switch (status) {
      case 'paid':
        return 'Đã trả';
      case 'partial':
        return 'Trả một phần';
      default:
        return 'Chưa trả';
    }
  }
}

class LoanPayment {
  String id;
  String loanId;
  double amount;
  String date;
  String? note;
  int? walletId;

  LoanPayment({
    required this.id,
    required this.loanId,
    required this.amount,
    required this.date,
    this.note,
    this.walletId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'loanId': loanId,
      'amount': amount,
      'date': date,
      'note': note,
      'walletId': walletId,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory LoanPayment.fromMap(Map<String, dynamic> map) {
    return LoanPayment(
      id: map['id'].toString(),
      loanId: map['loanId'].toString(),
      amount: map['amount']?.toDouble() ?? 0,
      date: map['date'] ?? '',
      note: map['note'],
      walletId: map['walletId'],
    );
  }
}

class LoanProvider extends ChangeNotifier {
  List<LoanModel> _loans = [];
  bool _isLoading = true;

  LoanProvider() {
    init();
  }

  bool get isLoading => _isLoading;
  List<LoanModel> get loans => _loans;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    await fetchAll();
  }

  Future<void> fetchAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('loans', where: 'isDeleted = 0 OR isDeleted IS NULL');
    _loans = maps.map((e) => LoanModel.fromMap(e)).toList();
    _loans.sort((a, b) => DateTime.parse(b.date ?? '').compareTo(DateTime.parse(a.date ?? '')));
    _isLoading = false;
    notifyListeners();
  }

  List<LoanModel> getByType(String type) {
    return _loans.where((l) => l.type == type).toList();
  }

  List<LoanModel> getByStatus(String status) {
    return _loans.where((l) => l.status == status).toList();
  }

  List<LoanModel> getByPerson(String personName) {
    return _loans.where((l) =>
      l.personName?.toLowerCase().contains(personName.toLowerCase()) ?? false
    ).toList();
  }

  List<LoanModel> filter({
    String? type,
    String? status,
    String? personName,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    List<LoanModel> result = List.from(_loans);

    if (type != null && type.isNotEmpty) {
      result = result.where((l) => l.type == type).toList();
    }
    if (status != null && status.isNotEmpty) {
      result = result.where((l) => l.status == status).toList();
    }
    if (personName != null && personName.isNotEmpty) {
      result = result.where((l) =>
        l.personName?.toLowerCase().contains(personName.toLowerCase()) ?? false
      ).toList();
    }
    if (fromDate != null) {
      result = result.where((l) =>
        DateTime.parse(l.date ?? '').isAfter(fromDate.subtract(const Duration(seconds: 1)))
      ).toList();
    }
    if (toDate != null) {
      result = result.where((l) =>
        DateTime.parse(l.date ?? '').isBefore(toDate.add(const Duration(seconds: 1)))
      ).toList();
    }

    return result;
  }

  LoanModel? getById(String id) {
    try {
      return _loans.firstWhere((l) => l.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> add(LoanModel loan) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('loans', loan.toMap());
    await SyncQueue.instance.enqueue(
      tableName: 'loans',
      actionType: 'create',
      recordId: loan.id,
      payload: loan.toMap(),
    );
    await fetchAll();
  }

  Future<void> update(LoanModel loan) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('loans', loan.toMap(), where: 'id = ?', whereArgs: [loan.id]);
    await SyncQueue.instance.enqueue(
      tableName: 'loans',
      actionType: 'update',
      recordId: loan.id,
      payload: loan.toMap(),
    );
    await fetchAll();
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    // Soft delete loan
    await db.update('loans', {'isDeleted': 1, 'updatedAt': now}, where: 'id = ?', whereArgs: [id]);
    await SyncQueue.instance.enqueue(
      tableName: 'loans',
      actionType: 'delete',
      recordId: id,
      payload: {'id': id, 'isDeleted': 1},
    );
    // Soft delete associated payments
    await db.update('loan_payments', {'isDeleted': 1, 'updatedAt': now}, where: 'loanId = ?', whereArgs: [id]);
    await NotificationHelper.instance.cancelNotification(id.hashCode);
    await fetchAll();
  }

  Future<void> deleteAll() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('loans');
    await db.delete('loan_payments');
    await fetchAll();
  }

  // Payment management
  Future<List<LoanPayment>> getPayments(String loanId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('loan_payments', where: 'loanId = ?', whereArgs: [loanId]);
    final payments = maps.map((e) => LoanPayment.fromMap(e)).toList();
    payments.sort((a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));
    return payments;
  }

  Future<void> addPayment(LoanPayment payment) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('loan_payments', payment.toMap());
    await SyncQueue.instance.enqueue(
      tableName: 'loan_payments',
      actionType: 'create',
      recordId: payment.id,
      payload: payment.toMap(),
    );

    // Update loan paidAmount and status
    final loan = getById(payment.loanId);
    if (loan != null) {
      loan.paidAmount = (loan.paidAmount ?? 0) + payment.amount;
      if (loan.paidAmount! >= loan.amount!) {
        loan.status = 'paid';
        loan.paidAmount = loan.amount;
        await NotificationHelper.instance.cancelNotification(loan.id.hashCode);
      } else {
        loan.status = 'partial';
      }
      await update(loan);
    }
  }

  Future<void> deletePayment(LoanPayment payment) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update('loan_payments', {'isDeleted': 1, 'updatedAt': now}, where: 'id = ?', whereArgs: [payment.id]);
    await SyncQueue.instance.enqueue(
      tableName: 'loan_payments',
      actionType: 'delete',
      recordId: payment.id,
      payload: {'id': payment.id, 'isDeleted': 1},
    );

    // Update loan paidAmount and status
    final loan = getById(payment.loanId);
    if (loan != null) {
      loan.paidAmount = (loan.paidAmount ?? 0) - payment.amount;
      if (loan.paidAmount! <= 0) {
        loan.status = 'unpaid';
        loan.paidAmount = 0;
      } else {
        loan.status = 'partial';
      }
      await update(loan);
    }
  }

  double getTotalBorrowed() {
    return _loans
      .where((l) => l.type == 'borrow')
      .fold(0, (sum, l) => sum + (l.remainingAmount));
  }

  double getTotalLent() {
    return _loans
      .where((l) => l.type == 'lend')
      .fold(0, (sum, l) => sum + (l.remainingAmount));
  }
}
