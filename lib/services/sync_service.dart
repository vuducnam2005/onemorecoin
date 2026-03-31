import 'package:onemorecoin/services/api_service.dart';
import 'package:onemorecoin/utils/database_helper.dart';

/// Service đồng bộ dữ liệu giữa SQLite local và SQL Server qua API
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  /// Upload toàn bộ dữ liệu từ SQLite local lên Server
  /// Dùng khi user đăng nhập lần đầu hoặc muốn đồng bộ thủ công
  Future<Map<String, dynamic>> uploadAllData() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Lấy toàn bộ dữ liệu local
      final wallets = await db.query('wallets');
      final groups = await db.query('groups');
      final transactions = await db.query('transactions_table');
      final budgets = await db.query('budgets');
      final loans = await db.query('loans');
      final loanPayments = await db.query('loan_payments');
      final reminders = await db.query('reminders');

      final result = await ApiService.instance.syncUpload({
        'wallets': wallets,
        'groups': groups,
        'transactions': transactions,
        'budgets': budgets,
        'loans': loans,
        'loanPayments': loanPayments,
        'reminders': reminders,
      });

      return result;
    } catch (e) {
      return {'success': false, 'error': 'Lỗi đồng bộ: $e'};
    }
  }

  /// Download toàn bộ dữ liệu từ Server về SQLite local
  /// Dùng khi đăng nhập trên thiết bị mới
  Future<Map<String, dynamic>> downloadAllData() async {
    try {
      final result = await ApiService.instance.syncDownload();

      if (result['success'] != true) {
        return result;
      }

      final data = result['data'];
      final db = await DatabaseHelper.instance.database;

      // Xoá dữ liệu local cũ trước khi nhập mới
      await db.delete('loan_payments');
      await db.delete('loans');
      await db.delete('transactions_table');
      await db.delete('budgets');
      await db.delete('reminders');
      await db.delete('groups');
      await db.delete('wallets');

      // Nhập wallets
      if (data['wallets'] != null) {
        for (var item in data['wallets']) {
          await db.insert('wallets', {
            'name': item['name'],
            'icon': item['icon'],
            'currency': item['currency'] ?? 'VND',
            'balance': item['balance'] ?? 0,
            'isReport': item['isReport'] == true ? 1 : 0,
            'index': item['index'] ?? 0,
          });
        }
      }

      // Nhập groups
      if (data['groups'] != null) {
        for (var item in data['groups']) {
          await db.insert('groups', {
            'name': item['name'],
            'type': item['type'],
            'icon': item['icon'],
            'color': item['color'],
            'parentId': item['parentId'],
            'index': item['index'] ?? 1,
          });
        }
      }

      // Nhập transactions
      if (data['transactions'] != null) {
        for (var item in data['transactions']) {
          await db.insert('transactions_table', {
            'id': item['id'],
            'title': item['title'],
            'amount': item['amount'],
            'unit': item['unit'] ?? 'VND',
            'type': item['type'],
            'date': item['date'],
            'note': item['note'],
            'addToReport': item['addToReport'] == true ? 1 : 0,
            'notifyDate': item['notifyDate'],
            'walletId': item['walletId'],
            'groupId': item['groupId'],
          });
        }
      }

      // Nhập budgets
      if (data['budgets'] != null) {
        for (var item in data['budgets']) {
          await db.insert('budgets', {
            'title': item['title'],
            'budget': item['budget'],
            'unit': item['unit'] ?? 'VND',
            'type': item['type'],
            'fromDate': item['fromDate'],
            'toDate': item['toDate'],
            'note': item['note'],
            'isRepeat': item['isRepeat'] == true ? 1 : 0,
            'walletId': item['walletId'],
            'groupId': item['groupId'],
            'budgetType': item['budgetType'] ?? 'month',
          });
        }
      }

      // Nhập loans
      if (data['loans'] != null) {
        for (var item in data['loans']) {
          await db.insert('loans', {
            'id': item['id'],
            'personName': item['personName'],
            'amount': item['amount'],
            'paidAmount': item['paidAmount'] ?? 0,
            'type': item['type'],
            'date': item['date'],
            'dueDate': item['dueDate'],
            'note': item['note'],
            'status': item['status'] ?? 'unpaid',
            'currency': item['currency'] ?? 'VND',
            'walletId': item['walletId'],
            'phoneNumber': item['phoneNumber'],
            'remindBeforeDays': item['remindBeforeDays'],
            'remindTime': item['remindTime'],
          });
        }
      }

      // Nhập loan payments
      if (data['loanPayments'] != null) {
        for (var item in data['loanPayments']) {
          await db.insert('loan_payments', {
            'id': item['id'],
            'loanId': item['loanId'],
            'amount': item['amount'],
            'date': item['date'],
            'note': item['note'],
            'walletId': item['walletId'],
          });
        }
      }

      // Nhập reminders
      if (data['reminders'] != null) {
        for (var item in data['reminders']) {
          await db.insert('reminders', {
            'id': item['id'],
            'title': item['title'],
            'amount': item['amount'],
            'type': item['type'],
            'dueDate': item['dueDate'],
            'remindBeforeDays': item['remindBeforeDays'] ?? 0,
            'remindTime': item['remindTime'] ?? '08:00',
            'isPaid': item['isPaid'] == true ? 1 : 0,
            'note': item['note'],
          });
        }
      }

      return {'success': true, 'message': 'Đồng bộ dữ liệu thành công'};
    } catch (e) {
      return {'success': false, 'error': 'Lỗi đồng bộ: $e'};
    }
  }
}
