import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onemorecoin/components/MyButton.dart';
import 'package:onemorecoin/pages/Profile/ProfileSecurity.dart';
import 'package:onemorecoin/widgets/PinDialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Objects/AlertDiaLogItem.dart';
import 'Reminders/RemindersScreen.dart';
import '../model/BudgetModel.dart';
import '../model/GroupModel.dart';
import '../model/StorageStage.dart';
import '../model/TransactionModel.dart';
import '../model/WalletModel.dart';
import '../widgets/AlertDiaLog.dart';
import 'LoginScreen.dart';
import 'ExportBackupScreen.dart';
import '../model/LoanModel.dart';
import '../model/ReminderModel.dart';
import '../model/AppNotificationModel.dart';

import '../utils/theme_provider.dart';
import '../utils/currency_provider.dart';
import '../utils/language_provider.dart';
import '../utils/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late bool islogin = false;
  late Account? user;
  String? _avatarPath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final proxy = Provider.of<StorageStageProxy>(context, listen: false);
    final currentUser = proxy.getCurrentUser();
    if (currentUser == null) return;
    
    final userId = currentUser['id'];
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('user_avatar_path_$userId');
    if (path != null && File(path).existsSync()) {
      if (mounted) {
        setState(() {
          _avatarPath = path;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _avatarPath = null;
        });
      }
    }
  }

  Future<void> _pickAvatar(BuildContext context) async {
    final s = S.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(s.get('choose_from_gallery') ?? 'Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(ctx);
                _getImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(s.get('take_photo') ?? 'Chụp ảnh'),
              onTap: () {
                Navigator.pop(ctx);
                _getImage(ImageSource.camera);
              },
            ),
            if (_avatarPath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(s.get('remove_avatar') ?? 'Xóa ảnh đại diện',
                    style: const TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final prefs = await SharedPreferences.getInstance();
                  final userId = user?.id ?? '';
                  await prefs.remove('user_avatar_path_$userId');
                  if (_avatarPath != null) {
                    final oldFile = File(_avatarPath!);
                    if (await oldFile.exists()) {
                      await oldFile.delete();
                    }
                  }
                  setState(() {
                    _avatarPath = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image != null) {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedPath = '${dir.path}/avatar_$timestamp.jpg';

      if (_avatarPath != null) {
        final oldFile = File(_avatarPath!);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }

      await File(image.path).copy(savedPath);
      final prefs = await SharedPreferences.getInstance();
      final userId = user?.id ?? '';
      await prefs.setString('user_avatar_path_$userId', savedPath);
      setState(() {
        _avatarPath = savedPath;
      });
    }
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: () => _pickAvatar(context),
      child: Stack(
        children: [
          CircleAvatar(
            backgroundColor: Colors.deepPurple,
            radius: 50,
            backgroundImage:
                _avatarPath != null ? FileImage(File(_avatarPath!)) : null,
            child: _avatarPath == null
                ? const Icon(Icons.person, size: 50, color: Colors.white)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child:
                  const Icon(Icons.camera_alt, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfileDialog(BuildContext context) async {
    if (user == null) return;
    final s = S.of(context);
    final nameController = TextEditingController(text: user!.name);
    final usernameController = TextEditingController(text: user!.username);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(s.get('edit_profile') ?? 'Chỉnh sửa hồ sơ'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: s.get('name') ?? 'Tên hiển thị',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return s.get('please_enter_name') ?? 'Vui lòng nhập tên';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: s.get('username') ?? 'Tên đăng nhập',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return s.get('please_enter_username') ?? 'Vui lòng nhập tên đăng nhập';
                    }
                    if (value.contains(' ')) {
                      return s.get('username_no_spaces') ?? 'Tên đăng nhập không được có khoảng trắng';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.get('cancel') ?? 'Hủy'),
            ),
            TextButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newName = nameController.text.trim();
                  final newUsername = usernameController.text.trim();
                  
                  final error = await context.read<StorageStageProxy>().updateProfile(
                    oldUsername: user!.username!,
                    newUsername: newUsername,
                    newName: newName,
                  );
                  
                  if (error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(error),
                      backgroundColor: Colors.red,
                    ));
                  } else {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(s.get('profile_updated') ?? 'Đã cập nhật hồ sơ'),
                      backgroundColor: Colors.green,
                    ));
                  }
                }
              },
              child: Text(s.get('save') ?? 'Lưu'),
            ),
          ],
        );
      },
    );
  }

  _removeAllData(BuildContext context, [String? username]) async {
    final s = S.of(context);
    
    // Check PIN first
    if (username != null) {
      final proxy = context.read<StorageStageProxy>();
      final hasPin = await proxy.hasPin(username);
      if (hasPin) {
        final pin = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PinDialog(title: s.get('enter_pin') ?? "Nhập mã PIN"))
        );
        if (pin == null) return; // User cancelled
        
        final isValid = await proxy.verifyPin(username, pin);
        if (!isValid) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(s.get('incorrect_pin') ?? "Mã PIN không chính xác"), 
            backgroundColor: Colors.red
          ));
          return;
        }
      } else {
        final wantToCreate = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.get('pin_required_title') ?? "Yêu cầu mã PIN"),
            content: Text(s.get('pin_required_desc') ?? "Bạn cần phải tạo mã PIN để thực hiện hành động này. Bạn có muốn tạo bây giờ không?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.get('cancel') ?? "Huỷ"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(s.get('create_pin_now') ?? "Tạo mã PIN ngay", style: const TextStyle(color: Colors.blue)),
              ),
            ],
          )
        );

        if (wantToCreate == true) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileSecurity())
          );
        }
        return;
      }
    }

    showAlertDialog(
      context: context,
      title:
          Text(s.get('delete_all_confirm') ?? "Xác nhận xoá toàn bộ dữ liệu?"),
      optionItems: [
        AlertDiaLogItem(
          text: s.get('delete') ?? "Xoá",
          textStyle:
              const TextStyle(color: Colors.red, fontWeight: FontWeight.normal),
          okOnPressed: () {
            var transactions = context.read<TransactionModelProxy>();
            var budgetProxy = context.read<BudgetModelProxy>();
            var groups = context.read<GroupModelProxy>();
            var wallets = context.read<WalletModelProxy>();
            var loans = context.read<LoanProvider>();
            var reminders = context.read<ReminderProvider>();
            var notifications = context.read<AppNotificationProvider>();

            transactions.deleteAll();
            budgetProxy.deleteAll();
            groups.deleteAll();
            wallets.deleteAll();
            loans.deleteAll();
            reminders.deleteAll();
            notifications.deleteAll();

            SnackBar snackBar = SnackBar(
              content:
                  Text(s.get('delete_all_data') ?? "Đã xoá toàn bộ dữ liệu"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            );
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
          },
        ),
      ],
      cancelItem: AlertDiaLogItem(
        text: s.get('cancel') ?? "Huỷ",
        textStyle:
            const TextStyle(color: Colors.blue, fontWeight: FontWeight.normal),
        okOnPressed: () {},
      ),
    );
  }

  void _signOut(BuildContext context) {
    context.read<StorageStageProxy>().logoutUser();
    Navigator.of(context, rootNavigator: true).popAndPushNamed("/login");
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final currencyProvider = context.watch<CurrencyProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    final s = S.of(context);
    islogin = context.watch<StorageStageProxy>().isLogin;
    final currentUser = context.watch<StorageStageProxy>().getCurrentUser();
    if (currentUser != null) {
      user = Account.fromString(jsonEncode(currentUser));
    } else {
      user = null;
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          s.get('options') ?? "Tuỳ chọn",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0.0,
      ),
      body: (islogin && user != null)
          ? ListView(
              children: [
                Center(
                  child: Column(children: [
                    const SizedBox(
                      height: 20,
                    ),
                    _buildAvatar(),
                    const SizedBox(
                      height: 20,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 48), // Balance icon button
                        Column(
                          children: [
                            Text(
                              user!.name,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              user!.email,
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            if (user!.username != null)
                              Text(
                                '@${user!.username}',
                                style:
                                    const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                          onPressed: () => _showEditProfileDialog(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${user!.id}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                  ]),
                ),
                Container(
                  color: Theme.of(context).cardColor,
                  child: Column(
                    children: [
                      Divider(
                        color: Theme.of(context).dividerColor,
                        height: 0.5,
                      ),
                      ListTile(
                        leading: const Icon(Icons.contact_support,
                            color: Colors.grey),
                        title: Text(s.get('support') ?? "Hỗ trợ"),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          Navigator.pushNamed(context, '/profile_support');
                        },
                      ),
                      Divider(
                        color: Theme.of(context).dividerColor,
                        height: 0.5,
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.dark_mode_outlined,
                            color: Colors.grey),
                        title: Text(s.get('dark_mode') ?? "Chế độ tối"),
                        value: themeProvider.isDarkMode,
                        onChanged: (value) {
                          themeProvider.toggleTheme(value);
                        },
                      ),
                      Divider(
                        color: Theme.of(context).dividerColor,
                        height: 0.5,
                      ),
                      ListTile(
                        leading:
                            const Icon(Icons.attach_money, color: Colors.grey),
                        title: Text(s.get('unit') ?? "Đơn vị tiền tệ"),
                        trailing: DropdownButton<String>(
                          value: currencyProvider.currency,
                          underline: const SizedBox(),
                          items: <String>['VND', 'USD'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              currencyProvider.toggleCurrency(newValue);
                            }
                          },
                        ),
                      ),
                      Divider(
                        color: Theme.of(context).dividerColor,
                        height: 0.5,
                      ),
                      ListTile(
                        leading: const Icon(Icons.language, color: Colors.grey),
                        title: Text(s.get('unit') == 'Đơn vị tiền tệ'
                            ? 'Ngôn ngữ'
                            : 'Language'),
                        trailing: DropdownButton<String>(
                          value: languageProvider.locale.languageCode,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(
                                value: 'vi', child: Text('Tiếng Việt')),
                            DropdownMenuItem(
                                value: 'en', child: Text('English')),
                          ],
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              languageProvider.toggleLanguage(newValue);
                            }
                          },
                        ),
                      ),
                      Divider(
                        color: Theme.of(context).dividerColor,
                        height: 0.5,
                      ),
                      ListTile(
                        leading: const Icon(Icons.notifications_active, color: Colors.grey),
                        title: Text(s.get('payment_reminders') ?? 'Nhắc nhở thanh toán'),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RemindersScreen())
                          );
                        },
                      ),
                      Divider(
                        color: Theme.of(context).dividerColor,
                        height: 0.5,
                      ),
                      ListTile(
                        leading: const Icon(Icons.security, color: Colors.grey),
                        title: Text(s.get('security') ?? 'Bảo mật'),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileSecurity())
                          );
                        },
                      ),
                      Divider(
                        color: Theme.of(context).dividerColor,
                        height: 0.5,
                      ),
                      ListTile(
                        leading:
                            const Icon(Icons.import_export, color: Colors.grey),
                        title: Text(
                            s.get('export_backup') ?? 'Xuất & Sao lưu dữ liệu'),
                        trailing: const Icon(Icons.arrow_forward_ios,
                            color: Colors.grey),
                        onTap: () async {
                          final proxy = context.read<StorageStageProxy>();
                          final hasPin = await proxy.hasPin(user!.username!);
                          if (hasPin) {
                            final pin = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PinDialog(title: s.get('enter_pin') ?? "Nhập mã PIN"))
                            );
                            if (pin == null) return;
                            
                            final isValid = await proxy.verifyPin(user!.username!, pin);
                            if (!isValid) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(s.get('incorrect_pin') ?? "Mã PIN không chính xác"), 
                                backgroundColor: Colors.red
                              ));
                              return;
                            }
                          } else {
                            final wantToCreate = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(s.get('pin_required_title') ?? "Yêu cầu mã PIN"),
                                content: Text(s.get('pin_required_desc') ?? "Bạn cần phải tạo mã PIN để thực hiện hành động này. Bạn có muốn tạo bây giờ không?"),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(s.get('cancel') ?? "Huỷ"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(s.get('create_pin_now') ?? "Tạo mã PIN ngay", style: const TextStyle(color: Colors.blue)),
                                  ),
                                ],
                              )
                            );

                            if (wantToCreate == true) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ProfileSecurity())
                              );
                            }
                            return;
                          }
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ExportBackupScreen()));
                        },
                      ),
                      Divider(
                        color: Theme.of(context).dividerColor,
                        height: 0.5,
                      ),
                      ListTile(
                        leading: const Icon(Icons.logout_outlined,
                            color: Colors.grey),
                        title: Text(s.get('logout') ?? "Đăng xuất"),
                        onTap: () async {
                          _signOut(context);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text("${s.get('version') ?? 'Phiên bản'} 1.0.1", style: const TextStyle(color: Colors.grey, fontSize: 13.0)),
                ),
                const SizedBox(
                  height: 30,
                ),
                Container(
                  color: Theme.of(context).cardColor,
                  height: 45.0,
                  child: MyButton(
                      onTap: () {
                        if (user != null && user!.username != null) {
                          _removeAllData(context, user!.username!);
                        }
                      },
                      child: Center(
                          child: Text(
                              s.get('delete_all_data') ?? "Xoá toàn bộ dữ liệu",
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 16.0,
                              )))),
                ),
                const SizedBox(
                  height: 50,
                ),
              ],
            )
          : ListView(
              children: [
                Center(
                  child: Column(children: [
                    const SizedBox(
                      height: 20,
                    ),
                    _buildAvatar(),
                    SizedBox(
                      height: 20,
                    ),
                    Center(
                      child: Text(
                          s.get('login_prompt') ??
                              "Hãy đăng nhập để quản lý tài khoản của bạn",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15,
                              color: Colors.grey,
                              fontWeight: FontWeight.normal)),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                  ]),
                ),
                Container(
                  color: Theme.of(context).cardColor,
                  child: Column(
                    children: [
                      Divider(
                        color: Theme.of(context).dividerColor,
                        height: 0.5,
                      ),
                      ListTile(
                        leading: const Icon(Icons.contact_support,
                            color: Colors.grey),
                        title: Text(s.get('support') ?? "Hỗ trợ"),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          Navigator.pushNamed(context, '/profile_support');
                        },
                      ),
                      Divider(
                        color: Theme.of(context).dividerColor,
                        height: 0.5,
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.dark_mode_outlined,
                            color: Colors.grey),
                        title: Text(s.get('dark_mode') ?? "Chế độ tối"),
                        value: themeProvider.isDarkMode,
                        onChanged: (value) {
                          themeProvider.toggleTheme(value);
                        },
                      ),
                      Divider(
                        color: Theme.of(context).dividerColor,
                        height: 0.5,
                      ),
                      ListTile(
                        leading:
                            const Icon(Icons.attach_money, color: Colors.grey),
                        title: Text(s.get('unit') ?? "Đơn vị tiền tệ"),
                        trailing: DropdownButton<String>(
                          value: currencyProvider.currency,
                          underline: const SizedBox(),
                          items: <String>['VND', 'USD'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              currencyProvider.toggleCurrency(newValue);
                            }
                          },
                        ),
                      ),
                      Divider(
                        color: Theme.of(context).dividerColor,
                        height: 0.5,
                      ),
                      ListTile(
                        leading: const Icon(Icons.language, color: Colors.grey),
                        title: Text(s.get('unit') == 'Đơn vị tiền tệ'
                            ? 'Ngôn ngữ'
                            : 'Language'),
                        trailing: DropdownButton<String>(
                          value: languageProvider.locale.languageCode,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(
                                value: 'vi', child: Text('Tiếng Việt')),
                            DropdownMenuItem(
                                value: 'en', child: Text('English')),
                          ],
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              languageProvider.toggleLanguage(newValue);
                            }
                          },
                        ),
                      ),
                      Divider(
                        color: Theme.of(context).dividerColor,
                        height: 0.5,
                      ),
                      ListTile(
                        leading:
                            const Icon(Icons.import_export, color: Colors.grey),
                        title: Text(
                            s.get('export_backup') ?? 'Xuất & Sao lưu dữ liệu'),
                        trailing: const Icon(Icons.arrow_forward_ios,
                            color: Colors.grey),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ExportBackupScreen()));
                        },
                      ),
                      Divider(
                        color: Theme.of(context).dividerColor,
                        height: 0.5,
                      ),
                      ListTile(
                        leading: const Icon(Icons.login_outlined,
                            color: Colors.grey),
                        title: Text(s.get('login') ?? "Đăng nhập"),
                        onTap: () {
                          Navigator.of(context, rootNavigator: true)
                              .popAndPushNamed("/login");
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text("${s.get('version') ?? 'Phiên bản'} 1.0.1", style: const TextStyle(color: Colors.grey, fontSize: 13.0)),
                ),
                const SizedBox(
                  height: 30,
                ),
                Container(
                  color: Theme.of(context).cardColor,
                  height: 45.0,
                  child: MyButton(
                      onTap: () {
                        _removeAllData(context);
                      },
                      child: Center(
                          child: Text(
                              s.get('delete_all_data') ?? "Xoá toàn bộ dữ liệu",
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 16.0,
                              )))),
                ),
                const SizedBox(
                  height: 50,
                ),
              ],
            ),
    );
  }
}
