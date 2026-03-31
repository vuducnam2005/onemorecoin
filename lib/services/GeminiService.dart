import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../model/GroupModel.dart';
import '../model/WalletModel.dart';

enum ChatIntent { addTransaction, queryTransactions, createWallet }

class TransactionExtracted {
  double amount;
  final int groupId;
  final String type;
  final String note;
  final bool isRealTransaction;
  final DateTime date;
  final ChatIntent intent;
  final DateTime? queryDateFrom;
  final DateTime? queryDateTo;
  final String currency;
  final int walletId;
  final String? walletName;
  final double walletBalance;

  TransactionExtracted({
    required this.amount,
    required this.groupId,
    required this.type,
    required this.note,
    required this.isRealTransaction,
    DateTime? date,
    this.intent = ChatIntent.addTransaction,
    this.queryDateFrom,
    this.queryDateTo,
    this.currency = 'VND',
    this.walletId = 0,
    this.walletName,
    this.walletBalance = 0,
  }) : date = date ?? DateTime.now();

  factory TransactionExtracted.fromJson(Map<String, dynamic> json) {
    ChatIntent intent;
    final intentStr = json['intent']?.toString() ?? '';
    if (intentStr == 'queryTransactions') {
      intent = ChatIntent.queryTransactions;
    } else if (intentStr == 'createWallet') {
      intent = ChatIntent.createWallet;
    } else {
      intent = ChatIntent.addTransaction;
    }

    return TransactionExtracted(
      amount: _parseDouble(json['amount']),
      groupId: _parseInt(json['groupId'], 1),
      type: json['type']?.toString() ?? 'expense',
      note: json['note']?.toString() ?? '',
      isRealTransaction: _parseBool(json['isRealTransaction'], true),
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) : null,
      currency: json['currency']?.toString().toUpperCase() ?? 'VND',
      walletId: _parseInt(json['walletId'], 0),
      intent: intent,
      queryDateFrom: json['queryDateFrom'] != null ? DateTime.tryParse(json['queryDateFrom'].toString()) : null,
      queryDateTo: json['queryDateTo'] != null ? DateTime.tryParse(json['queryDateTo'].toString()) : null,
      walletName: json['walletName']?.toString(),
      walletBalance: _parseDouble(json['walletBalance']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      // Remove all non-numeric characters EXCEPT the decimal point
      String cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  static int _parseInt(dynamic value, int defaultValue) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? defaultValue;
    return defaultValue;
  }

  static bool _parseBool(dynamic value, bool defaultValue) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return defaultValue;
  }
}

class GeminiService {
  // ========================
  // MAIN ENTRY: Try Gemini API first, fall back to local parser
  // ========================
  static Future<TransactionExtracted?> parseTransactionText(
      String userInput, List<GroupModel> groups, List<WalletModel> wallets, String locale, String currentCurrency) async {
    final input = userInput.toLowerCase().trim();

    // Check if user is querying transactions (not adding)
    if (_isQueryIntent(input)) {
      final dateRange = _extractDateRange(input);
      return TransactionExtracted(
        amount: 0,
        groupId: 0,
        type: '',
        note: '',
        isRealTransaction: false,
        intent: ChatIntent.queryTransactions,
        queryDateFrom: dateRange['from'],
        queryDateTo: dateRange['to'],
      );
    }

    // Check if user wants to create a wallet (local check first for speed)
    final localWalletResult = _parseCreateWallet(input);
    if (localWalletResult != null) {
      return localWalletResult;
    }

    // Try Gemini API
    try {
      final result = await _tryGeminiAPI(userInput, groups, wallets, locale, currentCurrency);
      if (result != null) return result;
    } catch (e) {
      print('Gemini API failed, falling back to local parser: $e');
    }

    // Fallback: Local keyword-based parser (no API needed)
    return _parseLocally(userInput, groups, wallets);
  }

