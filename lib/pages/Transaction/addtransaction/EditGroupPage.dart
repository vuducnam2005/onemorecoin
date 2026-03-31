import 'package:flutter/material.dart';
import 'package:onemorecoin/model/GroupModel.dart';
import 'package:provider/provider.dart';
import 'package:onemorecoin/widgets/CustomIcon.dart';
import 'package:onemorecoin/utils/app_localizations.dart';

class EditGroupPage extends StatefulWidget {
  final GroupModel group;
  const EditGroupPage({super.key, required this.group});

  @override
  State<EditGroupPage> createState() => _EditGroupPageState();
}

class _EditGroupPageState extends State<EditGroupPage> {
  final _nameController = TextEditingController();
  String _icon = '';
  String _color = '#9E9E9E';
  int? _parentId;
  late String _type;

  static const List<String> _colorOptions = [
    '#F44336', '#E91E63', '#9C27B0', '#673AB7',
    '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4',
    '#009688', '#4CAF50', '#8BC34A', '#CDDC39',
    '#FFEB3B', '#FFC107', '#FF9800', '#FF5722',
    '#795548', '#607D8B', '#9E9E9E', '#000000',
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.group.name ?? '';
    _icon = widget.group.icon ?? '';
    _color = widget.group.color ?? '#9E9E9E';
    _parentId = widget.group.parentId;
    _type = widget.group.type ?? 'expense';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  void _save() async {
    if (_nameController.text.trim().isEmpty || _icon.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).get('please_fill_all') ?? 'Vui lòng điền đầy đủ')),
      );
      return;
    }

    final groups = context.read<GroupModelProxy>();
    widget.group.name = _nameController.text.trim();
    widget.group.icon = _icon;
    widget.group.color = _color;
    widget.group.parentId = _parentId;
    widget.group.type = _type;
    await groups.update(widget.group);
    Navigator.pop(context, true);
  }

  void _delete() async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.get('confirm_delete') ?? 'Xác nhận xóa'),
        content: Text(s.get('confirm_delete_group') ?? 'Bạn có chắc muốn xóa danh mục này? Các giao dịch thuộc danh mục này sẽ không bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.get('cancel') ?? 'Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.get('delete') ?? 'Xóa', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final groups = context.read<GroupModelProxy>();
      await groups.delete(widget.group);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final allGroups = context.watch<GroupModelProxy>().getAll();
    final parentOptions = allGroups
        .where((g) => g.id != widget.group.id && g.type == _type && (g.parentId == null || g.parentId == 0))
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(s.get('edit_group') ?? 'Sửa danh mục',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _delete,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Icon and Name
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        dynamic result = await Navigator.of(context).pushNamed("/ListIconPage");
                        if (result != null) {
                          setState(() {
                            _icon = result['icon'];
                          });
                        }
                      },
                      child: CircleAvatar(
                        backgroundColor: _icon.isNotEmpty ? _hexToColor(_color).withOpacity(0.2) : Colors.grey[300],
                        radius: 30,
                        child: _icon.isEmpty
                            ? const Icon(Icons.add, size: 30, color: Colors.white)
                            : CustomIcon(iconPath: _icon, size: 40),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: s.get('group_name') ?? 'Tên danh mục',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Type
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.get('category_type') ?? 'Loại danh mục',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text(s.get('expense_item') ?? 'Khoản chi'),
                            value: 'expense',
                            groupValue: _type,
                            onChanged: (val) => setState(() => _type = val!),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text(s.get('income_item') ?? 'Khoản thu'),
                            value: 'income',
                            groupValue: _type,
                            onChanged: (val) => setState(() => _type = val!),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Color picker
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.get('category_color') ?? 'Màu sắc',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _colorOptions.map((colorHex) {
                        final isSelected = _color == colorHex;
                        return GestureDetector(
                          onTap: () => setState(() => _color = colorHex),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _hexToColor(colorHex),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [BoxShadow(color: _hexToColor(colorHex), blurRadius: 6)]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Parent category
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.get('parent_category') ?? 'Danh mục cha',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int?>(
                      value: _parentId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(s.get('no_parent') ?? 'Không có (danh mục gốc)'),
                        ),
                        ...parentOptions.map((g) => DropdownMenuItem<int?>(
                          value: g.id,
                          child: Row(
                            children: [
                              CustomIcon(iconPath: g.icon, size: 24),
                              const SizedBox(width: 8),
                              Text(g.name ?? ''),
                            ],
                          ),
                        )),
                      ],
                      onChanged: (val) => setState(() => _parentId = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(s.get('save') ?? 'Lưu',
                    style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
