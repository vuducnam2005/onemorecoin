import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OfflineReceiptResult {
  final double totalAmount;
  final String rawText;

  OfflineReceiptResult({
    required this.totalAmount,
    required this.rawText,
  });
}

class ReceiptOcrService {
  /// Scan a receipt image extract text via ML Kit and filter for the total amount
  static Future<OfflineReceiptResult?> scanReceipt(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      String fullText = recognizedText.text;
      
      // Split into lines for analysis
      List<String> lines = recognizedText.blocks
          .expand((block) => block.lines)
          .map((line) => line.text)
          .toList();
          
      double extractedAmount = _extractAmount(lines);
      
      return OfflineReceiptResult(
        totalAmount: extractedAmount,
        rawText: fullText,
      );
    } catch (e) {
      print('ML Kit OCR Error: $e');
      return null;
    } finally {
      textRecognizer.close();
    }
  }

  static double _extractAmount(List<String> lines) {
    // Priority 1: "Thanh toán", "Amount due"
    final p1Regex = RegExp(r'(thanh\s*toán|amount\s*due)', caseSensitive: false);
    // Priority 2: "Tổng tiền", "Tổng cộng", "Grand total"
    final p2Regex = RegExp(r'(tổng\s*tiền|tổng\s*cộng|grand\s*total)', caseSensitive: false);
    // Priority 3: "Total", "Thành tiền", "Subtotal"
    final p3Regex = RegExp(r'(total|thành\s*tiền|subtotal|cộng\s*tiền)', caseSensitive: false);
    
    double? foundAmount;

    // Check P1
    foundAmount = _scanLinesForKeyword(lines, p1Regex);
    if (foundAmount != null) return _roundVN(foundAmount);

    // Check P2
    foundAmount = _scanLinesForKeyword(lines, p2Regex);
    if (foundAmount != null) return _roundVN(foundAmount);

    // Check P3
    foundAmount = _scanLinesForKeyword(lines, p3Regex);
    if (foundAmount != null) return _roundVN(foundAmount);

    // Fallback: Find highest reasonable amount
    return _roundVN(_findHighestReasonableAmount(lines));
  }

  static double? _scanLinesForKeyword(List<String> lines, RegExp keywordRegex) {
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].toLowerCase();
      if (keywordRegex.hasMatch(line)) {
        // Check inline first
        double? amount = _extractNumberFromText(lines[i]);
        if (amount != null && _isValidAmount(amount)) return amount;
        
        // If not inline, check the next line
        if (i + 1 < lines.length) {
           amount = _extractNumberFromText(lines[i + 1]);
           if (amount != null && _isValidAmount(amount)) return amount;
        }
      }
    }
    return null;
  }

  static double _findHighestReasonableAmount(List<String> lines) {
    double maxAmount = 0;
    for (String line in lines) {
      double? amount = _extractNumberFromText(line);
      if (amount != null && _isValidAmount(amount)) {
        if (amount > maxAmount) {
          maxAmount = amount;
        }
      }
    }
    return maxAmount;
  }

  static double? _extractNumberFromText(String text) {
    if (_isGarbageLine(text)) return null;
    
    // Replace comma and dot based on common Vietnamese receipt formatting
    // Assume numbers like 322,000 or 322.000 are thousands
    String cleaned = text.replaceAll(RegExp(r'[^0-9\,\.]'), '');
    
    if (cleaned.isEmpty) return null;
    
    // Normalize format to English standard for double parsing (comma -> dot, remove extra dots)
    // First, remove dots if they are thousands separators, or commas if they are thousands separators
    // Easy trick for VN: Just remove all non-digits, and treat it as the full amount (assuming 0 decimal places for VND)
    // E.g. 322,000 -> 322000
    // But what if it's USD? e.g. 15.50
    // If text has ONLY one dot/comma in the last 3 chars, it might be decimals.
    
    // Simplified robust extraction for VN contexts: strip all separators
    String digitsOnly = cleaned.replaceAll(RegExp(r'[\,\.]'), '');
    return double.tryParse(digitsOnly);
  }

  static bool _isValidAmount(double amount) {
    // > 100M VND is suspicious for a daily offline receipt
    if (amount > 100000000) return false;
    // < 1K VND is too small, likely garbage or qty
    if (amount < 1000) return false;
    // Year context (1900-2100) and it falls in this exact range
    if (amount >= 1900 && amount <= 2100) return false;
    return true;
  }

  static bool _isGarbageLine(String text) {
    final lower = text.toLowerCase();
    
    // Eliminate dates/times
    if (RegExp(r'\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}').hasMatch(text)) return true; // 12/03/2024
    if (RegExp(r'\d{1,2}:\d{2}(:\d{2})?').hasMatch(text)) return true; // 14:30
    if (lower.contains('ngày') || lower.contains('tháng') || lower.contains('năm')) return true;
    
    // Eliminate phone numbers, tax codes, barcodes
    if (lower.contains('hotline') || lower.contains('tel') || lower.contains('sdt') || lower.contains('liên hệ')) return true;
    if (lower.contains('mst') || lower.contains('mã số thuế')) return true;
    if (lower.contains('hóa đơn') && RegExp(r'\d{5,}').hasMatch(text)) return true; // Mã hóa đơn 12345
    
    // Eliminate cash paid/change
    if (lower.contains('tiền khách') || lower.contains('khách đưa') || lower.contains('cash')) return true;
    if (lower.contains('tiền thừa') || lower.contains('tiền thối') || lower.contains('trả lại') || lower.contains('change')) return true;
    
    // Eliminate weights, quantities, stt
    if (lower.contains('kg') || lower.contains('gram') || lower.contains('stt') || lower.contains('số bàn') || lower.contains('table')) return true;

    return false;
  }

  static double _roundVN(double amount) {
    if (amount == 0) return 0;
    
    double remainder = amount % 1000;
    double base = amount - remainder;
    
    if (remainder >= 500) {
      return base + 1000;
    } else if (remainder < 200) {
      return base;
    } else {
      // 200 <= x < 500 -> keep origin
      return amount; // or keep as is, however realistically physical receipts round up.
    }
  }
}
