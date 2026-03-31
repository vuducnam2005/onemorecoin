import 'package:flutter/cupertino.dart';
import '../utils/database_helper.dart';
import '../services/sync_queue.dart';
import 'GroupModel.dart';
import 'TransactionModel.dart';
import 'WalletModel.dart';

class BudgetModel {
  int id;
  String? title;
  double? budget;
  String? unit;
  String? type;
  String? fromDate;
  String? toDate;
  String? note;
  bool? isRepeat;
  int walletId;
  int groupId;
  String? budgetType;

  WalletModel? wallet;
  GroupModel? group;
  List<TransactionModel> transactions = [];

  BudgetModel(
    this.id, {
    this.title,
    this.budget,
    this.unit = "VND",
    this.type = "expense",
    this.fromDate,
    this.toDate,
    this.note,
    this.isRepeat = false,
    required this.walletId,
    required this.groupId,
    this.budgetType = "month",
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'budget': budget,
      'unit': unit,
      'type': type,
      'fromDate': fromDate,
      'toDate': toDate,
      'note': note,
      'isRepeat': (isRepeat ?? false) ? 1 : 0,
      'walletId': walletId,
      'groupId': groupId,
      'budgetType': budgetType,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map, {WalletModel? wallet, GroupModel? group, List<TransactionModel>? transactions}) {
    final model = BudgetModel(
      map['id'],
      title: map['title'],
      budget: map['budget']?.toDouble(),
      unit: map['unit'],
      type: map['type'],
      fromDate: map['fromDate'],
      toDate: map['toDate'],
      note: map['note'],
      isRepeat: map['isRepeat'] == 1,
      walletId: map['walletId'],
      groupId: map['groupId'],
      budgetType: map['budgetType'],
    );
    model.wallet = wallet;
    model.group = group;
    if (transactions != null) {
      model.transactions = transactions;
    }
    return model;
  }
}

class BudgetModelProxy extends ChangeNotifier {
  List<BudgetModel> _budgets = [];
  bool _isLoading = true;

  BudgetModelProxy() {
    init();
  }

  bool get isLoading => _isLoading;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    await fetchAll();
  }

  Future<void> fetchAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('budgets', where: 'isDeleted = 0 OR isDeleted IS NULL');
    
    // Dependencies
    final walletsMaps = await db.query('wallets');
    final groupsMaps = await db.query('groups');
    final transMaps = await db.query('transactions_table');
    
    final wallets = walletsMaps.map((e) => WalletModel.fromMap(e)).toList();
    final groups = groupsMaps.map((e) => GroupModel.fromMap(e)).toList();
    final allTrans = transMaps.map((e) => TransactionModel.fromMap(e)).toList();

    _budgets = maps.map((e) {
      final b = BudgetModel.fromMap(e);
      b.wallet = wallets.cast<WalletModel?>().firstWhere((w) => w?.id == b.walletId, orElse: () => null);
      b.group = groups.cast<GroupModel?>().firstWhere((g) => g?.id == b.groupId, orElse: () => null);

      // Recreate getAllForBudget logic locally
      Iterable<TransactionModel> relevantTrans = allTrans;
      if (b.groupId != 0 && b.walletId != 0) {
        relevantTrans = relevantTrans.where((t) => t.groupId == b.groupId && t.walletId == b.walletId);
      } else if (b.groupId != 0) {
        relevantTrans = relevantTrans.where((t) => t.groupId == b.groupId);
      } else if (b.walletId != 0) {
        relevantTrans = relevantTrans.where((t) => t.walletId == b.walletId);
      }

      if (b.fromDate != null && b.toDate != null) {
        relevantTrans = relevantTrans.where((t) => 
          DateTime.parse(t.date ?? "").isAfter(DateTime.parse(b.fromDate!).subtract(const Duration(seconds: 1))) && 
          DateTime.parse(t.date ?? "").isBefore(DateTime.parse(b.toDate!).add(const Duration(seconds: 1)))
        );
      }

      b.transactions = relevantTrans.toList()
        ..sort((x, y) => DateTime.parse(y.date ?? "").compareTo(DateTime.parse(x.date ?? "")));
      
      return b;
    }).toList();

    _budgets.sort((a, b) => DateTime.parse(b.fromDate ?? "").compareTo(DateTime.parse(a.fromDate ?? "")));
    _isLoading = false;
    notifyListeners();
  }

  BudgetModel getById(int id) {
    if (_budgets.isEmpty) {
      return BudgetModel(0, walletId: 0, groupId: 0, title: "Loading...");
    }
    return _budgets.firstWhere((b) => b.id == id, orElse: () => _budgets.first);
  }

  Future<void> deleteById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update('budgets', {'isDeleted': 1, 'updatedAt': now}, where: 'id = ?', whereArgs: [id]);
    await SyncQueue.instance.enqueue(
      tableName: 'budgets',
      actionType: 'delete',
      recordId: id.toString(),
      payload: {'id': id, 'isDeleted': 1},
    );
    await fetchAll();
  }

  BudgetModel getByPosition(int position) {
    if (_budgets.isEmpty) {
      return BudgetModel(0, walletId: 0, groupId: 0, title: "Loading...");
    }
    if (position >= 0 && position < _budgets.length) return _budgets[position];
    return _budgets.first;
  }

  List<BudgetModel> getAll() {
    return _budgets;
  }

  List<BudgetModel> getAllByWalletId(int walletId) {
    List<BudgetModel> list;
    if (walletId == 0) {
      list = List.from(_budgets);
    } else {
      list = _budgets.where((b) => b.walletId == walletId).toList();
    }
    list.sort((a, b) => b.id.compareTo(a.id));
    return list;
  }

  int getId() {
    if (_budgets.isEmpty) return 1;
    return _budgets.map((b) => b.id).reduce((x, y) => x > y ? x : y) + 1;
  }

  Future<void> add(BudgetModel budget) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('budgets', budget.toMap());
    await SyncQueue.instance.enqueue(
      tableName: 'budgets',
      actionType: 'create',
      recordId: budget.id.toString(),
      payload: budget.toMap(),
    );
    await fetchAll();
  }

  Future<void> update(BudgetModel budget) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('budgets', budget.toMap(), where: 'id = ?', whereArgs: [budget.id]);
    await SyncQueue.instance.enqueue(
      tableName: 'budgets',
      actionType: 'update',
      recordId: budget.id.toString(),
      payload: budget.toMap(),
    );
    await fetchAll();
  }

  Future<void> delete(BudgetModel budget) async {
    await deleteById(budget.id);
  }

  Future<void> deleteAll() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('budgets');
    await fetchAll();
  }
}
