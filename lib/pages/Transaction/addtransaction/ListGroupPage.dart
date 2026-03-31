import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:onemorecoin/model/GroupModel.dart';
import 'package:provider/provider.dart';
import 'package:slide_switcher/slide_switcher.dart';
import 'package:onemorecoin/widgets/CustomIcon.dart';
import 'package:onemorecoin/utils/app_localizations.dart';
import 'package:onemorecoin/utils/Utils.dart';
import 'package:onemorecoin/pages/Transaction/addtransaction/EditGroupPage.dart';

class ListGroupPage extends StatefulWidget {

  final String? title;
  final String? type;
  const ListGroupPage({
    super.key,
     this.title,
     this.type = 'all'
  });

  static const String routeName = '/ListGroupPage';

  @override
  State<ListGroupPage> createState() => _ListGroupPageState();
}


class _ListGroupPageState extends State<ListGroupPage> {

  late List<GroupModel> listGroup;

  String _tabSelect = "expense";

  List<String> tabsValue = ['expense', 'income'];
  Map<String, String> tabs = {
    'expense': 'Khoản chi',
    'income': 'Khoản thu',
  };

  @override
  void initState() {
    super.initState();
    if(widget.type == 'all'){
      tabsValue = ['expense', 'income'];
    }
    if(widget.type == 'expense'){
      tabsValue = ['expense'];
    }
    if(widget.type == 'income'){
      tabsValue = ['income'];
    }
  }

  Map<String, String> getTabs(BuildContext context) {
    final s = S.of(context);
    if(widget.type == 'all'){
      return {
        'expense': s.get('expense_item') ?? 'Khoản chi',
        'income': s.get('income_item') ?? 'Khoản thu',
      };
    }
    if(widget.type == 'expense'){
      return {
        'expense': s.get('expense_item') ?? 'Khoản chi',
      };
    }
    if(widget.type == 'income'){
      return {
        'income': s.get('income_item') ?? 'Khoản thu',
      };
    }
    return {};
  }

  Color _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  Widget _buildListGroup(List<GroupModel> listGroup){
    listGroup = listGroup.where((element) => element.type == _tabSelect).toList();

    // Separate root and child groups
    final rootGroups = listGroup.where((g) => g.parentId == null || g.parentId == 0).toList();
    final childGroups = listGroup.where((g) => g.parentId != null && g.parentId != 0).toList();

    // Build flat list: root -> children
    List<GroupModel> orderedList = [];
    for (final root in rootGroups) {
      orderedList.add(root);
      final children = childGroups.where((c) => c.parentId == root.id).toList();
      orderedList.addAll(children);
    }
    // Add orphan children (parent deleted)
    final orphans = childGroups.where((c) => !rootGroups.any((r) => r.id == c.parentId)).toList();
    orderedList.addAll(orphans);

    return ListView.builder(
      controller: ModalScrollController.of(context),
      itemCount: orderedList.length,
      itemBuilder: (BuildContext context, int index) {
        final group = orderedList[index];
        final isChild = group.parentId != null && group.parentId != 0;
        return Container(
          color: Theme.of(context).cardColor,
          margin: const EdgeInsets.only(top: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.pop(context, {
                  'item': group
                });
              },
              onLongPress: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditGroupPage(group: group),
                  ),
                );
                if (result == true) {
                  setState(() {}); // refresh
                }
              },
              child: Padding(
                padding: EdgeInsets.only(left: isChild ? 30 : 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 60,
                          child: SizedBox(
                            child: Center(
                              child: CircleAvatar(
                                radius: 20.0,
                                backgroundColor: _hexToColor(group.color).withOpacity(0.15),
                                child: CustomIcon(iconPath: group.icon, size: 40),
                              )
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (group.color != null)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: _hexToColor(group.color),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                Text(Utils.translateGroupName(context, group.name),
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            if (isChild)
                              Text(
                                S.of(context).get('sub_category') ?? 'Danh mục con',
                                style: TextStyle(color: Colors.grey[500], fontSize: 11),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                    ),
                  ],
                ),
              ),
            )
          ),
        );
      },
    );
  }

  void _moveToAddNewGroup(BuildContext context) async {
    dynamic result = await Navigator.of(context).pushNamed("/AddNewGroupPage");
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    tabs = getTabs(context);
    listGroup = context.watch<GroupModelProxy>().getAll();
    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(widget.title ?? (S.of(context).get('group_list') ?? 'Danh sách nhóm'), style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () {

              },
            )],
        ),
        body: SafeArea(
          child: Column(
              children: [
                const Padding(padding: EdgeInsets.only(top: 2.0)),
                Container(
                  color: Theme.of(context).cardColor,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  height: 60,
                  child: Center(
                    child: SlideSwitcher(
                      children: [
                        for (final key in tabs.keys)
                        Text(
                          tabs[key] ?? "",
                          style: TextStyle(
                              fontSize: 15,
                              color: _tabSelect == key
                                  ? Colors.black.withOpacity(0.9)
                                  : Colors.grey),
                        ),
                        // Text(
                        //   'Khoản thu',
                        //   style: TextStyle(
                        //       fontSize: 15,
                        //       color: _tabSelect == key
                        //           ? Colors.black.withOpacity(0.9)
                        //           : Colors.grey),
                        // ),
                      ],
                      onSelect: (int index) => setState(() => _tabSelect = tabsValue[index]),
                      containerColor: Colors.grey[200]!,
                      slidersColors: [Colors.white],
                      containerBorderRadius: 5,
                      indents: 3,
                      containerHeight: 30,
                      containerWight: 315,
                    ),
                    // child:  ToggleButtons(
                    //   onPressed: (int index) {
                    //     setState(() {
                    //       // The button that is tapped is set to true, and the others to false.
                    //       for (int i = 0; i < _selectedTabs.length; i++) {
                    //         _selectedTabs[i] = i == index;
                    //       }
                    //       if(index == 0) {
                    //         setState(() {
                    //           _tabSelect = "expense";
                    //         });
                    //       } else {
                    //         setState(() {
                    //           _tabSelect = "income";
                    //         });
                    //       }
                    //     });
                    //   },
                    //   borderRadius: const BorderRadius.all(Radius.circular(8)),
                    //   selectedBorderColor: Colors.red[700],
                    //   selectedColor: Colors.white,
                    //   fillColor: Colors.red[200],
                    //   color: Colors.red[400],
                    //   constraints: const BoxConstraints(
                    //     minHeight: 40.0,
                    //     minWidth: 120.0,
                    //   ),
                    //   isSelected: _selectedTabs,
                    //   children: fruits,
                    // ),
                  ),
                ),
                const Padding(padding: EdgeInsets.only(top: 5.0)),
                Container(
                  color: Theme.of(context).cardColor,
                  height: 60,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _moveToAddNewGroup(context);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SizedBox(
                              width: 80,
                              child: Center(
                                child: Icon(Icons.add_circle_sharp, color: Colors.green),
                              )
                          ),
                          Text(S.of(context).get('new_group') ?? "Nhóm mới", style: const TextStyle(color: Colors.green),),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                    child: _buildListGroup(listGroup)
                )
              ]
          ),
        )

    );
  }
}
