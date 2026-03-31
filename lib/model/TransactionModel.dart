import 'dart:math';
import 'package:flutter/cupertino.dart';
import '../Objects/ShowType.dart';
import '../Objects/TabTransaction.dart';
import '../utils/MyDateUtils.dart';
import '../utils/Utils.dart';
import '../utils/database_helper.dart';
import '../services/sync_queue.dart';
import 'GroupModel.dart';
import 'WalletModel.dart';

class TransactionModel {
  String id;
  String? title;
  double? amount;
  String? unit;
  String? type;
  String? date;
  String? note;
  bool? addToReport;
  String? notifyDate;
  int walletId;
  int groupId;

  WalletModel? wallet;
  GroupModel? group;

  TransactionModel(this.id,
      {this.title,
      this.amount,
      this.unit = "VND",
      this.type = "income",
      this.date,
      this.note,
      this.addToReport = true,
      this.notifyDate,
      required this.walletId,
      required this.groupId,
      this.wallet,
      this.group});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'unit': unit,
      'type': type,
      'date': date,
      'note': note,
      'addToReport': (addToReport ?? true) ? 1 : 0,
      'notifyDate': notifyDate,
      'walletId': walletId,
      'groupId': groupId,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, {WalletModel? wallet, GroupModel? group}) {
    return TransactionModel(
      map['id'].toString(),
      title: map['title'],
      amount: map['amount']?.toDouble(),
      unit: map['unit'],
      type: map['type'],
      date: map['date'],
      note: map['note'],
      addToReport: map['addToReport'] == 1,
      notifyDate: map['notifyDate'],
      walletId: map['walletId'],
      groupId: map['groupId'],
      wallet: wallet,
      group: group,
    );
  }
}

class TransactionModelProxy extends ChangeNotifier {
  List<TransactionModel> _transactions = [];
  List<TabTransaction> listTab = [];
  ShowType showType = ShowType.date;
  WalletModel _walletModel = WalletModel(0, name: null, icon: null, currency: "VND");
  bool _isLoading = true;

  TransactionModelProxy() {
    init();
  }

