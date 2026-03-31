import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onemorecoin/Objects/NavigationTransitionType.dart';
import 'package:onemorecoin/components/MyButton.dart';
import 'package:onemorecoin/model/StorageStage.dart';
import 'package:onemorecoin/model/WalletModel.dart';
import 'package:onemorecoin/pages/Transaction/addtransaction/ListWalletPage.dart';
import 'package:onemorecoin/utils/MyDateUtils.dart';
import 'package:onemorecoin/utils/Utils.dart';
import 'package:onemorecoin/widgets/HomeReportWidget.dart';
import 'package:onemorecoin/widgets/ShowDialogFullScreen.dart';
import 'package:provider/provider.dart';
import 'package:onemorecoin/utils/currency_provider.dart';
import 'package:slide_switcher/slide_switcher.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:onemorecoin/pages/ChatBot/ChatScreen.dart';
import 'package:onemorecoin/pages/Reminders/RemindersScreen.dart';
import 'package:onemorecoin/pages/Notification/NotificationListScreen.dart';
import 'package:onemorecoin/model/AppNotificationModel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../commons/Constants.dart';
import '../model/TransactionModel.dart';
import '../widgets/ShowListWallet.dart';
import '../widgets/ShowReportForPeriod.dart';
import 'Report/ReportForPeriod.dart';
import 'package:onemorecoin/widgets/CustomIcon.dart';
import 'package:onemorecoin/utils/app_localizations.dart';
import 'package:onemorecoin/widgets/HomeStatsWidget.dart';
import 'package:onemorecoin/widgets/QuickAddWidget.dart';
import 'package:onemorecoin/widgets/MiniDashboardWidget.dart';
import 'package:onemorecoin/widgets/QuickStatsWidget.dart';

class HomeScreen extends StatefulWidget {

  const HomeScreen({
    super.key,
    required this.title,
    this.jumpToPage,
  });

  final String title;
  final jumpToPage;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _showAmount = true;
  bool _showStats = true;
  Duration _statsAnimationDuration = Duration.zero;
  WalletModel _wallet = WalletModel(0, name: null, icon: null, currency: "VND");  int chartType = 0;
  late List<TransactionModel> transactionNewest;

  void _selectWallet(BuildContext context) async {

    ShowListWalletPage(context, wallet: _wallet).then((value) => {

      if(value != null && value['wallet'] != null){
        if(value['wallet'].id != _wallet.id){
          setState(() {
            _wallet = value['wallet'];
          })
        }
      }
    });
  }


  void _showReportForPeriod(BuildContext context) async {
    ShowReportForPeriod(context);
  }

