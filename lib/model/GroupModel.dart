import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../services/sync_queue.dart';

class GroupModel {
  int id;
  String? name;
  String? type;
  String? icon;
  String? color;
  int? parentId;
  int index;

  GroupModel(
    this.id,
    this.index, {
    this.name,
    this.type,
    this.icon,
    this.color,
    this.parentId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
      'parentId': parentId,
      '"index"': index, // Quote index as it's a SQL keyword
    };
  }

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      map['id'],
      map['index'] ?? 0, // In SQLite map keys are returned without quotes
      name: map['name'],
      type: map['type'],
      icon: map['icon'],
      color: map['color'],
      parentId: map['parentId'],
    );
  }
}

class GroupModelProxy extends ChangeNotifier {
  List<GroupModel> _groups = [];
  bool _isLoading = true;

  GroupModelProxy() {
    init();
  }

  bool get isLoading => _isLoading;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    await fetchAll();
    if (_groups.isEmpty) {
      await _insertInitialGroups();
      await fetchAll();
    } else {
      await _updateOldIcons();
    }
  }

  Future<void> _updateOldIcons() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('groups');
    bool needsFetch = false;
    for (var map in maps) {
      if (map['icon'] == "assets/images/icon_wallet_primary.png") {
        String newIcon = _getIconForName(map['name'] as String? ?? "");
        if (newIcon != "assets/images/icon_wallet_primary.png") {
          await db.update('groups', {'icon': newIcon}, where: 'id = ?', whereArgs: [map['id']]);
          needsFetch = true;
        }
      }
    }
    if (needsFetch) {
      await fetchAll();
    }
  }

  String _getIconForName(String name) {
    switch (name) {
      case "Ăn uống": return Icons.restaurant.codePoint.toString();
      case "Di chuyển": return Icons.directions_car.codePoint.toString();
      case "Mua sắm": return Icons.shopping_cart.codePoint.toString();
      case "Sức khỏe": return Icons.favorite.codePoint.toString();
      case "Giải trí": return Icons.movie.codePoint.toString();
      case "Tiền nhà": return Icons.home.codePoint.toString();
      case "Tiền nước": return Icons.water_drop.codePoint.toString();
      case "Tiền internet": return Icons.wifi.codePoint.toString();
      case "Tiền điện thoại": return Icons.phone_android.codePoint.toString();
      case "Tiền học": return Icons.school.codePoint.toString();
      case "Tiền khác": return Icons.category.codePoint.toString();
      case "Lương": return Icons.attach_money.codePoint.toString();
      case "Thưởng": return Icons.card_giftcard.codePoint.toString();
      case "Lãi": return Icons.trending_up.codePoint.toString();
      case "Bán đồ": return Icons.storefront.codePoint.toString();
      case "Khác": return Icons.category.codePoint.toString();
      default: return "assets/images/icon_wallet_primary.png";
    }
  }

  Future<void> fetchAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('groups', where: 'isDeleted = 0 OR isDeleted IS NULL');
    _groups = maps.map((e) => GroupModel.fromMap(e)).toList();
    _groups.sort((a, b) => b.index.compareTo(a.index));
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _insertInitialGroups() async {
    final db = await DatabaseHelper.instance.database;
    final initialGroups = [
      GroupModel(1, 1, name: "Ăn uống", type: "expense", icon: Icons.restaurant.codePoint.toString(), color: "#FF5722"),
      GroupModel(2, 1, name: "Di chuyển", type: "expense", icon: Icons.directions_car.codePoint.toString(), color: "#2196F3"),
      GroupModel(3, 1, name: "Mua sắm", type: "expense", icon: Icons.shopping_cart.codePoint.toString(), color: "#E91E63"),
      GroupModel(4, 1, name: "Sức khỏe", type: "expense", icon: Icons.favorite.codePoint.toString(), color: "#F44336"),
      GroupModel(5, 1, name: "Giải trí", type: "expense", icon: Icons.movie.codePoint.toString(), color: "#9C27B0"),
      GroupModel(6, 1, name: "Tiền nhà", type: "expense", icon: Icons.home.codePoint.toString(), color: "#795548"),
      GroupModel(7, 1, name: "Tiền nước", type: "expense", icon: Icons.water_drop.codePoint.toString(), color: "#00BCD4"),
      GroupModel(8, 1, name: "Tiền internet", type: "expense", icon: Icons.wifi.codePoint.toString(), color: "#3F51B5"),
      GroupModel(9, 1, name: "Tiền điện thoại", type: "expense", icon: Icons.phone_android.codePoint.toString(), color: "#607D8B"),
      GroupModel(10, 1, name: "Tiền học", type: "expense", icon: Icons.school.codePoint.toString(), color: "#FF9800"),
      GroupModel(11, 1, name: "Tiền khác", type: "expense", icon: Icons.category.codePoint.toString(), color: "#9E9E9E"),
      GroupModel(12, 1, name: "Lương", type: "income", icon: Icons.attach_money.codePoint.toString(), color: "#4CAF50"),
      GroupModel(13, 1, name: "Thưởng", type: "income", icon: Icons.card_giftcard.codePoint.toString(), color: "#FFEB3B"),
      GroupModel(14, 1, name: "Lãi", type: "income", icon: Icons.trending_up.codePoint.toString(), color: "#8BC34A"),
      GroupModel(15, 1, name: "Bán đồ", type: "income", icon: Icons.storefront.codePoint.toString(), color: "#FF9800"),
      GroupModel(16, 1, name: "Khác", type: "income", icon: Icons.category.codePoint.toString(), color: "#9E9E9E"),
    ];
    for (var group in initialGroups) {
      await db.insert('groups', group.toMap());
    }
  }

  List<GroupModel> getChildren(int parentId) {
    return _groups.where((g) => g.parentId == parentId).toList();
  }

  List<GroupModel> getRootGroups() {
    return _groups.where((g) => g.parentId == null || g.parentId == 0).toList();
  }

  GroupModel getById(int id) {
    if (_groups.isEmpty) {
      return GroupModel(0, 0, name: "Loading...", icon: Icons.category.codePoint.toString(), type: "expense");
    }
    return _groups.firstWhere((g) => g.id == id, orElse: () => _groups.first);
  }

  GroupModel getByPosition(int position) {
    if (_groups.isEmpty) {
      return GroupModel(0, 0, name: "Loading...", icon: Icons.category.codePoint.toString(), type: "expense");
    }
    if (position >= 0 && position < _groups.length) {
      return _groups[position];
    }
    return _groups.first;
  }

  List<GroupModel> getAll() {
    return _groups;
  }

  Future<void> add(GroupModel group) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('groups', group.toMap());
    await SyncQueue.instance.enqueue(
      tableName: 'groups',
      actionType: 'create',
      recordId: group.id.toString(),
      payload: group.toMap(),
    );
    await fetchAll();
  }

  Future<void> update(GroupModel group) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('groups', group.toMap(), where: 'id = ?', whereArgs: [group.id]);
    await SyncQueue.instance.enqueue(
      tableName: 'groups',
      actionType: 'update',
      recordId: group.id.toString(),
      payload: group.toMap(),
    );
    await fetchAll();
  }

  Future<void> delete(GroupModel group) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update('groups', {'isDeleted': 1, 'updatedAt': now}, where: 'id = ?', whereArgs: [group.id]);
    await SyncQueue.instance.enqueue(
      tableName: 'groups',
      actionType: 'delete',
      recordId: group.id.toString(),
      payload: {'id': group.id, 'isDeleted': 1},
    );
    await fetchAll();
  }

  Future<void> deleteAll() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('groups');
    await _insertInitialGroups();
    await fetchAll();
  }

  int getId() {
    if (_groups.isEmpty) return 1;
    return _groups.map((g) => g.id).reduce((a, b) => a > b ? a : b) + 1;
  }
}