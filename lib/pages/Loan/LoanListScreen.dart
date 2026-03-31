import 'package:flutter/material.dart';
import 'package:onemorecoin/model/LoanModel.dart';
import 'package:onemorecoin/utils/Utils.dart';
import 'package:onemorecoin/utils/app_localizations.dart';
import 'package:provider/provider.dart';

class LoanListScreen extends StatefulWidget {
  const LoanListScreen({super.key});

  @override
  State<LoanListScreen> createState() => _LoanListScreenState();
}

class _LoanListScreenState extends State<LoanListScreen> with SingleTickerProviderStateMixin {
  String _tabSelect = 'borrow';
  String _statusFilter = '';
  String _searchPerson = '';
  final _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _tabSelect = _tabController.index == 0 ? 'borrow' : 'lend';
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'paid':
        return const Color(0xFF4CAF50);
      case 'partial':
        return const Color(0xFFFFA726);
      default:
        return const Color(0xFFEF5350);
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'paid':
        return Icons.check_circle_rounded;
      case 'partial':
        return Icons.timelapse_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  String _getStatusText(BuildContext context, String? status) {
    final s = S.of(context);
    switch (status) {
      case 'paid':
        return s.get('loan_paid') ?? 'Đã trả';
      case 'partial':
        return s.get('loan_partial') ?? 'Trả một phần';
      default:
        return s.get('loan_unpaid') ?? 'Chưa trả';
    }
  }

  Color get _accentColor => _tabSelect == 'borrow'
      ? const Color(0xFFE53935)
      : const Color(0xFF1E88E5);

  List<Color> get _gradientColors => _tabSelect == 'borrow'
      ? [const Color(0xFFE53935), const Color(0xFFB71C1C)]
      : [const Color(0xFF1E88E5), const Color(0xFF0D47A1)];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loanProvider = context.watch<LoanProvider>();

    if (loanProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final loans = loanProvider.filter(
      type: _tabSelect,
      status: _statusFilter.isNotEmpty ? _statusFilter : null,
      personName: _searchPerson.isNotEmpty ? _searchPerson : null,
    );

    final totalAmount = loans.fold<double>(0, (sum, l) => sum + l.remainingAmount);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(s.get('loan_management') ?? 'Sổ nợ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Tab Switcher ───
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: _accentColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                tabs: [
                  Tab(text: s.get('loan_borrow') ?? 'Đi vay'),
                  Tab(text: s.get('loan_lend') ?? 'Cho vay'),
                ],
              ),
            ),

            // ─── Summary Card ───
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Decorative circle
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 20,
                    bottom: -30,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tabSelect == 'borrow'
                                ? (s.get('total_borrowed') ?? 'Tổng nợ còn lại')
                                : (s.get('total_lent') ?? 'Tổng cho vay còn lại'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            Utils.currencyFormat(totalAmount),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${loans.length} ${s.get('loan_items') ?? 'khoản'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ─── Search Bar ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchPerson = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: s.get('search_person') ?? 'Tìm theo người...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 10),

            // ─── Quick Filter Chips ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: s.get('all') ?? 'Tất cả',
                      value: '',
                      icon: Icons.list_rounded,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: s.get('loan_unpaid') ?? 'Chưa trả',
                      value: 'unpaid',
                      icon: Icons.warning_amber_rounded,
                      statusColor: const Color(0xFFEF5350),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: s.get('loan_partial') ?? 'Trả một phần',
                      value: 'partial',
                      icon: Icons.timelapse_rounded,
                      statusColor: const Color(0xFFFFA726),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: s.get('loan_paid') ?? 'Đã trả',
                      value: 'paid',
                      icon: Icons.check_circle_rounded,
                      statusColor: const Color(0xFF4CAF50),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ─── Loan List ───
            Expanded(
              child: loans.isEmpty
                  ? _buildEmptyState(s, isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: loans.length,
                      itemBuilder: (context, index) {
                        final loan = loans[index];
                        return _buildLoanCard(loan, s, isDark, context);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/AddLoan', arguments: _tabSelect);
        },
        backgroundColor: _accentColor,
        elevation: 6,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required IconData icon,
    Color? statusColor,
    required bool isDark,
  }) {
    final isSelected = _statusFilter == value;
    final chipColor = statusColor ?? _accentColor;

    return GestureDetector(
      onTap: () {
        setState(() {
          _statusFilter = isSelected ? '' : value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withOpacity(isDark ? 0.25 : 0.15)
              : isDark ? Colors.grey[850] : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? chipColor.withOpacity(0.6)
                : isDark ? Colors.grey[700]! : Colors.grey[300]!,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? chipColor
                  : isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? chipColor
                    : isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(S s, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(isDark ? 0.15 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 40,
              color: _accentColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            s.get('no_loans') ?? 'Chưa có sổ nợ nào',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _tabSelect == 'borrow'
                ? (s.get('loan_borrow_hint') ?? 'Nhấn + để thêm khoản vay mới')
                : (s.get('loan_lend_hint') ?? 'Nhấn + để thêm khoản cho vay'),
            style: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(LoanModel loan, S s, bool isDark, BuildContext context) {
    final progress = (loan.amount ?? 0) > 0
        ? (loan.paidAmount ?? 0) / (loan.amount ?? 1)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 0.8,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/LoanDetail',
              arguments: loan,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          // Avatar with status ring
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _getStatusColor(loan.status).withOpacity(isDark ? 0.2 : 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _getStatusColor(loan.status).withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              color: _getStatusColor(loan.status),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loan.personName ?? '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  loan.date != null
                                      ? Utils.getStringFormatDayOfWeek(
                                          DateTime.parse(loan.date!),
                                          context: context)
                                      : '',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Utils.currencyFormat(loan.amount ?? 0),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _accentColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getStatusColor(loan.status).withOpacity(isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(loan.status),
                                size: 12,
                                color: _getStatusColor(loan.status),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getStatusText(context, loan.status),
                                style: TextStyle(
                                  color: _getStatusColor(loan.status),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (loan.status != 'unpaid') ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getStatusColor(loan.status),
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${s.get('loan_paid_amount') ?? 'Đã trả'}: ${Utils.currencyFormat(loan.paidAmount ?? 0)} / ${Utils.currencyFormat(loan.amount ?? 0)}',
                    style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
                if (loan.isOverdue && loan.status != 'paid') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(isDark ? 0.2 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 14, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          s.get('loan_overdue') ?? 'Quá hạn!',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (loan.note != null && loan.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 14,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          loan.note!,
                          style: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
