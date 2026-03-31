import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onemorecoin/model/BudgetModel.dart';
import 'package:onemorecoin/model/TransactionModel.dart';
import 'package:provider/provider.dart';
import 'package:onemorecoin/utils/currency_provider.dart';
import '../utils/Utils.dart';
import 'package:onemorecoin/utils/app_localizations.dart';

class MiniDashboardWidget extends StatelessWidget {
  const MiniDashboardWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    context.watch<CurrencyProvider>();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context).get('today_overview') ?? 'Today\'s Overview',
            style: const TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10.0),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildTodayExpense(context)),
                    Container(
                      width: 1,
                      height: 40,
                      color: Theme.of(context).dividerColor,
                    ),
                    Expanded(child: _buildBudgetUsage(context)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayExpense(BuildContext context) {
    final proxy = context.watch<TransactionModelProxy>();
    final wallet = proxy.walletModel;
    
    double todayExpense = 0;
    if (wallet.id != 0) {
      final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      // Get all transactions for current wallet, then filter for today's expense
      final allTrans = proxy.getTransactionByWalletId(wallet.id);
      
      for (var t in allTrans) {
        if (t.type == 'expense' && t.date != null && t.date!.startsWith(todayStr)) {
          todayExpense += (t.amount ?? 0);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_downward, color: Colors.red, size: 12),
            ),
            const SizedBox(width: 4),
            Text(
              S.of(context).get('spent_today_label') ?? 'Spent Today',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          Utils.currencyFormat(todayExpense),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetUsage(BuildContext context) {
    final budgetProxy = context.watch<BudgetModelProxy>();
    final transactionProxy = context.watch<TransactionModelProxy>();
    final wallet = transactionProxy.walletModel;
    
    double totalBudget = 0;
    double usedBudget = 0;

    if (wallet.id != 0) {
      final monthStr = DateFormat('yyyy-MM').format(DateTime.now());
      List<BudgetModel> activeBudgets = budgetProxy.getAllByWalletId(wallet.id);
      
      for (var b in activeBudgets) {
        if (b.fromDate != null) {
            // Check if budget is active this month
            if (b.fromDate!.startsWith(monthStr) || (b.isRepeat ?? false)) {
                totalBudget += (b.budget ?? 0);
                
                // Calculate usage
                for (var t in b.transactions) {
                  if (t.type == 'expense' && t.date != null && t.date!.startsWith(monthStr)) {
                    usedBudget += (t.amount ?? 0);
                  }
                }
            }
        }
      }
    }

    if (totalBudget == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            S.of(context).get('budget') ?? 'Budget',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context).get('not_set') ?? 'Not set',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ],
      );
    }

    double percent = (usedBudget / totalBudget).clamp(0.0, 1.0);
    Color progressColor = percent > 0.9 ? Colors.red : (percent > 0.7 ? Colors.orange : Colors.green);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              S.of(context).get('used_percent') ?? 'Used ',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              '${(percent * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.bold,
                color: progressColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percent,
            child: Container(
              decoration: BoxDecoration(
                color: progressColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${S.of(context).get('remaining_colon') ?? 'Remaining: '} ${Utils.currencyFormat(totalBudget - usedBudget)}',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
