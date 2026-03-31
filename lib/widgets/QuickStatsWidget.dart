import 'package:flutter/material.dart';
import 'package:onemorecoin/model/LoanModel.dart';
import 'package:onemorecoin/model/TransactionModel.dart';
import 'package:onemorecoin/utils/Utils.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onemorecoin/utils/app_localizations.dart';
import 'package:onemorecoin/utils/currency_provider.dart';

class QuickStatsWidget extends StatefulWidget {
  const QuickStatsWidget({Key? key}) : super(key: key);

  @override
  State<QuickStatsWidget> createState() => _QuickStatsWidgetState();
}

class _QuickStatsWidgetState extends State<QuickStatsWidget> {
  bool _showStats = true;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showStats = prefs.getBool('show_home_quick_stats') ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CurrencyProvider>();
    final s = S.of(context);
    // Watch relevant providers
    final transactionProxy = context.watch<TransactionModelProxy>();
    final loanProvider = context.watch<LoanProvider>();

    final wallet = transactionProxy.walletModel;
    final transactions = transactionProxy.getTransactionByWalletId(wallet.id);

    // Calculate this month's Income and Expense
    final now = DateTime.now();
    final String monthStr = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    double monthIncome = 0.0;
    double monthExpense = 0.0;

    for (var t in transactions) {
      if (t.date != null && t.date!.startsWith(monthStr)) {
        if (t.type == 'income') {
          monthIncome += t.amount ?? 0;
        } else if (t.type == 'expense') {
          monthExpense += t.amount ?? 0;
        }
      }
    }

    // Get Loan amounts
    final totalBorrowed = loanProvider.getTotalBorrowed(); // Tổng vay
    final totalLent = loanProvider.getTotalLent(); // Tổng nợ (cho vay)

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(left: 10.0, right: 10.0, top: 10.0, bottom: 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.get('quick_stats') ?? 'Quick Stats',
                style: const TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  setState(() {
                    _showStats = !_showStats;
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('show_home_quick_stats', _showStats);
                },
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    _showStats ? (s.get('hide_stats') ?? 'Hide') : (s.get('show_stats') ?? 'Show'),
                    style: const TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            firstChild: Column(
              children: [
                const SizedBox(height: 10.0),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context: context,
                        title: s.get('total_income') ?? 'Tổng thu',
                        amount: monthIncome,
                        color: Colors.green,
                        icon: Icons.south_west_rounded,
                        isDark: isDark,
                        subtitle: s.get('this_month') ?? 'This month',
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: _buildStatCard(
                        context: context,
                        title: s.get('total_expense') ?? 'Tổng chi',
                        amount: monthExpense,
                        color: Colors.red,
                        icon: Icons.north_east_rounded,
                        isDark: isDark,
                        subtitle: s.get('this_month') ?? 'This month',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context: context,
                        title: s.get('total_borrowed') ?? 'Tổng vay',
                        amount: totalBorrowed,
                        color: Colors.orange,
                        icon: Icons.account_balance_wallet_rounded,
                        isDark: isDark,
                        subtitle: s.get('currently') ?? 'Currently',
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: _buildStatCard(
                        context: context,
                        title: s.get('total_lent') ?? 'Tổng nợ',
                        amount: totalLent,
                        color: Colors.blue,
                        icon: Icons.handshake_rounded,
                        isDark: isDark,
                        subtitle: s.get('currently') ?? 'Currently',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _showStats ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
    required bool isDark,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Container(
                padding: const EdgeInsets.all(6.0),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Text(
            Utils.currencyFormat(amount, withoutUnit: true),
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.0,
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
