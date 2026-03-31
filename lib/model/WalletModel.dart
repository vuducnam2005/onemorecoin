import 'package:flutter/cupertino.dart';
import '../utils/database_helper.dart';
import '../services/sync_queue.dart';

class WalletModel {
  int id;
  int index;
  String? name;
  String? icon;
  double? balance;
  String? currency;
  bool isDefault;
  bool isReport;

  WalletModel(
    this.id, {
    this.index = 0,
    this.name,
    this.icon,
    this.balance,
    this.currency,
    this.isDefault = false,
    this.isReport = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'currency': currency,
      'balance': balance,
      'isReport': isReport ? 1 : 0,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory WalletModel.fromMap(Map<String, dynamic> map) {
    return WalletModel(
      map['id'],
      name: map['name'],
      icon: map['icon'],
      currency: map['currency'],
      balance: map['balance']?.toDouble(),
      isReport: map['isReport'] == 1,
    );
  }
}

class WalletModelProxy extends ChangeNotifier {
  List<WalletModel> _wallets = [];
  bool _isLoading = true;

  WalletModelProxy() {
    init();
  }

  bool get isLoading => _isLoading;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    await fetchAll();
    if (_wallets.isEmpty) {
      final defaultWallet = WalletModel(
        1,
        index: 0,
        name: "Ví chính",
        icon: "assets/images/icon_wallet_primary.png",
        balance: 0,
        currency: "VND",
        isDefault: true,
        isReport: true,
      );
      await add(defaultWallet);
    }
  }

  Future<void> fetchAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('wallets', where: 'isDeleted = 0 OR isDeleted IS NULL');
    _wallets = maps.map((e) => WalletModel.fromMap(e)).toList();
    _wallets.sort((a, b) => a.index.compareTo(b.index));
    _isLoading = false;
    notifyListeners();
  }

  WalletModel getById(int id) {
    if (_wallets.isEmpty) {
      return WalletModel(0, name: "Loading...", icon: "assets/images/icon_wallet_primary.png", balance: 0, currency: "VND");
    }
    return _wallets.firstWhere((w) => w.id == id, orElse: () => _wallets.first);
  }

  WalletModel getByPosition(int position) {
    if (_wallets.isEmpty) {
      return WalletModel(0, name: "Loading...", icon: "assets/images/icon_wallet_primary.png", balance: 0, currency: "VND");
    }
    if (position >= 0 && position < _wallets.length) {
      return _wallets[position];
    }
    return _wallets.first;
  }

  List<WalletModel> getAll() {
    return _wallets;
  }

  Future<void> add(WalletModel wallet) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('wallets', wallet.toMap());
    // Enqueue sync
    await SyncQueue.instance.enqueue(
      tableName: 'wallets',
      actionType: 'create',
      recordId: wallet.id.toString(),
      payload: wallet.toMap(),
    );
    await fetchAll();
  }

  Future<void> update(WalletModel wallet) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('wallets', wallet.toMap(), where: 'id = ?', whereArgs: [wallet.id]);
    // Enqueue sync
    await SyncQueue.instance.enqueue(
      tableName: 'wallets',
      actionType: 'update',
      recordId: wallet.id.toString(),
      payload: wallet.toMap(),
    );
    await fetchAll();
  }

  Future<void> updateBalance(WalletModel wallet, double balance) async {
    wallet.balance = balance;
    await update(wallet);
  }

  Future<void> delete(WalletModel wallet) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    // Soft delete wallet
    await db.update('wallets', {'isDeleted': 1, 'updatedAt': now}, where: 'id = ?', whereArgs: [wallet.id]);
    await SyncQueue.instance.enqueue(
      tableName: 'wallets',
      actionType: 'delete',
      recordId: wallet.id.toString(),
      payload: {'id': wallet.id, 'isDeleted': 1},
    );
    // Soft delete associated transactions and budgets
    await db.update('transactions_table', {'isDeleted': 1, 'updatedAt': now}, where: 'walletId = ?', whereArgs: [wallet.id]);
    await db.update('budgets', {'isDeleted': 1, 'updatedAt': now}, where: 'walletId = ?', whereArgs: [wallet.id]);
    
    await fetchAll();
  }

  Future<void> deleteAll() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('wallets');
    
    // Cascade delete all transactions and budgets
    await db.delete('transactions_table');
    await db.delete('budgets');
    
    final defaultWallet = WalletModel(
      1,
      index: 0,
      name: "Ví chính",
      icon: "assets/images/icon_wallet_primary.png",
      balance: 0,
      currency: "VND",
      isDefault: true,
      isReport: true,
    );
    await add(defaultWallet);
  }

  int getId() {
    if (_wallets.isEmpty) {
      return 1;
    } else {
      return _wallets.map((w) => w.id).reduce((a, b) => a > b ? a : b) + 1;
    }
  }
}