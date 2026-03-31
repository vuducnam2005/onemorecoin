import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:onemorecoin/model/AppNotificationModel.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:onemorecoin/Objects/NavigationTransitionType.dart';
import 'package:onemorecoin/pages/Report/ReportForPeriod.dart';
import 'package:onemorecoin/pages/Transaction/addtransaction/AddNewGroupPage.dart';
import 'package:onemorecoin/pages/Transaction/addtransaction/AddNotePage.dart';
import 'package:onemorecoin/pages/Transaction/addtransaction/AddNotificationPage.dart';
import 'package:onemorecoin/pages/Transaction/addtransaction/AddTransaction.dart';
import 'package:onemorecoin/pages/BudgetScreen.dart';
import 'package:onemorecoin/pages/Transaction.dart';
import 'package:onemorecoin/pages/HomeScreen.dart';
import 'package:flutter/foundation.dart';
import 'package:onemorecoin/pages/Transaction/addtransaction/AddWalletPage.dart';
import 'package:onemorecoin/pages/Transaction/addtransaction/DateSelectPage.dart';
import 'package:onemorecoin/pages/Transaction/addtransaction/ListCurrencyPage.dart';
import 'package:onemorecoin/pages/Transaction/addtransaction/ListGroupPage.dart';
import 'package:onemorecoin/pages/Transaction/addtransaction/ListIconPage.dart';
import 'package:onemorecoin/pages/Transaction/addtransaction/ListWalletPage.dart';
import 'package:onemorecoin/widgets/ShowTransaction.dart';

import '../pages/ProfileScreen.dart';
import '../widgets/ShowDialogFullScreen.dart';
import 'TabNavigator.dart';
import 'package:onemorecoin/utils/app_localizations.dart';

class NavigationBottom2 extends StatefulWidget {
  const NavigationBottom2({super.key});

  @override
  State<NavigationBottom2> createState() => _NavigationExampleState();
}

class _NavigationExampleState extends State<NavigationBottom2> with WidgetsBindingObserver {
  Timer? _timer;
  int currentPageIndex = 0;
  late PageController _pageController;
  Key _refreshKey = UniqueKey();

  // Colors are now derived from theme in build()

  late final List<Widget> _pages = <Widget>[
    HomeScreen(
      title: "HomeScreen",
      jumpToPage: _jumpToPage,
    ),
    const Transaction(),
    const BudgetScreen(title: "BudgetScreen"),
    TabNavigator(
      tabItem: 'ProfileScreen',
      navigatorKey: GlobalKey<NavigatorState>(),
    ),
// ProfileScreen()
  ];

  List<BottomObject> _getNavigationBarItems(BuildContext context) {
    final s = S.of(context);
    return [
      BottomObject(
          Icons.home, Icons.home_outlined, s.get('overview') ?? "Tổng quan"),
      BottomObject(Icons.wallet, Icons.wallet_outlined,
          s.get('transactions') ?? "Giao dịch"),
      BottomObject(
          Icons.class_, Icons.class_outlined, s.get('budget') ?? "Ngân sách"),
      BottomObject(
          Icons.person, Icons.person_outlined, s.get('account') ?? "Tài khoản"),
    ];
  }

  Widget bottomBarButton(Size size, BottomObject bottomObject,
          Function() onSelect, bool isSelect) =>
      Expanded(
        child: SizedBox(
          height: size.height,
          child: InkWell(
            onTap: onSelect,
            // borderRadius: BorderRadius.circular(50.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(isSelect ? bottomObject.selectedIcon : bottomObject.icon,
                    color:
                        isSelect ? Theme.of(context).colorScheme.primary : null,
                    size: MediaQuery.of(context).size.width * 0.08), // <-- Icon
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    bottomObject.label,
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.035,
                        color: isSelect
                            ? Theme.of(context).colorScheme.primary
                            : null),
                  ),
                )
              ],
            ),
          ),
        ),
      );

  List<Widget> buildBottomBarItems(BuildContext context, Size size) {
    final items = _getNavigationBarItems(context);
    List<Widget> list = [];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (i == 2) {
        list.add(const Expanded(child: SizedBox.shrink()));
      }
      list.add(bottomBarButton(
          size, item, () => {_jumpToPage(i)}, currentPageIndex == i));
    }
    return list;
  }

  _jumpToPage(int index) {
    setState(() {
      currentPageIndex = index;
      _pageController.jumpToPage(currentPageIndex);
    });
  }

  Widget bottomAppBar(BuildContext context, size) => BottomAppBar(
      color: Theme.of(context).bottomAppBarTheme.color,
      shape: const CircularNotchedRectangle(), //shape of notch
      notchMargin: 5, //notche margin between floating button and bottom appbar
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: buildBottomBarItems(context, size),
      ));

  @override
  void initState() {
    super.initState();
    currentPageIndex = 0;
    _pageController = PageController(initialPage: currentPageIndex);
    
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        context.read<AppNotificationProvider>().syncNotifications();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        context.read<AppNotificationProvider>().syncNotifications();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _handleLocaleChanged() => setState(() {
        _refreshKey = UniqueKey();
      });

  @override
  Widget build(BuildContext context) {
    var size = Size(MediaQuery.of(context).size.width * 0.15,
        MediaQuery.of(context).size.width * 0.15);
    return Scaffold(
      key: _refreshKey,
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: SizedBox(
        width: size.width,
        height: size.height,
        child: FloatingActionButton(
          backgroundColor: Colors.blue,
          shape: const CircleBorder(),
          elevation: 0.0,
          child: const Icon(
            Icons.add,
            color: Colors.white,
          ),
          onPressed: () {
            ShowTransactionPage(context);
          },
        ),
      ),
      floatingActionButtonLocation: FixedCenterDockedFabLocation(),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _pages,
      ),
      bottomNavigationBar: bottomAppBar(context, size),
    );
  }
}

class FixedCenterDockedFabLocation extends FloatingActionButtonLocation {
  const FixedCenterDockedFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = (scaffoldGeometry.scaffoldSize.width - scaffoldGeometry.floatingActionButtonSize.width) / 2.0;
    final double fabY = scaffoldGeometry.contentBottom - (scaffoldGeometry.floatingActionButtonSize.height / 2.0);
    return Offset(fabX, fabY);
  }
}

class BottomObject {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  BottomObject(this.icon, this.selectedIcon, this.label);
}