  _calculate(){
    transactionNewest = context.watch<TransactionModelProxy>().getNewest(3);
    double totalAmount = context.watch<WalletModelProxy>().getAll().fold(0, (previousValue, element) => previousValue + element.balance!);
    
    final selectedWalletProxy = context.watch<TransactionModelProxy>().walletModel;
    if (selectedWalletProxy.id == 0) {
      _wallet = selectedWalletProxy;
      _wallet.balance = totalAmount;
    } else {
      _wallet = context.read<WalletModelProxy>().getById(selectedWalletProxy.id);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStatsPreference();
  }

  Future<void> _loadStatsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showStats = prefs.getBool('show_home_stats') ?? true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    context.watch<CurrencyProvider>();
    final s = S.of(context);
    _calculate();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    
    final cardGradient = isDark 
        ? const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)], 
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [primaryColor.withValues(alpha: 0.15), Theme.of(context).cardColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    
    final borderColor = isDark ? Colors.blueAccent.withValues(alpha: 0.3) : primaryColor.withValues(alpha: 0.4);
    final shadowColor = isDark ? Colors.black45 : primaryColor.withValues(alpha: 0.1);
    final balanceColor = isDark ? Colors.white : primaryColor;

    print("build HomeScreen");
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leadingWidth: double.infinity,
        leading: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Container(
                  padding: const EdgeInsets.only(left: 10.0),
                  child: Row(
                    children: [
                      Text(_showAmount ? Utils.currencyFormat(_wallet.balance ?? 0) : "******",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(_showAmount ? Icons.remove_red_eye : Icons.visibility_off),
                        color: Theme.of(context).iconTheme.color,
                        onPressed: () {
                          // Scaffold.of(context).openDrawer();
                          setState(() {
                            _showAmount = !_showAmount;
                          });
                        },
                      ),
                    ],
                  ),
                ),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: s.get('notifications') ?? "Thông báo",
                  icon: const Icon(Icons.notifications),
                  color: Theme.of(context).iconTheme.color,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationListScreen())
                    );
                  },
                ),
                Consumer<AppNotificationProvider>(
                  builder: (context, provider, child) {
                    if (provider.unreadCount == 0) return const SizedBox.shrink();
                    return Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${provider.unreadCount > 99 ? '99+' : provider.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        // title: const Text('HomeScreen'),
      ),
      body: ListView(
         children: [
           Container(
             margin: const EdgeInsets.symmetric( horizontal: 10.0),
             padding: const EdgeInsets.all(12.0),
             decoration: BoxDecoration(
               gradient: cardGradient,
               border: Border.all(
                 color: borderColor,
                 width: 1.5,
               ),
               boxShadow: [
                 BoxShadow(
                   color: shadowColor,
                   blurRadius: 12,
                   offset: const Offset(0, 4),
                 ),
               ],
               borderRadius: BorderRadius.circular(14.0),
             ),
             child: Column(
               children: [
                 Container(
                   margin: const EdgeInsets.all(10.0),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text(s.get('my_wallet') ?? "Ví của tôi",
                           style: const TextStyle(
                             fontSize: 16.0,
                             fontWeight: FontWeight.bold,
                           )
                       ),
                       MyButton(
                         onTap: () {
                           _selectWallet(context);
                         },
                         child: Text(s.get('view_all') ?? "Xem tất cả",
                           style: const TextStyle(
                             fontSize: 13.0,
                             fontWeight: FontWeight.bold,
                             color: Colors.green,
                           ),
                         )
                       ),
                     ],
                   ),
                 ),
                 Divider(
                   color: Theme.of(context).dividerColor,
                   height: 1,
                   thickness: 1,
                   indent: 10,
                   endIndent: 10,
                 ),
                 Container(
                   padding: const EdgeInsets.all(10.0),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Row(
                         children: [
                           _wallet.id == 0 ?  Icon(Icons.language_outlined, color: Colors.green, size: 33,) : CircleAvatar(
                             backgroundColor: Colors.transparent,
                             radius: 20.0,
                             child: CustomIcon(iconPath: _wallet.icon, size: 40),
                           ),
                           Container(
                              margin: const EdgeInsets.only(left: 10.0),
                             child: Text(Utils.translateWalletName(context, _wallet.name),
                                 style: const TextStyle(
                                   fontSize: 15.0,
                                   fontWeight: FontWeight.w600,
                                 )
                             ),
                           )
                         ],
                       ),
                       Text(Utils.currencyFormat(_wallet.balance!),
                         style: TextStyle(
                           fontSize: 18.0,
                           fontWeight: FontWeight.bold,
                           color: balanceColor,
                         ),
                       ),
                     ],
                   ),
                 ),
               ],
             ),
           ),
           const SizedBox(height: 12.0),
           // Feature cards: Chatbot & Loan Management
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 10.0),
             child: IntrinsicHeight(
               child: Row(
               children: [
                 Expanded(
                   child: GestureDetector(
                     onTap: () {
                       Navigator.of(context).push(
                         MaterialPageRoute(builder: (context) => const ChatScreen()),
                       );
                     },
                     child: Container(
                       padding: const EdgeInsets.all(14),
                       decoration: BoxDecoration(
                         gradient: const LinearGradient(
                           colors: [Color(0xFF6C63FF), Color(0xFF9B8FFF)],
                           begin: Alignment.topLeft,
                           end: Alignment.bottomRight,
                         ),
                         borderRadius: BorderRadius.circular(14),
                         boxShadow: [
                           BoxShadow(
                             color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                             blurRadius: 8,
                             offset: const Offset(0, 4),
                           ),
                         ],
                       ),
                       child: Row(
                         children: [
                           Container(
                             padding: const EdgeInsets.all(8),
                             decoration: BoxDecoration(
                               color: Colors.white.withValues(alpha: 0.2),
                               borderRadius: BorderRadius.circular(10),
                             ),
                             child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 24),
                           ),
                           const SizedBox(width: 10),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 FittedBox(
                                   fit: BoxFit.scaleDown,
                                   alignment: Alignment.centerLeft,
                                   child: Text(
                                     s.get('chatbot') ?? 'Trợ lý tài chính',
                                     style: const TextStyle(
                                       color: Colors.white,
                                       fontWeight: FontWeight.bold,
                                       fontSize: 14,
                                     ),
                                   ),
                                 ),
                                 const SizedBox(height: 2),
                                 FittedBox(
                                   fit: BoxFit.scaleDown,
                                   alignment: Alignment.centerLeft,
                                   child: Text(
                                     s.get('chatbot_subtitle') ?? 'Hỏi đáp với AI',
                                     style: TextStyle(
                                       color: Colors.white.withValues(alpha: 0.8),
                                       fontSize: 11,
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                           ),
                           Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.7), size: 20),
                         ],
                       ),
                     ),
                   ),
                 ),
                 const SizedBox(width: 10),
                 Expanded(
                   child: GestureDetector(
                     onTap: () {
                       Navigator.pushNamed(context, '/LoanList');
                     },
                     child: Container(
                       padding: const EdgeInsets.all(14),
                       decoration: BoxDecoration(
                         gradient: const LinearGradient(
                           colors: [Color(0xFFFF8C42), Color(0xFFFFAB76)],
                           begin: Alignment.topLeft,
                           end: Alignment.bottomRight,
                         ),
                         borderRadius: BorderRadius.circular(14),
                         boxShadow: [
                           BoxShadow(
                             color: const Color(0xFFFF8C42).withValues(alpha: 0.3),
                             blurRadius: 8,
                             offset: const Offset(0, 4),
                           ),
                         ],
                       ),
                       child: Row(
                         children: [
                           Container(
                             padding: const EdgeInsets.all(8),
                             decoration: BoxDecoration(
                               color: Colors.white.withValues(alpha: 0.2),
                               borderRadius: BorderRadius.circular(10),
                             ),
                             child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                           ),
                           const SizedBox(width: 10),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 FittedBox(
                                   fit: BoxFit.scaleDown,
                                   alignment: Alignment.centerLeft,
                                   child: Text(
                                     s.get('loan_management') ?? 'Sổ nợ',
                                     style: const TextStyle(
                                       color: Colors.white,
                                       fontWeight: FontWeight.bold,
                                       fontSize: 14,
                                     ),
                                   ),
                                 ),
                                 const SizedBox(height: 2),
                                 FittedBox(
                                   fit: BoxFit.scaleDown,
                                   alignment: Alignment.centerLeft,
                                   child: Text(
                                     s.get('loan_subtitle') ?? 'Vay & Cho vay',
                                     style: TextStyle(
                                       color: Colors.white.withValues(alpha: 0.8),
                                       fontSize: 11,
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                           ),
                           Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.7), size: 20),
                         ],
                       ),
                     ),
                   ),
                 ),
               ],
             ),
             ),
           ),
            const QuickAddWidget(),
             const MiniDashboardWidget(),
             const QuickStatsWidget(),
           Container(
             margin: const EdgeInsets.symmetric( horizontal: 10.0),
             child: Container(
               margin: const EdgeInsets.symmetric(vertical: 10.0),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text(s.get('spending_report') ?? "Báo cáo chi tiêu",
                       style: const TextStyle(
                         fontSize: 13.0,
                         fontWeight: FontWeight.bold,
                         color: Colors.grey,
                       )
                   ),
                   MyButton(
                        backgroundColor: Colors.transparent,
                       onTap: () {
                         _showReportForPeriod(context);
                       },
                       child: Text(s.get('view_all') ?? "Xem tất cả",
                         style: const TextStyle(
                           fontSize: 13.0,
                           fontWeight: FontWeight.bold,
                           color: Colors.green,
                         ),
                       )
                   ),
                 ],
               ),
             ),
           ),
           const HomeReportWidget(),
           const SizedBox(
             height: 10.0,
           ),
           Container(
             margin: const EdgeInsets.symmetric( horizontal: 10.0),
             child: Container(
               margin: const EdgeInsets.symmetric(vertical: 10.0),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text(s.get('recent_transactions') ?? "Giao dịch gần đây",
                       style: const TextStyle(
                         fontSize: 13.0,
                         fontWeight: FontWeight.bold,
                         color: Colors.grey,
                       )
                   ),
                   MyButton(
                       backgroundColor: Colors.transparent,
                       onTap: () {
                         widget.jumpToPage(1);
                       },
                       child: Text(s.get('view_all') ?? "Xem tất cả",
                         style: const TextStyle(
                           fontSize: 13.0,
                           fontWeight: FontWeight.bold,
                           color: Colors.green,
                         ),
                       )
                   ),
                 ],
               ),
             ),
           ),
           Container(
             margin: const EdgeInsets.symmetric( horizontal: 10.0),
             padding: const EdgeInsets.all(10.0),
             decoration: BoxDecoration(
               color: Theme.of(context).cardColor,
               borderRadius: BorderRadius.circular(10.0),
             ),
             child: Column(
               children: [
                 Container(
                   margin: const EdgeInsets.only(top: 10.0),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        if(transactionNewest.isNotEmpty)
                          for(var item in transactionNewest)
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.transparent,
                                radius: 20.0,
                                child: CustomIcon(iconPath: item.group!.icon, size: 40),
                              ),
                              title: Text(Utils.translateGroupName(context, item.group!.name),
                                style: TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(MyDateUtils.toStringFormat00FromString(item.date ?? "", context: context),
                                style: TextStyle(
                                  fontSize: 13.0,
                                ),
                              ),
                              trailing: Text(
                                (item.type == 'expense' ? "-" : "+") + Utils.currencyFormat(item.amount ?? 0),
                                style: TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.bold,
                                  color: item.type == 'expense' ? Colors.red : Colors.green,
                                ),
                              ),
                            ),
                       if(!transactionNewest.isNotEmpty)
                         Container(
                             padding: const EdgeInsets.only(bottom:20.0),
                             margin: const EdgeInsets.only(top: 10.0),
                             child: Center(
                               child: Text(s.get('no_transactions_yet') ?? "Chưa có giao dịch nào",
                                 style: const TextStyle(
                                   fontSize: 13.0,
                                   fontWeight: FontWeight.normal,
                                   color: Colors.grey,
                                 ),
                               ),
                             )
                         ),
                     ],
                   ),
                 ),
               ],
             ),
           ),
            SizedBox(
              height: 100.0,
            ),
         ],
      ),
    );
  }
}


