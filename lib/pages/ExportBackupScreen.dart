import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../model/BudgetModel.dart';
import '../model/GroupModel.dart';
import '../model/TransactionModel.dart';
import '../model/WalletModel.dart';
import '../utils/app_localizations.dart';
import '../utils/backup_helper.dart';
import '../utils/export_helper.dart';
import '../widgets/AlertDiaLog.dart';
import '../Objects/AlertDiaLogItem.dart';

enum ExportFilterType { all, day, month, quarter, year, range }

class ExportBackupScreen extends StatefulWidget {
  const ExportBackupScreen({super.key});

  @override
  State<ExportBackupScreen> createState() => _ExportBackupScreenState();
}

class _ExportBackupScreenState extends State<ExportBackupScreen> {
  ExportFilterType _filterType = ExportFilterType.all;
  DateTime? _selectedDate;
  DateTime? _selectedMonth;
  int _selectedQuarter = 1;
  int _selectedYear = DateTime.now().year;
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _selectedMonth = now;
    _selectedQuarter = ((now.month - 1) / 3).floor() + 1;
    _selectedYear = now.year;
    _selectedRange = DateTimeRange(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return LoaderOverlay(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            s.get('export_backup') ?? 'Xuất & Sao lưu dữ liệu',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0.0,
        ),
        body: ListView(
          children: [
            const SizedBox(height: 16),
            // Section header: Export Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                s.get('export_filter') ?? 'Bộ lọc xuất',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ),
            Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _buildFilterDropdown(s),
                  if (_filterType != ExportFilterType.all) const SizedBox(height: 12),
                  _buildFilterSelector(context, s),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Section header: Export
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                s.get('export_data') ?? 'Xuất dữ liệu',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ),
            Container(
              color: Theme.of(context).cardColor,
              child: Column(
                children: [
                  Divider(color: Theme.of(context).dividerColor, height: 0.5),
                  ListTile(
                    leading: const Icon(Icons.table_chart, color: Colors.green),
                    title: Text(s.get('export_excel') ?? 'Xuất Excel (.xlsx)'),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                    onTap: () => _exportExcel(context),
                  ),
                  Divider(color: Theme.of(context).dividerColor, height: 0.5),
                  ListTile(
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    title: Text(s.get('export_pdf') ?? 'Xuất PDF'),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                    onTap: () => _exportPdf(context),
                  ),
                  Divider(color: Theme.of(context).dividerColor, height: 0.5),
                  ListTile(
                    leading: const Icon(Icons.description, color: Colors.blue),
                    title: Text(s.get('export_csv') ?? 'Xuất CSV'),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                    onTap: () => _exportCsv(context),
                  ),
                  Divider(color: Theme.of(context).dividerColor, height: 0.5),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section header: Backup
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                s.get('backup_section') ?? 'Sao lưu',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ),
            Container(
              color: Theme.of(context).cardColor,
              child: Column(
                children: [
                  Divider(color: Theme.of(context).dividerColor, height: 0.5),
                  ListTile(
                    leading: const Icon(Icons.backup, color: Colors.purple),
                    title: Text(s.get('backup_data') ?? 'Sao lưu dữ liệu'),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                    onTap: () => _backupData(context),
                  ),
                  Divider(color: Theme.of(context).dividerColor, height: 0.5),
                  ListTile(
                    leading: const Icon(Icons.restore, color: Colors.orange),
                    title: Text(s.get('restore_data') ?? 'Khôi phục dữ liệu'),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                    onTap: () => _restoreData(context),
                  ),
                  Divider(color: Theme.of(context).dividerColor, height: 0.5),
                ],
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(S s) {
    return DropdownButtonFormField<ExportFilterType>(
      value: _filterType,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        DropdownMenuItem(value: ExportFilterType.all, child: Text(s.get('filter_all') ?? 'Tất cả')),
        DropdownMenuItem(value: ExportFilterType.day, child: Text(s.get('filter_day') ?? 'Theo ngày')),
        DropdownMenuItem(value: ExportFilterType.month, child: Text(s.get('filter_month') ?? 'Theo tháng')),
        DropdownMenuItem(value: ExportFilterType.quarter, child: Text(s.get('filter_quarter') ?? 'Theo kỳ (quý)')),
        DropdownMenuItem(value: ExportFilterType.year, child: Text(s.get('filter_year') ?? 'Theo năm')),
        DropdownMenuItem(value: ExportFilterType.range, child: Text(s.get('filter_range') ?? 'Khoảng thời gian')),
      ],
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _filterType = val;
          });
        }
      },
    );
  }

  Widget _buildFilterSelector(BuildContext context, S s) {
    switch (_filterType) {
      case ExportFilterType.all:
        return const SizedBox.shrink();
      case ExportFilterType.day:
        return ListTile(
          title: Text(_selectedDate != null ? DateFormat('dd/MM/yyyy').format(_selectedDate!) : (s.get('select_date') ?? 'Chọn ngày')),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
        );
      case ExportFilterType.month:
        return ListTile(
          title: Text(_selectedMonth != null ? DateFormat('MM/yyyy').format(_selectedMonth!) : (s.get('select_month') ?? 'Chọn tháng')),
          trailing: const Icon(Icons.calendar_view_month),
          onTap: () async {
            // A simple way to pick month/year without importing complex packages
            // Show year picker then month picker
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedMonth ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              initialDatePickerMode: DatePickerMode.year,
            );
            if (picked != null) {
              setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
            }
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
        );
      case ExportFilterType.quarter:
        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _selectedQuarter,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [1, 2, 3, 4].map((q) => DropdownMenuItem(value: q, child: Text('Q$q'))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedQuarter = val);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _selectedYear,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: List.generate(20, (i) => DateTime.now().year - 10 + i)
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedYear = val);
                },
              ),
            ),
          ],
        );
      case ExportFilterType.year:
        return DropdownButtonFormField<int>(
          value: _selectedYear,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: List.generate(20, (i) => DateTime.now().year - 10 + i)
              .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedYear = val);
          },
        );
      case ExportFilterType.range:
        return ListTile(
          title: Text(_selectedRange != null 
            ? '${DateFormat('dd/MM/yyyy').format(_selectedRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedRange!.end)}'
            : (s.get('select_range') ?? 'Chọn khoảng thời gian')),
          trailing: const Icon(Icons.date_range),
          onTap: () async {
            final picked = await showDateRangePicker(
              context: context,
              initialDateRange: _selectedRange ?? DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() => _selectedRange = picked);
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
        );
    }
  }

  /// Get localized labels for export methods
  Map<String, String> _getLabels(S s) {
    return {
      'reportTitle': s.get('transaction_report') ?? 'Báo cáo giao dịch',
      'exportDateLabel': s.get('export_date') ?? 'Ngày xuất',
      'serialLabel': s.get('serial_number') ?? 'STT',
      'titleLabel': s.get('title') ?? 'Tiêu đề',
      'amountLabel': s.get('amount') ?? 'Số tiền',
      'typeLabel': s.get('type') ?? 'Loại',
      'groupLabel': s.get('group') ?? 'Nhóm',
      'walletLabel': s.get('wallet') ?? 'Ví',
      'dateLabel': s.get('date') ?? 'Ngày',
      'noteLabel': s.get('note') ?? 'Ghi chú',
      'incomeLabel': s.get('income') ?? 'Thu nhập',
      'expenseLabel': s.get('expense') ?? 'Chi tiêu',
      'totalIncomeLabel': s.get('total_income') ?? 'Tổng thu nhập',
      'totalExpenseLabel': s.get('total_expense') ?? 'Tổng chi tiêu',
    };
  }

  List<TransactionModel> _getFilteredTransactions(BuildContext context) {
    final all = context.read<TransactionModelProxy>().getAll();
    
    DateTime? startDate;
    DateTime? endDate;

    switch (_filterType) {
      case ExportFilterType.all:
        return all;
      case ExportFilterType.day:
        if (_selectedDate != null) {
          startDate = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
          endDate = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59);
        }
        break;
      case ExportFilterType.month:
        if (_selectedMonth != null) {
          startDate = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
          final nextMonth = (_selectedMonth!.month < 12) ? _selectedMonth!.month + 1 : 1;
          final nextYear = (_selectedMonth!.month < 12) ? _selectedMonth!.year : _selectedMonth!.year + 1;
          endDate = DateTime(nextYear, nextMonth, 1).subtract(const Duration(seconds: 1));
        }
        break;
      case ExportFilterType.quarter:
        final startMonth = (_selectedQuarter - 1) * 3 + 1;
        startDate = DateTime(_selectedYear, startMonth, 1);
        final nextMonth = startMonth + 3;
        if (nextMonth > 12) {
          endDate = DateTime(_selectedYear + 1, 1, 1).subtract(const Duration(seconds: 1));
        } else {
          endDate = DateTime(_selectedYear, nextMonth, 1).subtract(const Duration(seconds: 1));
        }
        break;
      case ExportFilterType.year:
        startDate = DateTime(_selectedYear, 1, 1);
        endDate = DateTime(_selectedYear, 12, 31, 23, 59, 59);
        break;
      case ExportFilterType.range:
        if (_selectedRange != null) {
          startDate = DateTime(_selectedRange!.start.year, _selectedRange!.start.month, _selectedRange!.start.day);
          endDate = DateTime(_selectedRange!.end.year, _selectedRange!.end.month, _selectedRange!.end.day, 23, 59, 59);
        }
        break;
    }

    return all.where((t) {
      if (t.date == null) return false;
      final d = DateTime.tryParse(t.date!);
      if (d == null) return false;
      
      if (startDate != null && d.isBefore(startDate)) return false;
      if (endDate != null && d.isAfter(endDate)) return false;
      
      return true;
    }).toList();
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _exportExcel(BuildContext context) async {
    final s = S.of(context);
    final transactions = _getFilteredTransactions(context);

    if (transactions.isEmpty) {
      _showSnackBar(context, s.get('no_transactions_to_export') ?? 'Không có giao dịch nào để xuất', isError: true);
      return;
    }

    context.loaderOverlay.show();
    try {
      final labels = _getLabels(s);
      final file = await ExportHelper.exportToExcel(
        transactions,
        reportTitle: labels['reportTitle']!,
        exportDateLabel: labels['exportDateLabel']!,
        serialLabel: labels['serialLabel']!,
        titleLabel: labels['titleLabel']!,
        amountLabel: labels['amountLabel']!,
        typeLabel: labels['typeLabel']!,
        groupLabel: labels['groupLabel']!,
        walletLabel: labels['walletLabel']!,
        dateLabel: labels['dateLabel']!,
        noteLabel: labels['noteLabel']!,
        incomeLabel: labels['incomeLabel']!,
        expenseLabel: labels['expenseLabel']!,
        totalIncomeLabel: labels['totalIncomeLabel']!,
        totalExpenseLabel: labels['totalExpenseLabel']!,
      );
      context.loaderOverlay.hide();

      if (file != null) {
        await ExportHelper.shareFile(file);
      } else {
        _showSnackBar(context, s.get('export_fail') ?? 'Xuất file thất bại', isError: true);
      }
    } catch (e) {
      context.loaderOverlay.hide();
      _showSnackBar(context, s.get('export_fail') ?? 'Xuất file thất bại', isError: true);
    }
  }

  Future<void> _exportPdf(BuildContext context) async {
    final s = S.of(context);
    final transactions = _getFilteredTransactions(context);

    if (transactions.isEmpty) {
      _showSnackBar(context, s.get('no_transactions_to_export') ?? 'Không có giao dịch nào để xuất', isError: true);
      return;
    }

    context.loaderOverlay.show();
    try {
      final labels = _getLabels(s);
      final file = await ExportHelper.exportToPdf(
        transactions,
        reportTitle: labels['reportTitle']!,
        exportDateLabel: labels['exportDateLabel']!,
        serialLabel: labels['serialLabel']!,
        titleLabel: labels['titleLabel']!,
        amountLabel: labels['amountLabel']!,
        typeLabel: labels['typeLabel']!,
        groupLabel: labels['groupLabel']!,
        walletLabel: labels['walletLabel']!,
        dateLabel: labels['dateLabel']!,
        noteLabel: labels['noteLabel']!,
        incomeLabel: labels['incomeLabel']!,
        expenseLabel: labels['expenseLabel']!,
        totalIncomeLabel: labels['totalIncomeLabel']!,
        totalExpenseLabel: labels['totalExpenseLabel']!,
      );
      context.loaderOverlay.hide();

      if (file != null) {
        await ExportHelper.shareFile(file);
      } else {
        _showSnackBar(context, s.get('export_fail') ?? 'Xuất file thất bại', isError: true);
      }
    } catch (e) {
      context.loaderOverlay.hide();
      _showSnackBar(context, s.get('export_fail') ?? 'Xuất file thất bại', isError: true);
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    final s = S.of(context);
    final transactions = _getFilteredTransactions(context);

    if (transactions.isEmpty) {
      _showSnackBar(context, s.get('no_transactions_to_export') ?? 'Không có giao dịch nào để xuất', isError: true);
      return;
    }

    context.loaderOverlay.show();
    try {
      final labels = _getLabels(s);
      final file = await ExportHelper.exportToCsv(
        transactions,
        serialLabel: labels['serialLabel']!,
        titleLabel: labels['titleLabel']!,
        amountLabel: labels['amountLabel']!,
        typeLabel: labels['typeLabel']!,
        groupLabel: labels['groupLabel']!,
        walletLabel: labels['walletLabel']!,
        dateLabel: labels['dateLabel']!,
        noteLabel: labels['noteLabel']!,
        incomeLabel: labels['incomeLabel']!,
        expenseLabel: labels['expenseLabel']!,
      );
      context.loaderOverlay.hide();

      if (file != null) {
        await ExportHelper.shareFile(file);
      } else {
        _showSnackBar(context, s.get('export_fail') ?? 'Xuất file thất bại', isError: true);
      }
    } catch (e) {
      context.loaderOverlay.hide();
      _showSnackBar(context, s.get('export_fail') ?? 'Xuất file thất bại', isError: true);
    }
  }

  Future<void> _backupData(BuildContext context) async {
    final s = S.of(context);

    context.loaderOverlay.show();
    try {
      final file = await BackupHelper.backupDatabase();
      context.loaderOverlay.hide();

      if (file != null) {
        await BackupHelper.shareBackup(file);
      } else {
        _showSnackBar(context, s.get('export_fail') ?? 'Sao lưu thất bại', isError: true);
      }
    } catch (e) {
      context.loaderOverlay.hide();
      _showSnackBar(context, s.get('export_fail') ?? 'Sao lưu thất bại', isError: true);
    }
  }

  Future<void> _restoreData(BuildContext context) async {
    final s = S.of(context);

    showAlertDialog(
      context: context,
      title: Text(s.get('restore_confirm') ?? 'Dữ liệu hiện tại sẽ bị thay thế. Bạn có chắc?'),
      optionItems: [
        AlertDiaLogItem(
          text: s.get('restore_data') ?? 'Khôi phục',
          textStyle: const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
          ),
          okOnPressed: () async {
            context.loaderOverlay.show();
            try {
              final success = await BackupHelper.restoreDatabase();
              if (success) {
                // Reload all providers
                await context.read<WalletModelProxy>().init();
                await context.read<GroupModelProxy>().init();
                await context.read<TransactionModelProxy>().init();
                await context.read<BudgetModelProxy>().init();

                // ignore: use_build_context_synchronously
                context.loaderOverlay.hide();
                // ignore: use_build_context_synchronously
                _showSnackBar(context, s.get('restore_success') ?? 'Khôi phục dữ liệu thành công');
              } else {
                // ignore: use_build_context_synchronously
                context.loaderOverlay.hide();
                // ignore: use_build_context_synchronously
                _showSnackBar(context, s.get('restore_fail') ?? 'Khôi phục thất bại', isError: true);
              }
            } catch (e) {
              // ignore: use_build_context_synchronously
              context.loaderOverlay.hide();
              // ignore: use_build_context_synchronously
              _showSnackBar(context, s.get('restore_fail') ?? 'Khôi phục thất bại', isError: true);
            }
          },
        ),
      ],
      cancelItem: AlertDiaLogItem(
        text: s.get('cancel') ?? 'Huỷ',
        textStyle: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.normal,
        ),
        okOnPressed: () {},
      ),
    );
  }
}