  static bool _isQueryIntent(String input) {
    final queryKeywords = [
      'liệt kê', 'liet ke', 'những khoản', 'nhung khoan',
      'có những gì', 'co nhung gi', 'đã chi', 'da chi',
      'đã thu', 'da thu', 'tổng chi', 'tong chi', 'tổng thu', 'tong thu',
      'xem lại', 'xem lai', 'bao nhiêu', 'bao nhieu',
      'chi những gì', 'chi nhung gi', 'thu những gì', 'thu nhung gi',
      'chi tiêu gì', 'chi tieu gi', 'giao dịch nào', 'giao dich nao',
      'khoản chi nào', 'khoan chi nao', 'khoản thu nào', 'khoan thu nao',
      'tổng kết', 'tong ket', 'thống kê', 'thong ke',
      'chi gì', 'chi gi', 'thu gì', 'thu gi', 'tiêu gì', 'tieu gi',
      'làm gì', 'lam gi', 'tốn gì', 'ton gi'
    ];
    return queryKeywords.any((kw) => input.contains(kw));
  }

  static Map<String, DateTime> _extractDateRange(String input) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (RegExp(r'hôm qua|hom qua').hasMatch(input)) {
      final yesterday = today.subtract(const Duration(days: 1));
      return {'from': yesterday, 'to': yesterday.add(const Duration(hours: 23, minutes: 59, seconds: 59))};
    }
    if (RegExp(r'hôm kia|hom kia').hasMatch(input)) {
      final d = today.subtract(const Duration(days: 2));
      return {'from': d, 'to': d.add(const Duration(hours: 23, minutes: 59, seconds: 59))};
    }
    if (RegExp(r'hôm nay|hom nay').hasMatch(input)) {
      return {'from': today, 'to': today.add(const Duration(hours: 23, minutes: 59, seconds: 59))};
    }
    if (RegExp(r'tuần này|tuan nay').hasMatch(input)) {
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      return {'from': startOfWeek, 'to': today.add(const Duration(hours: 23, minutes: 59, seconds: 59))};
    }
    if (RegExp(r'tuần trước|tuan truoc').hasMatch(input)) {
      final startOfLastWeek = today.subtract(Duration(days: today.weekday + 6));
      final endOfLastWeek = today.subtract(Duration(days: today.weekday));
      return {'from': startOfLastWeek, 'to': endOfLastWeek.add(const Duration(hours: 23, minutes: 59, seconds: 59))};
    }
    if (RegExp(r'tháng này|thang nay').hasMatch(input)) {
      final startOfMonth = DateTime(now.year, now.month, 1);
      return {'from': startOfMonth, 'to': today.add(const Duration(hours: 23, minutes: 59, seconds: 59))};
    }
    if (RegExp(r'tháng trước|thang truoc').hasMatch(input)) {
      final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
      final endOfLastMonth = DateTime(now.year, now.month, 0, 23, 59, 59);
      return {'from': startOfLastMonth, 'to': endOfLastMonth};
    }

    // Specific date: "ngày 12 tháng 5" or "12/5"
    final specificDateMatch = RegExp(r'(?:ngày |ngay )?(\d{1,2})(?:\s*tháng\s*|\s*thang\s*|\s*/\s*)(\d{1,2})(?:\s*năm\s*|\s*nam\s*|\s*/\s*)?(\d{4})?').firstMatch(input);
    if (specificDateMatch != null) {
      try {
        int day = int.parse(specificDateMatch.group(1)!);
        int month = int.parse(specificDateMatch.group(2)!);
        int year = specificDateMatch.group(3) != null ? int.parse(specificDateMatch.group(3)!) : now.year;
        final specificDate = DateTime(year, month, day);
        return {'from': specificDate, 'to': specificDate.add(const Duration(hours: 23, minutes: 59, seconds: 59))};
      } catch (e) {
        // Fallback to today on parse error
      }
    }

