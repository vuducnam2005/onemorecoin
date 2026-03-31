import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';
import '../../model/TransactionModel.dart';
import '../../model/GroupModel.dart';
import '../../model/WalletModel.dart';
import '../../services/GeminiService.dart';
import '../../widgets/ChatMessageWidget.dart';
import '../../widgets/TransactionPreviewWidget.dart';
import '../../utils/currency_provider.dart';
import '../../utils/Utils.dart';
import '../../utils/app_localizations.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<dynamic> _messages = [];
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isTyping = false;
  bool _isListening = false;
  bool _speechSubmitted = false;

  @override
  void initState() {
    super.initState();
    // Use deferred message addition because we need context for localization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = S.of(context);
      _messages.add(ChatMessage(
        text: s.get('chatbot_welcome') ?? "Xin chào! 👋 Hãy bắt đầu thêm giao dịch của bạn tại đây nhé!",
        isUser: false,
      ));
      
      // Ensure groups are loaded
      final groupProxy = Provider.of<GroupModelProxy>(context, listen: false);
      if (groupProxy.getAll().isEmpty) {
        groupProxy.fetchAll();
      }
    });
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
      });
      return;
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (error) {
        setState(() {
          _isListening = false;
        });
        print('Speech recognition error: $error');
      },
    );

    if (available) {
      setState(() {
        _isListening = true;
        _speechSubmitted = false;
      });
      await _speech.listen(
        onResult: (result) {
          if (_speechSubmitted) return;
          setState(() {
            _textController.text = result.recognizedWords;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length),
            );
          });
        },
        localeId: 'vi_VN',
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: true,
        ),
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    } else {
      final s = S.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.get('speech_not_available') ?? 'Không thể sử dụng giọng nói. Hãy cấp quyền micro cho ứng dụng.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;
    _speechSubmitted = true;

    // Stop speech recognition if active to prevent onResult overwriting
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
      });
    }

    _textController.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isTyping = true;
    });
    _scrollToBottom();

    final transactionProxy = Provider.of<TransactionModelProxy>(context, listen: false);
    final groupProxy = Provider.of<GroupModelProxy>(context, listen: false);
    final walletProxy = Provider.of<WalletModelProxy>(context, listen: false);

    var groups = groupProxy.getAll();
    if (groups.isEmpty) {
      await groupProxy.fetchAll();
      groups = groupProxy.getAll();
    }

    final s = S.of(context);
    final locale = s.languageCode;
    final currentCurrency = CurrencyProvider.currentCurrency;
    var wallets = walletProxy.getAll();

    try {
      TransactionExtracted? extracted = await GeminiService.parseTransactionText(text, groups, wallets, locale, currentCurrency);

      setState(() {
        _isTyping = false;
      });

      if (extracted != null) {
        // === CREATE WALLET INTENT ===
        if (extracted.intent == ChatIntent.createWallet) {
          final walletName = extracted.walletName ?? 'Ví mới';
          final walletBalance = extracted.walletBalance;

          // Check if wallet with same name already exists
          final existingWallet = wallets.cast<WalletModel?>().firstWhere(
            (w) => w?.name?.toLowerCase() == walletName.toLowerCase(),
            orElse: () => null,
          );

          if (existingWallet != null) {
            setState(() {
              _messages.add(ChatMessage(
                text: s.get('chatbot_wallet_exists') ?? "Ví \"$walletName\" đã tồn tại rồi! 📋",
                isUser: false,
              ));
            });
          } else {
            final newWallet = WalletModel(
              walletProxy.getId(),
              name: walletName,
              icon: "assets/images/icon_wallet_primary.png",
              balance: walletBalance,
              currency: CurrencyProvider.currentCurrency,
              isReport: true,
            );
            await walletProxy.add(newWallet);

            setState(() {
              String balanceText = walletBalance > 0 
                ? " ${s.get('chatbot_with_balance') ?? 'với số dư'} ${_formatMoney(walletBalance)}"
                : " ${s.get('chatbot_with_balance_zero') ?? 'với số dư 0 đồng'}";
              _messages.add(ChatMessage(
                text: "✅ ${s.get('chatbot_wallet_created') ?? 'Đã tạo ví'} \"$walletName\"$balanceText!",
                isUser: false,
              ));
            });
          }
        }
        // === QUERY INTENT: List transactions ===
        else if (extracted.intent == ChatIntent.queryTransactions) {
          final from = extracted.queryDateFrom ?? DateTime.now();
          final to = extracted.queryDateTo ?? DateTime.now();
          final transactions = transactionProxy.getAllByDate(from, to);

          if (transactions.isEmpty) {
            setState(() {
              _messages.add(ChatMessage(
                text: s.get('chatbot_no_transaction') ?? "Không có giao dịch nào trong khoảng thời gian này 📭",
                isUser: false,
              ));
            });
          } else {
            double totalExpense = 0;
            double totalIncome = 0;
            for (var t in transactions) {
              if (t.type == 'expense') {
                totalExpense += t.amount ?? 0;
              } else {
                totalIncome += t.amount ?? 0;
              }
            }

            String summaryMsg = s.get('chatbot_summary') ?? "📊 Tổng kết: {count} giao dịch\n";
            String expenseMsg = s.get('chatbot_total_expense') ?? "💸 Chi: {amount}\n";
            String incomeMsg = s.get('chatbot_total_income') ?? "💰 Thu: {amount}";
            
            String summary = summaryMsg.replaceAll('{count}', transactions.length.toString());
            if (totalExpense > 0) summary += expenseMsg.replaceAll('{amount}', _formatMoney(totalExpense));
            if (totalIncome > 0) summary += incomeMsg.replaceAll('{amount}', _formatMoney(totalIncome));

            setState(() {
              _messages.add(ChatMessage(text: summary.trim(), isUser: false));
              for (var t in transactions) {
                final group = groupProxy.getById(t.groupId);
                _messages.add({
                  'type': 'transaction_preview',
                  'transaction': t,
                  'group': group,
                });
              }
            });
          }
        }
        // === ADD TRANSACTION INTENT ===
        else if (!extracted.isRealTransaction) {
          setState(() {
            _messages.add(ChatMessage(
              text: s.get('chatbot_error_understand') ?? "Mình chưa hiểu rõ ý bạn, bạn có thể nói lại một giao dịch cụ thể hơn được không? (Ví dụ: 'Sáng nay uống cafe 50k')",
              isUser: false,
            ));
          });
        } else {
          GroupModel matchedGroup = groups.firstWhere(
            (g) => g.id == extracted.groupId,
            orElse: () => groups.first,
          );

          int walletId = extracted.walletId;
          
          if (walletId <= 0) {
            if (wallets.isNotEmpty) {
               walletId = wallets.first.id;
            } else {
               walletId = 1;
            }
          } else {
            // Verify wallet actually exists
            final walletExists = wallets.any((w) => w.id == walletId);
            if (!walletExists) {
               walletId = wallets.isNotEmpty ? wallets.first.id : 1;
            }
          }

          final String newId = const Uuid().v4();
          final TransactionModel transaction = TransactionModel(
            newId,
            amount: extracted.amount,
            unit: CurrencyProvider.currentCurrency,
            // LUÔN DÙNG matchedGroup.type ĐỂ ĐẢM BẢO KHÔNG BỊ SAI TYPE DO AI TRẢ VỀ CHỮ HOA / TIẾNG VIỆT
            type: matchedGroup.type ?? 'expense',
            date: extracted.date.toIso8601String(),
            note: extracted.note,
            addToReport: true,
            walletId: walletId,
            groupId: matchedGroup.id,
          );

          await transactionProxy.add(transaction);
          
          // Update Wallet Balance
          var wallet = walletProxy.getById(walletId);
          double newBalance = (transaction.type == 'expense') 
              ? (wallet.balance ?? 0) - (transaction.amount ?? 0)
              : (wallet.balance ?? 0) + (transaction.amount ?? 0);
          await walletProxy.updateBalance(wallet, newBalance);

          setState(() {
            String successMsgTemplate = transaction.type == 'expense' 
              ? (s.get('chatbot_success_expense') ?? "Tuyệt vời! Mình đã ghi lại khoản chi của bạn vào danh mục {group}. Cùng giữ thói quen tốt nhé! 💪")
              : (s.get('chatbot_success_income') ?? "Tuyệt vời! Mình đã ghi lại khoản thu của bạn vào danh mục {group}. Cùng giữ thói quen tốt nhé! 💪");
            
            _messages.add(ChatMessage(
              text: successMsgTemplate.replaceAll('{group}', matchedGroup.name ?? ''),
              isUser: false,
            ));
            _messages.add({
              'type': 'transaction_preview',
              'transaction': transaction,
              'group': matchedGroup,
            });
          });
        }
      } else {
        setState(() {
          _messages.add(ChatMessage(
            text: s.get('chatbot_error_parse') ?? "Xin lỗi, đã xảy ra lỗi trong quá trình phân tích. Vui lòng thử lại.",
            isUser: false,
          ));
        });
      }
    } catch (e) {
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text: s.languageCode == 'en' ? "An error occurred: $e" : "Có lỗi xảy ra: $e",
          isUser: false,
        ));
      });
    }
    _scrollToBottom();
  }

  String _formatMoney(double amount) {
    return Utils.currencyFormat(amount);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(s.get('chatbot_title') ?? "Hôm nay bạn đã chi tiêu gì?", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.normal, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: Theme.of(context).iconTheme,
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Center(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Image.asset('assets/images/icons/bot_avatar.png', height: 80, errorBuilder: (c, e, errorStackInfo) => const Icon(Icons.smart_toy, size: 80, color: Colors.pink)),
                const SizedBox(height: 8),
                Text(s.get('chatbot_subtitle') ?? "Cuộc trò chuyện kéo dài 48 giờ", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.teal.shade200),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet, size: 14, color: Colors.teal),
                      const SizedBox(width: 6),
                      Text(s.get('chatbot_spending') ?? "Chi Tiêu", style: const TextStyle(color: Colors.teal, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 20, bottom: 20),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return ChatMessageWidget(
                    message: ChatMessage(text: "", isUser: false, isTyping: true),
                  );
                }

                final item = _messages[index];
                if (item is ChatMessage) {
                  return ChatMessageWidget(message: item);
                } else if (item is Map && item['type'] == 'transaction_preview') {
                  return TransactionPreviewWidget(
                    transaction: item['transaction'],
                    group: item['group'],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -1),
                  blurRadius: 5,
                )
              ]
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      decoration: InputDecoration(
                        hintText: s.get('chatbot_hint') ?? "bữa tối 100k, mua sắm 400k",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        fillColor: isDark ? Colors.grey.shade800 : Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(color: Colors.teal),
                        ),
                      ),
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.red : const Color(0xFF2C2C2C),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                      ),
                      onPressed: _toggleListening,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF2C2C2C),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      // Biểu tượng Send nếu đang gõ, Camera nếu rỗng
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () => _handleSubmitted(_textController.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
