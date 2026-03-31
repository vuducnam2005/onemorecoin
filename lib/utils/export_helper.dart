import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../model/TransactionModel.dart';

class ExportHelper {
  /// Xuất danh sách giao dịch ra file Excel (.xlsx)
  static Future<File?> exportToExcel(
    List<TransactionModel> transactions, {
    String reportTitle = 'Báo cáo giao dịch',
    String exportDateLabel = 'Ngày xuất',
    String serialLabel = 'STT',
    String titleLabel = 'Tiêu đề',
    String amountLabel = 'Số tiền',
    String typeLabel = 'Loại',
    String groupLabel = 'Nhóm',
    String walletLabel = 'Ví',
    String dateLabel = 'Ngày',
    String noteLabel = 'Ghi chú',
    String incomeLabel = 'Thu nhập',
    String expenseLabel = 'Chi tiêu',
    String totalIncomeLabel = 'Tổng thu nhập',
    String totalExpenseLabel = 'Tổng chi tiêu',
  }) async {
    try {
      var excel = Excel.createExcel();
      var sheet = excel['Giao dịch'];

      // Remove default sheet
      excel.delete('Sheet1');

      // Header row
      final headers = [
        serialLabel,
        titleLabel,
        amountLabel,
        typeLabel,
        groupLabel,
        walletLabel,
        dateLabel,
        noteLabel,
      ];

      // Style for header
      var headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );

      for (int i = 0; i < headers.length; i++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Data rows
      double totalIncome = 0;
      double totalExpense = 0;

      for (int i = 0; i < transactions.length; i++) {
        final t = transactions[i];
        final row = i + 1;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = IntCellValue(i + 1);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(t.title ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = DoubleCellValue(t.amount ?? 0);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = TextCellValue(
          t.type == 'income' ? incomeLabel : expenseLabel,
        );
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = TextCellValue(t.group?.name ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = TextCellValue(t.wallet?.name ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = TextCellValue(
          t.date != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(t.date!)) : '',
        );
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = TextCellValue(t.note ?? '');

        if (t.type == 'income') {
          totalIncome += t.amount ?? 0;
        } else {
          totalExpense += t.amount ?? 0;
        }
      }

      // Summary rows
      final summaryRow = transactions.length + 2;
      var summaryStyle = CellStyle(bold: true);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRow)).value = TextCellValue(totalIncomeLabel);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRow)).cellStyle = summaryStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: summaryRow)).value = DoubleCellValue(totalIncome);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRow + 1)).value = TextCellValue(totalExpenseLabel);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRow + 1)).cellStyle = summaryStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: summaryRow + 1)).value = DoubleCellValue(totalExpense);

      // Set column widths
      sheet.setColumnWidth(0, 8);
      sheet.setColumnWidth(1, 25);
      sheet.setColumnWidth(2, 18);
      sheet.setColumnWidth(3, 12);
      sheet.setColumnWidth(4, 18);
      sheet.setColumnWidth(5, 18);
      sheet.setColumnWidth(6, 15);
      sheet.setColumnWidth(7, 25);

      // Save file
      final dir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir.path}/giao_dich_$timestamp.xlsx';
      final fileBytes = excel.save();
      if (fileBytes == null) return null;

      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      return file;
    } catch (e) {
      return null;
    }
  }

  /// Xuất danh sách giao dịch ra file PDF
  static Future<File?> exportToPdf(
    List<TransactionModel> transactions, {
    String reportTitle = 'Báo cáo giao dịch',
    String exportDateLabel = 'Ngày xuất',
    String serialLabel = 'STT',
    String titleLabel = 'Tiêu đề',
    String amountLabel = 'Số tiền',
    String typeLabel = 'Loại',
    String groupLabel = 'Nhóm',
    String walletLabel = 'Ví',
    String dateLabel = 'Ngày',
    String noteLabel = 'Ghi chú',
    String incomeLabel = 'Thu nhập',
    String expenseLabel = 'Chi tiêu',
    String totalIncomeLabel = 'Tổng thu nhập',
    String totalExpenseLabel = 'Tổng chi tiêu',
  }) async {
    try {
      final fontRegular = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
      );

      double totalIncome = 0;
      double totalExpense = 0;
      for (var t in transactions) {
        if (t.type == 'income') {
          totalIncome += t.amount ?? 0;
        } else {
          totalExpense += t.amount ?? 0;
        }
      }

      final numberFormat = NumberFormat('#,##0', 'vi_VN');

      // Split transactions into chunks for pagination
      const int rowsPerPage = 25;
      final int pageCount = (transactions.length / rowsPerPage).ceil().clamp(1, 999);

      for (int page = 0; page < pageCount; page++) {
        final start = page * rowsPerPage;
        final end = (start + rowsPerPage).clamp(0, transactions.length);
        final chunk = transactions.sublist(start, end);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (page == 0) ...[
                    pw.Center(
                      child: pw.Text(
                        reportTitle,
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Center(
                      child: pw.Text(
                        '$exportDateLabel: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ),
                    pw.SizedBox(height: 16),
                  ],
                  pw.TableHelper.fromTextArray(
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                    cellStyle: const pw.TextStyle(fontSize: 8),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.blue100),
                    cellAlignments: {
                      0: pw.Alignment.center,
                      2: pw.Alignment.centerRight,
                    },
                    headers: [serialLabel, titleLabel, amountLabel, typeLabel, groupLabel, dateLabel],
                    data: chunk.asMap().entries.map((entry) {
                      final idx = start + entry.key;
                      final t = entry.value;
                      return [
                        '${idx + 1}',
                        t.title ?? '',
                        numberFormat.format(t.amount ?? 0),
                        t.type == 'income' ? incomeLabel : expenseLabel,
                        t.group?.name ?? '',
                        t.date != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(t.date!)) : '',
                      ];
                    }).toList(),
                  ),
                  if (page == pageCount - 1) ...[
                    pw.SizedBox(height: 16),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('$totalIncomeLabel: ${numberFormat.format(totalIncome)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                        pw.Text('$totalExpenseLabel: ${numberFormat.format(totalExpense)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        );
      }

      // Save file
      final dir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir.path}/giao_dich_$timestamp.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      return null;
    }
  }

  /// Xuất danh sách giao dịch ra file CSV
  static Future<File?> exportToCsv(
    List<TransactionModel> transactions, {
    String serialLabel = 'STT',
    String titleLabel = 'Tiêu đề',
    String amountLabel = 'Số tiền',
    String typeLabel = 'Loại',
    String groupLabel = 'Nhóm',
    String walletLabel = 'Ví',
    String dateLabel = 'Ngày',
    String noteLabel = 'Ghi chú',
    String incomeLabel = 'Thu nhập',
    String expenseLabel = 'Chi tiêu',
  }) async {
    try {
      List<List<dynamic>> rows = [];

      // Header
      rows.add([serialLabel, titleLabel, amountLabel, typeLabel, groupLabel, walletLabel, dateLabel, noteLabel]);

      // Data
      for (int i = 0; i < transactions.length; i++) {
        final t = transactions[i];
        rows.add([
          i + 1,
          t.title ?? '',
          t.amount ?? 0,
          t.type == 'income' ? incomeLabel : expenseLabel,
          t.group?.name ?? '',
          t.wallet?.name ?? '',
          t.date != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(t.date!)) : '',
          t.note ?? '',
        ]);
      }

      final csvData = const ListToCsvConverter().convert(rows);

      // Add UTF-8 BOM for Excel compatibility with Vietnamese
      final dir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir.path}/giao_dich_$timestamp.csv';
      final file = File(filePath);
      await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...csvData.codeUnits]);
      return file;
    } catch (e) {
      return null;
    }
  }

  /// Chia sẻ file đã xuất
  static Future<void> shareFile(File file) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }
}