    // Default: hôm nay
    return {'from': today, 'to': today.add(const Duration(hours: 23, minutes: 59, seconds: 59))};
  }

  // ========================
  // GEMINI API (online)
  // ========================
  static Future<TransactionExtracted?> _tryGeminiAPI(
      String userInput, List<GroupModel> groups, List<WalletModel> wallets, String locale, String currentCurrency) async {
    String? rawKey = dotenv.env['GEMINI_API_KEY'];
    if (rawKey != null) {
      rawKey = rawKey.replaceAll('"', '').replaceAll("'", '').trim();
    }
    if (rawKey == null || rawKey.isEmpty) return null;

    String groupsMapping =
        groups.map((g) => "${g.id}: ${g.name} (${g.type})").join("\n");
        
    String walletsMapping =
        wallets.map((w) => "${w.id}: ${w.name}").join("\n");

    final bool isEnglish = locale == 'en';
    
    final promptEn = """
You are a personal finance virtual assistant.
The user will input a natural language sentence. Please parse and extract the information into EXACTLY 1 JSON OBJECT.
DO NOT explain, DO NOT add any text other than the JSON.
Even if the user speaks another language, understand it and return the JSON.

List of categories (ID: Name (Type)):
$groupsMapping

List of wallets (ID: Name):
$walletsMapping

IMPORTANT - RULES:
1. Parse the EXACT amount the user mentioned. DO NOT do any currency math/multiply yourself. We will do it locally. E.g. if user says "1.5 USD", amount = 1.5. If user says "100k" (VND), amount = 100000.
2. Identify the currency mentioned by the user ("USD" or "VND"). If no currency is explicitly mentioned, assume it is "$currentCurrency".
3. Identify the EXACT wallet requested based on its name. If not explicitly requested, leave walletId as 1 or 0.
4. "intent": If user wants to ADD a transaction (e.g. "I ate pho for 50k"), intent="addTransaction". If user wants to VIEW/QUERY/LIST past transactions (e.g. "What did I spend today?", "List expenses on March 12"), intent="queryTransactions".

JSON to return:
1. "intent": "addTransaction", "queryTransactions", or "createWallet".
2. "amount": The exact amount requested. If intent="queryTransactions" or "createWallet", set to 0.
3. "currency": "USD" or "VND" exactly.
4. "groupId": Most suitable category ID. If intent="queryTransactions" or "createWallet", set to 1.
5. "walletId": Extracted wallet ID, else 0.
6. "type": "expense" or "income". MUST BE EXACTLY ONE OF THESE TWO.
7. "note": Short note about the transaction.
8. "isRealTransaction": true if it's a real transaction, false if spam/greeting. For createWallet, set to true.
9. "date": Date of the transaction (ISO-8601: YYYY-MM-DDTHH:mm:ss). Today is ${DateTime.now().toIso8601String()}.
10. "queryDateFrom": If intent="queryTransactions", the start of the queried time range (YYYY-MM-DDTHH:mm:ss). For a specific day, start time is 00:00:00. Today is ${DateTime.now().toIso8601String()}.
11. "queryDateTo": If intent="queryTransactions", the end of the queried time range (YYYY-MM-DDTHH:mm:ss). For a specific day, end time is 23:59:59.
12. "walletName": If intent="createWallet", the name of the new wallet to create.
13. "walletBalance": If intent="createWallet", the initial balance of the wallet (default 0 if not specified).

User input: "$userInput"
""";

    final promptVi = """
Bạn là một trợ lý ảo phân tích chi tiêu cá nhân. 
Người dùng sẽ nhập một câu nói tự nhiên. Hãy phân tích và trích xuất thông tin thành ĐÚNG 1 OBJECT JSON.
KHÔNG giải thích, KHÔNG thêm bất kỳ văn bản nào ngoài JSON.

Danh sách các nhóm (ID: Tên (Loại)):
$groupsMapping

Danh sách các ví (ID: Tên):
$walletsMapping

QUAN TRỌNG - NGUYÊN TẮC BÓC TÁCH:
1. Ghi nhận CHÍNH XÁC con số người dùng nói. TUYỆT ĐỐI KHÔNG làm phép nhân hay đổi tỷ giá tại đây. Ví dụ: "1.5 đô" -> amount = 1.5. "50k" -> amount = 50000.
2. Nhận diện loại tiền tệ người dùng sử dụng ("USD" hoặc "VND"). Nếu người dùng không nói rõ, hãy mặc định nó là loại tiền tệ "$currentCurrency".
3. Nhận diện ví xuất kho hoặc nhận tiền dựa trên Tên ví trong danh sách. Nếu không xác định, trả về walletId = 0.
4. "intent": 
   - Nếu người dùng CẦN THÊM giao dịch (vd: "Sáng nay ăn phở 50k", "nhận lương 5 triệu"), intent="addTransaction".
   - Nếu người dùng CẦN XEM/HỎI/THỐNG KÊ lại giao dịch (vd: "Hôm qua chi gì?"), intent="queryTransactions".
   - Nếu người dùng muốn TẠO VÍ MỚI (vd: "tạo ví đi chơi", "thêm ví tiết kiệm 500k"), intent="createWallet".

JSON cần trả về:
1. "intent": "addTransaction", "queryTransactions", hoặc "createWallet".
2. "amount": Số tiền chính xác (kiểu số). Nếu intent="queryTransactions" hoặc "createWallet", để 0.
3. "currency": Trả về ĐÚNG chữ "USD" hoặc "VND".
4. "groupId": ID nhóm phù hợp nhất. Nếu intent="queryTransactions" hoặc "createWallet", để 1.
5. "walletId": ID của ví thanh toán. Nếu không xác định, hoặc intent="queryTransactions", trả về 0.
6. "type": "expense" hoặc "income".
7. "note": Ghi chú ngắn. Cần lược bỏ từ ví thanh toán, ví dụ "ăn cơm bằng ví đi chơi" -> Ghi chú: "ăn cơm".
8. "isRealTransaction": true nếu là giao dịch hoặc tạo ví, false nếu spam/chào hỏi.
9. "date": Ngày giao dịch (YYYY-MM-DDTHH:mm:ss). Nếu người dùng nói "hôm qua", "hôm nay", tự tính dựa trên hôm nay là ${DateTime.now().toIso8601String()}.
10. "queryDateFrom": Nếu intent="queryTransactions", Ngày bắt đầu khoảng thời gian cần xem (YYYY-MM-DDTHH:mm:ss). Nếu xem 1 ngày cụ thể (vd ngày 12 tháng 3), startDate là 00:00:00 của ngày đó. Hôm nay là ${DateTime.now().toIso8601String()}.
11. "queryDateTo": Nếu intent="queryTransactions", Ngày kết thúc khoảng thời gian cần xem (YYYY-MM-DDTHH:mm:ss). Nếu xem 1 ngày cụ thể, endDate là 23:59:59 của ngày đó.
12. "walletName": Nếu intent="createWallet", tên ví mới cần tạo (chỉ lấy tên, bỏ đi phần "tạo ví", "thêm ví").
13. "walletBalance": Nếu intent="createWallet", số dư ban đầu của ví (mặc định 0 nếu không nói rõ).

Câu nói: "$userInput"
""";

    final prompt = isEnglish ? promptEn : promptVi;

    final attempts = [
      {'version': 'v1beta', 'model': 'gemini-2.5-flash'},
      {'version': 'v1beta', 'model': 'gemini-2.0-flash'},
      {'version': 'v1', 'model': 'gemini-2.0-flash'},
    ];

    for (final attempt in attempts) {
      final version = attempt['version']!;
      final model = attempt['model']!;
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/$version/models/$model:generateContent?key=$rawKey',
      );

      try {
        print('Trying: $version/$model');
        final response = await http
            .post(url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  "contents": [{"parts": [{"text": prompt}]}],
                  "generationConfig": {"responseMimeType": "application/json"}
                }))
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final jsonBody = jsonDecode(response.body);
          final text = jsonBody['candidates']?[0]?['content']?['parts']?[0]?['text'];
          if (text != null && text.isNotEmpty) {
            String cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
            final extracted = TransactionExtracted.fromJson(jsonDecode(cleaned));
            
            // LOCAL CONVERSION: Always convert USD to VND natively for the database
            if (extracted.currency == 'USD') {
              extracted.amount = extracted.amount * 26294.0;
            }
            
            return extracted;
          }
        } else {
          print('API error ($version/$model): ${response.statusCode}');
        }
      } catch (e) {
        print('Attempt failed ($version/$model): $e');
      }
    }
    return null;
  }

  // ========================
  // LOCAL PARSER (offline fallback)
  // Phân tích bằng từ khóa tiếng Việt
  // ========================
  static TransactionExtracted? _parseLocally(
      String userInput, List<GroupModel> groups, List<WalletModel> wallets) {
    final input = userInput.toLowerCase().trim();
    if (input.isEmpty) return null;

    // 1. Trích xuất số tiền
    final amount = _extractAmount(input);
    if (amount <= 0) {
      return TransactionExtracted(
        amount: 0,
        groupId: groups.isNotEmpty ? groups.first.id : 1,
        type: 'expense',
        note: userInput,
        isRealTransaction: false,
      );
    }

    // 2. Tìm nhóm phù hợp nhất bằng từ khóa
    final matched = _matchGroup(input, groups);

    // 3. Tìm ví thanh toán khớp với tên do người dùng lưu
    final matchedWalletInfo = _matchWalletAndCleanInput(input, wallets);
    final walletId = matchedWalletInfo['walletId'] as int;
    final cleanedInput = matchedWalletInfo['cleanedInput'] as String;

    // 4. Trích xuất ghi chú (bỏ phần số tiền và từ khóa ví)
    final note = _extractNote(cleanedInput);

    // 5. Trích xuất ngày từ từ khóa thời gian
    final date = _extractDate(cleanedInput);

    return TransactionExtracted(
      amount: amount,
      groupId: matched.id,
      type: matched.type ?? 'expense',
      note: note,
      isRealTransaction: true,
      date: date,
      walletId: walletId,
    );
  }

  static DateTime _extractDate(String input) {
    final now = DateTime.now();

    // "ngày mai" / "ngay mai"
    if (RegExp(r'ngày mai|ngay mai').hasMatch(input)) {
      return DateTime(now.year, now.month, now.day + 1);
    }
    // "ngày kia" / "ngay kia" / "ngày mốt" / "ngay mot"
    if (RegExp(r'ngày kia|ngay kia|ngày mốt|ngay mot').hasMatch(input)) {
      return DateTime(now.year, now.month, now.day + 2);
    }
    // "hôm qua" / "hom qua"
    if (RegExp(r'hôm qua|hom qua').hasMatch(input)) {
      return DateTime(now.year, now.month, now.day - 1);
    }
    // "hôm kia"
    if (RegExp(r'hôm kia|hom kia').hasMatch(input)) {
      return DateTime(now.year, now.month, now.day - 2);
    }
    // "tuần trước" / "tuan truoc"
    if (RegExp(r'tuần trước|tuan truoc').hasMatch(input)) {
      return now.subtract(const Duration(days: 7));
    }
    // "tuần sau" / "tuan sau"
    if (RegExp(r'tuần sau|tuan sau').hasMatch(input)) {
      return now.add(const Duration(days: 7));
    }
    // "tháng trước" / "thang truoc"
    if (RegExp(r'tháng trước|thang truoc').hasMatch(input)) {
      return DateTime(now.year, now.month - 1, now.day);
    }

    // Default: hôm nay
    return now;
  }

  static double _extractAmount(String input) {
    // Patterns: "200k", "200K", "200 nghìn", "200 ngàn", "2 triệu", "2tr", "1.5 triệu", "500000"
    final patterns = [
      RegExp(r'(\d+[\.,]?\d*)\s*(?:triệu|tr)', caseSensitive: false),
      RegExp(r'(\d+[\.,]?\d*)\s*(?:k|K|nghìn|ngàn|ngan|nghin)', caseSensitive: false),
      RegExp(r'(\d+[\.,]?\d*)\s*(?:đồng|dong|đ|vnd|vnđ)', caseSensitive: false),
      RegExp(r'(\d{4,})', caseSensitive: false), // số lớn >= 4 chữ số (vd: 50000)
    ];

    final multipliers = [1000000.0, 1000.0, 1.0, 1.0];

    for (int i = 0; i < patterns.length; i++) {
      final match = patterns[i].firstMatch(input);
      if (match != null) {
        String numStr = match.group(1)!.replaceAll(',', '.');
        double value = double.tryParse(numStr) ?? 0;
        return value * multipliers[i];
      }
    }

    // Fallback: tìm bất kỳ số nào
    final anyNumber = RegExp(r'(\d+)').firstMatch(input);
    if (anyNumber != null) {
      double value = double.tryParse(anyNumber.group(1)!) ?? 0;
      // Nếu số nhỏ hơn 1000, giả sử đơn vị là nghìn
      if (value > 0 && value < 1000) {
        return value * 1000;
      }
      return value;
    }

    return 0;
  }

  static GroupModel _matchGroup(String input, List<GroupModel> groups) {
    // Mapping từ khóa -> tên nhóm
    final keywordMap = {
      'Ăn uống': [
        'ăn', 'an', 'bữa', 'bua', 'cơm', 'com', 'phở', 'pho', 'bún', 'bun',
        'mì', 'mi', 'cafe', 'cà phê', 'ca phe', 'trà', 'tra', 'uống', 'uong',
        'nhậu', 'nhau', 'lẩu', 'lau', 'nước', 'nuoc', 'bia', 'rượu', 'ruou',
        'bánh', 'banh', 'chè', 'che', 'kem', 'thịt', 'thit', 'cá', 'ca',
        'rau', 'tôm', 'tom', 'gà', 'ga', 'heo', 'bò', 'bo', 'đồ ăn', 'do an',
        'thức ăn', 'thuc an', 'quán', 'quan', 'nhà hàng', 'nha hang',
        'sáng', 'sang', 'trưa', 'trua', 'tối', 'toi', 'chiều', 'chieu',
        'pizza', 'burger', 'gỏi', 'goi', 'chả', 'cha', 'xôi', 'xoi',
      ],
      'Di chuyển': [
        'xăng', 'xang', 'xe', 'taxi', 'grab', 'uber', 'bus', 'gửi xe', 'gui xe',
        'đỗ xe', 'do xe', 'vé xe', 've xe', 'tàu', 'tau', 'máy bay', 'may bay',
        'đi lại', 'di lai', 'xăng dầu', 'xang dau', 'đổ xăng', 'do xang',
        'gojek', 'be', 'vé', 've', 'cầu đường', 'cau duong', 'phí đường', 'phi duong',
      ],
      'Mua sắm': [
        'mua', 'sắm', 'sam', 'shopping', 'quần', 'quan', 'áo', 'ao', 'giày', 'giay',
        'dép', 'dep', 'túi', 'tui', 'đồ', 'do', 'váy', 'vay', 'nón', 'non',
        'mũ', 'mu', 'kính', 'kinh', 'phụ kiện', 'phu kien', 'đồng hồ', 'dong ho',
      ],
      'Sức khỏe': [
        'thuốc', 'thuoc', 'bệnh viện', 'benh vien', 'khám', 'kham', 'bác sĩ', 'bac si',
        'y tế', 'y te', 'sức khỏe', 'suc khoe', 'gym', 'tập', 'tap', 'yoga',
        'vitamin', 'bổ sung', 'bo sung',
      ],
      'Giải trí': [
        'xem phim', 'phim', 'game', 'chơi', 'choi', 'giải trí', 'giai tri',
        'karaoke', 'du lịch', 'du lich', 'vui chơi', 'vui choi', 'nhạc', 'nhac',
        'concert', 'show', 'netflix', 'spotify',
      ],
      'Tiền nhà': [
        'nhà', 'nha', 'thuê nhà', 'thue nha', 'trọ', 'tro', 'phòng', 'phong',
      ],
      'Tiền điện': [
        'điện', 'dien', 'tiền điện', 'tien dien',
      ],
      'Tiền nước': [
        'nước', 'nuoc', 'tiền nước', 'tien nuoc',
      ],
      'Tiền internet': [
        'internet', 'wifi', 'mạng', 'mang', 'net', 'cáp', 'cap',
      ],
      'Tiền điện thoại': [
        'điện thoại', 'dien thoai', 'nạp tiền', 'nap tien', 'sim', 'cước', 'cuoc',
      ],
      'Tiền học': [
        'học', 'hoc', 'sách', 'sach', 'khóa', 'khoa', 'lớp', 'lop', 'trường', 'truong',
        'học phí', 'hoc phi',
      ],
      'Lương': [
        'lương', 'luong', 'salary',
      ],
      'Thưởng': [
        'thưởng', 'thuong', 'bonus',
      ],
      'Lãi': [
        'lãi', 'lai', 'lợi nhuận', 'loi nhuan', 'đầu tư', 'dau tu',
      ],
      'Bán đồ': [
        'bán', 'ban', 'thanh lý', 'thanh ly',
      ],
      'Khác': [
        'khác', 'khac', 'linh tinh', 'lặt vặt', 'lat vat', 'nhặt', 'nhat',
      ],
    };

    // Tìm nhóm phù hợp nhất
    String? bestGroupName;
    int bestScore = 0;

    keywordMap.forEach((groupName, keywords) {
      int score = 0;
      for (final keyword in keywords) {
        if (input.contains(keyword)) {
          score += keyword.length; // Ưu tiên keywords dài hơn (chính xác hơn)
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestGroupName = groupName;
      }
    });

    if (bestGroupName != null) {
      final match = groups.cast<GroupModel?>().firstWhere(
        (g) => g?.name == bestGroupName,
        orElse: () => null,
      );
      if (match != null) return match;
    }

    // Default: Nhóm "Tiền khác" (expense) hoặc nhóm đầu tiên
    final defaultGroup = groups.cast<GroupModel?>().firstWhere(
      (g) => g?.name == 'Tiền khác' && g?.type == 'expense',
      orElse: () => groups.isNotEmpty ? groups.first : null,
    );
    return defaultGroup ?? GroupModel(1, 0, name: 'Khác', type: 'expense');
  }

  static String _extractNote(String input) {
    // Loại bỏ phần số tiền ra khỏi note
    String note = input
        .replaceAll(RegExp(r'\d+[\.,]?\d*\s*(?:triệu|tr|k|K|nghìn|ngàn|đồng|dong|đ|vnd|vnđ)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\d{4,}'), '')
        .replaceAll(RegExp(r'\bhết\b|\btốn\b|\bmất\b|\bchi\b|\btiêu\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bhôm nay\b|\bsáng nay\b|\bchiều nay\b|\btối nay\b|\bhôm qua\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(bằng|từ|vào) ví\b.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    if (note.isEmpty) note = input.replaceAll(RegExp(r'[\d]+[kK]?'), '').trim();
    if (note.isEmpty) note = input;
    
    return note;
  }

  static Map<String, dynamic> _matchWalletAndCleanInput(String input, List<WalletModel> wallets) {
    int walletId = 0;
    String cleanedInput = input;
    
    // Sort wallets by length descending so longer matching strings win
    final sortedWallets = List<WalletModel>.from(wallets)
      ..sort((a, b) => (b.name?.length ?? 0).compareTo(a.name?.length ?? 0));

    for (final wallet in sortedWallets) {
      if (wallet.name == null || wallet.name!.isEmpty) continue;
      
      final walletNameLower = wallet.name!.toLowerCase();
      // Check if the user mentioned the wallet
      // Trích xuất với pattern: "ví ABC" hoặc "bằng ABC" v.v...
      if (input.contains(walletNameLower)) {
        walletId = wallet.id;
        // Clean out context keywords
        cleanedInput = input.replaceAll(walletNameLower, '').trim();
        break;
      }
    }
    
    return {
      'walletId': walletId,
      'cleanedInput': cleanedInput,
    };
  }

  // ========================
  // CREATE WALLET PARSER (local)
  // Detect "tạo ví", "thêm ví", "create wallet" commands
  // ========================
  static TransactionExtracted? _parseCreateWallet(String input) {
    // Match patterns like: "tạo ví ABC", "thêm ví ABC 500k", "tạo ví ABC số dư 1 triệu"
    final createWalletPatterns = [
      RegExp(r'^(?:tạo|tao|thêm|them|mở|mo|lập|lap)\s+(?:ví|vi)\s+(.+)', caseSensitive: false),
      RegExp(r'^create\s+wallet\s+(.+)', caseSensitive: false),
      RegExp(r'^new\s+wallet\s+(.+)', caseSensitive: false),
    ];

    for (final pattern in createWalletPatterns) {
      final match = pattern.firstMatch(input);
      if (match != null) {
        String remaining = match.group(1)!.trim();
        
        // Extract optional balance from the remaining text
        double balance = 0;
        String walletName = remaining;
        
        // Try to extract amount patterns like "500k", "1 triệu", "số dư 500k"
        final balancePatterns = [
          RegExp(r'(?:số dư|so du|balance)?\s*(\d+[\.,]?\d*)\s*(?:triệu|tr)', caseSensitive: false),
          RegExp(r'(?:số dư|so du|balance)?\s*(\d+[\.,]?\d*)\s*(?:k|K|nghìn|ngàn|ngan|nghin)', caseSensitive: false),
          RegExp(r'(?:số dư|so du|balance)?\s*(\d+[\.,]?\d*)\s*(?:đồng|dong|đ|vnd|vnđ)', caseSensitive: false),
          RegExp(r'(?:số dư|so du|balance)?\s*(\d{4,})', caseSensitive: false),
        ];
        final balanceMultipliers = [1000000.0, 1000.0, 1.0, 1.0];

        for (int i = 0; i < balancePatterns.length; i++) {
          final balanceMatch = balancePatterns[i].firstMatch(remaining);
          if (balanceMatch != null) {
            String numStr = balanceMatch.group(1)!.replaceAll(',', '.');
            balance = (double.tryParse(numStr) ?? 0) * balanceMultipliers[i];
            // Remove the balance part from wallet name
            walletName = remaining.replaceAll(balanceMatch.group(0)!, '').trim();
            // Also remove common prefix words
            walletName = walletName.replaceAll(RegExp(r'\b(?:số dư|so du|balance|với|voi|có|co)\b', caseSensitive: false), '').trim();
            break;
          }
        }

        if (walletName.isEmpty) {
          walletName = remaining;
        }

        return TransactionExtracted(
          amount: 0,
          groupId: 0,
          type: '',
          note: '',
          isRealTransaction: true,
          intent: ChatIntent.createWallet,
          walletName: walletName,
          walletBalance: balance,
        );
      }
    }
    return null;
  }
}