  bool get isLoading => _isLoading;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    await fetchAll();
    showType = ShowType.date;
    generateListTabTransactionInTransactionPage(true, showType, walletModel);
  }

  WalletModel get walletModel => _walletModel;

  set walletModel(WalletModel value) {
    _walletModel = value;
    generateListTabTransactionInTransactionPage(true, showType, value);
  }

  Future<void> fetchAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('transactions_table', where: 'isDeleted = 0 OR isDeleted IS NULL');
    
    // Fetch dependencies
    final walletsMaps = await db.query('wallets');
    final groupsMaps = await db.query('groups');
    final wallets = walletsMaps.where((e) => e['isDeleted'] != 1).map((e) => WalletModel.fromMap(e)).toList();
    final groups = groupsMaps.where((e) => e['isDeleted'] != 1).map((e) => GroupModel.fromMap(e)).toList();

    _transactions = maps.map((e) {
      final t = TransactionModel.fromMap(e);
      t.wallet = wallets.cast<WalletModel?>().firstWhere((w) => w?.id == t.walletId, orElse: () => null);
      t.group = groups.cast<GroupModel?>().firstWhere((g) => g?.id == t.groupId, orElse: () => null);
      return t;
    }).toList();
    
    _transactions.sort((a, b) => DateTime.parse(b.date ?? "").compareTo(DateTime.parse(a.date ?? "")));
    _isLoading = false;
    notifyListeners();
  }

  TransactionModel getById(String id) {
    if (_transactions.isEmpty) {
      return TransactionModel("0", walletId: 0, groupId: 0, title: "Loading...");
    }
    return _transactions.firstWhere((t) => t.id == id, orElse: () => _transactions.first);
  }

  TransactionModel getByPosition(int position) {
    if (_transactions.isEmpty) {
      return TransactionModel("0", walletId: 0, groupId: 0, title: "Loading...");
    }
    if (position >= 0 && position < _transactions.length) {
      return _transactions[position];
    }
    return _transactions.first;
  }

  List<TransactionModel> getAll() {
    return _transactions;
  }

  List<TransactionModel> getAllByDate(DateTime fromDate, DateTime toDate) {
    return _transactions.where((element) => 
      DateTime.parse(element.date ?? "").isAfter(fromDate.subtract(const Duration(seconds: 1))) && 
      DateTime.parse(element.date ?? "").isBefore(toDate.add(const Duration(seconds: 1)))).toList();
  }

  List<TransactionModel> getNewest(int limit) {
    return _transactions.sublist(0, min(_transactions.length, limit));
  }

  List<TransactionModel> getAllByWalletId(int walletId) {
    List<TransactionModel> list = [];
    if (walletId == 0) {
      list = List.from(_transactions);
    } else {
      list = _transactions.where((t) => t.walletId == walletId).toList();
    }
    return list;
  }

  List<TransactionModel> getLimitByGroup(int groupId, int limit) {
    List<TransactionModel> list = [];
    if(groupId == 0){
      list = List.from(_transactions);
    }else {
      list = _transactions.where((t) => t.groupId == groupId).toList();
    }
    if (list.length <= limit) return list;
    return list.sublist(list.length - limit, list.length);
  }

  Future<void> add(TransactionModel transaction) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('transactions_table', transaction.toMap());
    await SyncQueue.instance.enqueue(
      tableName: 'transactions_table',
      actionType: 'create',
      recordId: transaction.id,
      payload: transaction.toMap(),
    );
    await fetchAll();
    listTab = generateListTabTransactionInTransactionPage(true, showType, walletModel);
  }

  Future<void> update(TransactionModel transaction) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('transactions_table', transaction.toMap(), where: 'id = ?', whereArgs: [transaction.id]);
    await SyncQueue.instance.enqueue(
      tableName: 'transactions_table',
      actionType: 'update',
      recordId: transaction.id,
      payload: transaction.toMap(),
    );
    await fetchAll();
    listTab = generateListTabTransactionInTransactionPage(true, showType, walletModel);
  }

  Future<void> delete(TransactionModel transaction) async {
    await deleteById(transaction.id);
  }

  Future<void> deleteById(String id) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update('transactions_table', {'isDeleted': 1, 'updatedAt': now}, where: 'id = ?', whereArgs: [id]);
    await SyncQueue.instance.enqueue(
      tableName: 'transactions_table',
      actionType: 'delete',
      recordId: id,
      payload: {'id': id, 'isDeleted': 1},
    );
    await fetchAll();
    listTab = generateListTabTransactionInTransactionPage(true, showType, walletModel);
  }

  Future<void> deleteAll() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('transactions_table');
    await fetchAll();
    listTab = generateListTabTransactionInTransactionPage(true, showType, walletModel);
  }

  List<TransactionModel> getAllForBudget(int groupId, int walletId, String? fromDate, String? toDate) {
    List<TransactionModel> list = [];
    if (groupId == 0 && walletId == 0) {
      list = List.from(_transactions);
    } else if (groupId == 0 && walletId != 0) {
      list = _transactions.where((t) => t.walletId == walletId).toList();
    } else if (groupId != 0 && walletId == 0) {
      list = _transactions.where((t) => t.groupId == groupId).toList();
    } else {
      list = _transactions.where((t) => t.groupId == groupId && t.walletId == walletId).toList();
    }
    
    if (fromDate != null && toDate != null) {
      list = list.where((element) => 
        DateTime.parse(element.date ?? "").isAfter(DateTime.parse(fromDate).subtract(const Duration(seconds: 1))) && 
        DateTime.parse(element.date ?? "").isBefore(DateTime.parse(toDate).add(const Duration(seconds: 1)))
      ).toList();
    }
    list.sort((a, b) => DateTime.parse(b.date ?? "").compareTo(DateTime.parse(a.date ?? "")));
    return list;
  }

  List<TransactionModel> getTransactionByWalletId(int walletId) {
    return _transactions.where((element) => (element.walletId == walletId || walletId == 0)).toList();
  }

  List<TabTransaction> generateListTabTransactionInTransactionPage(bool require, ShowType showTypeRequest, WalletModel walletModelRequest) {
    if (showType == showTypeRequest && _walletModel.id == walletModelRequest.id && !require) {
      return listTab;
    }
    showType = showTypeRequest;
    _walletModel = walletModelRequest;
    List<TabTransaction> listTabNoTransaction = Utils.getListTabShowTypeTransaction(showTypeRequest, 20);
    listTab.clear();
    listTab.addAll(listTabNoTransaction);
    
    var transactions = getTransactionByWalletId(_walletModel.id);
    transLoop:
    for(final tran in transactions){
      tabLoop:
      for(var tab in listTab){
        if(tab.isAll){
          tab.transactions.add(tran);
          break tabLoop;
        }
        if(tab.isFuture){
          if(MyDateUtils.isAfter(DateTime.parse(tran.date!), tab.from)){
            tab.transactions.add(tran);
            break tabLoop;
          }
        }
        else{
          if(MyDateUtils.isBetween(DateTime.parse(tran.date!), tab.from, tab.to)){
            tab.transactions.add(tran);
            break tabLoop;
          }
        }
      }
    }
    notifyListeners();
    return listTab;
  }
}
