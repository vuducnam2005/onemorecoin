import 'package:flutter/material.dart';
import 'package:onemorecoin/model/StorageStage.dart';
import 'package:onemorecoin/utils/app_localizations.dart';
import 'package:onemorecoin/widgets/PinDialog.dart';
import 'package:provider/provider.dart';

class ProfileSecurity extends StatefulWidget {
  const ProfileSecurity({super.key});

  @override
  State<ProfileSecurity> createState() => _ProfileSecurityState();
}

class _ProfileSecurityState extends State<ProfileSecurity> {
  String? _linkedPhone;
  bool _hasPin = false;
  String _username = "";

  @override
  void initState() {
    super.initState();
    _loadSecurityInfo();
  }

  Future<void> _loadSecurityInfo() async {
    final proxy = context.read<StorageStageProxy>();
    final user = proxy.getCurrentUser();
    if (user != null) {
      _username = user['username'];
      final phone = await proxy.getPhone(_username);
      final hasPin = await proxy.hasPin(_username);
      setState(() {
        _linkedPhone = phone;
        _hasPin = hasPin;
      });
    }
  }

  void _onLinkPhone() {
    final s = S.of(context);
    final _phoneController = TextEditingController(text: _linkedPhone);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(s.get('link_phone') ?? "Liên kết số điện thoại"),
          content: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: s.get('phone_number') ?? "Số điện thoại",
            ),
          ),
          actions: [
            if (_linkedPhone != null)
              TextButton(
                onPressed: () async {
                  await context.read<StorageStageProxy>().savePhone(_username, "");
                  setState(() {
                    _linkedPhone = null;
                  });
                  Navigator.pop(context);
                },
                child: Text(s.get('remove_phone') ?? "Xoá", style: const TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.get('cancel') ?? "Huỷ"),
            ),
            TextButton(
              onPressed: () async {
                if (_phoneController.text.isNotEmpty) {
                  await context.read<StorageStageProxy>().savePhone(_username, _phoneController.text.trim());
                  setState(() {
                    _linkedPhone = _phoneController.text.trim();
                  });
                }
                Navigator.pop(context);
              },
              child: Text(s.get('save') ?? "Lưu"),
            ),
          ],
        );
      },
    );
  }

  void _onChangePin() async {
    final proxy = context.read<StorageStageProxy>();
    final s = S.of(context);

    if (_hasPin) {
      // Must verify old pin first or ask what they want to do
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.get('pin_code') ?? "Mã PIN"),
          content: Text(s.get('change_pin_code') ?? "Bạn muốn đổi mã PIN hay xoá mã PIN?"),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                // Verify old pin to remove
                final verifyOld = await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PinDialog(title: s.get('enter_pin') ?? "Nhập mã PIN hiện tại")
                ));
                if (verifyOld != null) {
                  final isValid = await proxy.verifyPin(_username, verifyOld);
                  if (isValid) {
                    await proxy.removePin(_username);
                    setState(() { _hasPin = false; });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.get('pin_removed') ?? "Đã xoá mã PIN"), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.get('incorrect_pin') ?? "Mã PIN không chính xác"), backgroundColor: Colors.red));
                  }
                }
              },
              child: Text(s.get('remove_pin') ?? "Xoá mã PIN", style: const TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final verifyOld = await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PinDialog(title: s.get('enter_pin') ?? "Nhập mã PIN hiện tại")
                ));
                if (verifyOld != null) {
                  final isValid = await proxy.verifyPin(_username, verifyOld);
                  if (isValid) {
                    final newPin = await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => PinDialog(title: s.get('new_password') ?? "Mã PIN mới")
                    ));
                    if (newPin != null) {
                      await proxy.savePin(_username, newPin);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.get('pin_changed') ?? "Đổi mã PIN thành công"), backgroundColor: Colors.green));
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.get('incorrect_pin') ?? "Mã PIN không chính xác"), backgroundColor: Colors.red));
                  }
                }
              },
              child: Text(s.get('change_pin_code') ?? "Đổi mã PIN", style: const TextStyle(color: Colors.blue)),
            ),
          ],
        )
      );
    } else {
      // create pin
      final newPin = await Navigator.push(context, MaterialPageRoute(
        builder: (_) => PinDialog(title: s.get('create_pin_code') ?? "Tạo mã PIN")
      ));
      if (newPin != null) {
        await proxy.savePin(_username, newPin);
        setState(() { _hasPin = true; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.get('pin_created') ?? "Tạo mã PIN thành công"), backgroundColor: Colors.green));
      }
    }
  }

  void _onChangePassword() async {
    final s = S.of(context);
    final proxy = context.read<StorageStageProxy>();

    if (!_hasPin) {
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
        // Just call _onChangePin to trigger creation flow since _hasPin is false
        _onChangePin();
      }
      return;
    }

    final pin = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PinDialog(title: s.get('enter_pin') ?? "Nhập mã PIN"))
    );
    if (pin == null) return;
    
    final isValid = await proxy.verifyPin(_username, pin);
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.get('incorrect_pin') ?? "Mã PIN không chính xác"), 
        backgroundColor: Colors.red
      ));
      return;
    }

    final _oldPasswordController = TextEditingController();
    final _newPasswordController = TextEditingController();
    final _confirmPasswordController = TextEditingController();
    final _formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool _obscureOldText = true;
    bool _obscureNewText = true;
    bool _obscureConfirmText = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.get('change_password') ?? "Thay đổi mật khẩu",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _oldPasswordController,
                      obscureText: _obscureOldText,
                      decoration: InputDecoration(
                        labelText: s.get('old_password') ?? "Mật khẩu cũ",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureOldText ? Icons.visibility : Icons.visibility_off),
                          onPressed: () {
                            setModalState(() {
                              _obscureOldText = !_obscureOldText;
                            });
                          },
                        ),
                      ),
                      validator: (value) => value!.isEmpty ? s.get('please_enter_password') ?? "Vui lòng nhập mật khẩu" : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNewText,
                      decoration: InputDecoration(
                        labelText: s.get('new_password') ?? "Mật khẩu mới",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNewText ? Icons.visibility : Icons.visibility_off),
                          onPressed: () {
                            setModalState(() {
                              _obscureNewText = !_obscureNewText;
                            });
                          },
                        ),
                      ),
                      validator: (value) => (value == null || value.length < 6) ? s.get('password_min_length') ?? "Mật khẩu ít nhất 6 ký tự" : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmText,
                      decoration: InputDecoration(
                        labelText: s.get('confirm_password') ?? "Xác nhận mật khẩu",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmText ? Icons.visibility : Icons.visibility_off),
                          onPressed: () {
                            setModalState(() {
                              _obscureConfirmText = !_obscureConfirmText;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value != _newPasswordController.text) {
                          return s.get('password_not_match') ?? "Mật khẩu xác nhận không khớp";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () async {
                          if (_formKey.currentState!.validate()) {
                            setModalState(() => isLoading = true);
                            final err = await context.read<StorageStageProxy>().changePassword(
                              username: _username,
                              oldPassword: _oldPasswordController.text,
                              newPassword: _newPasswordController.text,
                            );
                            setModalState(() => isLoading = false);
                            
                            if (err != null) {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Lỗi"),
                                  content: Text(err),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text("Đóng"),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              Navigator.pop(context); // Close bottom sheet
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Thành công"),
                                  content: Text(s.get('password_changed') ?? "Đổi mật khẩu thành công"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text("Đóng"),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                        child: isLoading
                            ? const CircularProgressIndicator()
                            : Text(s.get('save') ?? "Lưu", style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(s.get('security') ?? "Bảo mật", style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        margin: const EdgeInsets.only(top: 20),
        color: Theme.of(context).cardColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone_android, color: Colors.grey),
              title: Text(s.get('link_phone') ?? "Liên kết số điện thoại"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_linkedPhone != null && _linkedPhone!.isNotEmpty)
                    Text(_linkedPhone!, style: const TextStyle(color: Colors.grey)),
                  if (_linkedPhone != null && _linkedPhone!.isNotEmpty)
                    const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                ],
              ),
              onTap: _onLinkPhone,
            ),
            Divider(color: Theme.of(context).dividerColor, height: 0.5),
            ListTile(
              leading: const Icon(Icons.lock_outline, color: Colors.grey),
              title: Text(_hasPin ? (s.get('change_pin_code') ?? "Đổi mã PIN") : (s.get('create_pin_code') ?? "Tạo mã PIN")),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
              onTap: _onChangePin,
            ),
            Divider(color: Theme.of(context).dividerColor, height: 0.5),
            ListTile(
              leading: const Icon(Icons.password_outlined, color: Colors.grey),
              title: Text(s.get('change_password') ?? "Thay đổi mật khẩu"),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
              onTap: _onChangePassword,
            ),
          ],
        ),
      ),
    );
  }
}
