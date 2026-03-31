import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:onemorecoin/model/TransactionModel.dart';
import 'package:onemorecoin/model/LoanModel.dart';
import 'package:onemorecoin/utils/Utils.dart';
import 'package:onemorecoin/utils/app_localizations.dart';

class HomeStatsWidget extends StatelessWidget {
  const HomeStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final transactions = context.watch<TransactionModelProxy>().getAll();
    final loanProvider = context.watch<LoanProvider>();

    // Calculate income & expense totals
    double totalIncome = 0;
    double totalExpense = 0;
    for (final t in transactions) {
      if (t.type == 'income') {
        totalIncome += t.amount ?? 0;
      } else if (t.type == 'expense') {
        totalExpense += t.amount ?? 0;
      }
    }

    final totalLent = loanProvider.getTotalLent();
    final totalBorrowed = loanProvider.getTotalBorrowed();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: s.get('income') ?? 'Thu nhập',
                  amount: totalIncome,
                  bgColor: const Color(0xFFE8F5E9),
                  borderColor: const Color(0xFF81C784),
                  textColor: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: s.get('expense') ?? 'Chi tiêu',
                  amount: totalExpense,
                  bgColor: const Color(0xFFFFEBEE),
                  borderColor: const Color(0xFFE57373),
                  textColor: const Color(0xFFC62828),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: s.get('lending') ?? 'Cho vay',
                  amount: totalLent,
                  bgColor: const Color(0xFFE0F7FA),
                  borderColor: const Color(0xFF4DD0E1),
                  textColor: const Color(0xFF00838F),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: s.get('borrowing') ?? 'Đi vay',
                  amount: totalBorrowed,
                  bgColor: const Color(0xFFE3F2FD),
                  borderColor: const Color(0xFF90CAF9),
                  textColor: const Color(0xFF1565C0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;

  const _StatCard({
    required this.label,
    required this.amount,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Utils.currencyFormat(amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
