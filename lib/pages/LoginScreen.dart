import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:onemorecoin/model/StorageStage.dart';
import 'package:provider/provider.dart';
import 'package:onemorecoin/utils/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    final storageStage = context.read<StorageStageProxy>();
    final error = await storageStage.loginUser(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (error != null) {
      setState(() {
        _errorMessage = error;
      });
    } else {
      setState(() {
        _errorMessage = null;
      });
      if (mounted) {
        Navigator.pushReplacementNamed(context, "/home");
      }
    }
  }

  void _skipLogin() {
    final storageStage = context.read<StorageStageProxy>();
    storageStage.isLogin = true;
    Navigator.pushReplacementNamed(context, "/home");
  }

  void _goToRegister() {
    Navigator.pushNamed(context, "/register");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Logo / Image
              SizedBox(
                height: 180,
                child: Image.asset(
                  'assets/images/home.jpg',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  S.of(context).get('welcome_back') ?? 'Chào mừng trở lại!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  S.of(context).get('login_to_manage') ?? 'Đăng nhập để quản lý chi tiêu của bạn',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.red.shade900.withOpacity(0.3)
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade300, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade300, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

              // Login Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Username / Email
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: S.of(context).get('username_or_email') ?? 'Tên đăng nhập hoặc Email',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade800
                            : Colors.grey.shade50,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return S.of(context).get('please_enter_username_or_email') ?? 'Vui lòng nhập tên đăng nhập hoặc email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: S.of(context).get('password') ?? 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade800
                            : Colors.grey.shade50,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return S.of(context).get('please_enter_password') ?? 'Vui lòng nhập mật khẩu';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          S.of(context).get('login') ?? 'Đăng nhập',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Skip Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _skipLogin,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          S.of(context).get('skip_login') ?? 'Bỏ qua đăng nhập',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          S.of(context).get('no_account') ?? 'Chưa có tài khoản? ',
                          style: const TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                        GestureDetector(
                          onTap: _goToRegister,
                          child: Text(
                            S.of(context).get('register_now') ?? 'Đăng ký ngay',
                            style: TextStyle(
                              color: Colors.yellow.shade800,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Account {
  final String id;
  final String name;
  final String email;
  final String? username;

  Account({
    required this.id,
    required this.name,
    required this.email,
    this.username,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      username: json['username'],
    );
  }

  factory Account.fromString(String data) {
    var json = jsonDecode(data);
    return Account(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      username: json['username'],
    );
  }

  @override
  String toString() {
    return jsonEncode({
      'id': id,
      'name': name,
      'email': email,
      'username': username,
    });
  }
}