import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:inter_knot/models/author.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameController = TextEditingController();

  bool isRegister = false;
  bool isLoading = false;
  String? error;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      final username = usernameController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw Exception('请填写邮箱和密码');
      }
      if (isRegister && username.isEmpty) {
        throw Exception('请填写用户名');
      }

      final res = isRegister
          ? await BaseConnect.authApi.register(username, email, password)
          : await BaseConnect.authApi.login(email, password);

      await box.write('access_token', res.token);

      // Update Controller state
      final c = Get.find<Controller>();
      AuthorModel currentUser = res.user;
      try {
        currentUser = await Get.find<Api>().getSelfUserInfo('');
      } catch (_) {}
      c.user(currentUser);
      await c.ensureAuthorForUser(currentUser);
      c.isLogin(true);

      Get.back();
      Get.rawSnackbar(message: '登录成功：欢迎回来，绳匠！');
    } catch (e) {
      logger.e('Login failed', error: e);
      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isRegister ? '注册' : '登录')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error != null) ...[
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (isRegister) ...[
                      TextField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: '邮箱',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: '密码',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: const ButtonStyle(
                          overlayColor:
                              WidgetStatePropertyAll(Colors.transparent),
                        ),
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const CircularProgressIndicator()
                            : Text(isRegister ? '注册' : '登录'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      style: const ButtonStyle(
                        overlayColor:
                            WidgetStatePropertyAll(Colors.transparent),
                      ),
                      onPressed: () {
                        setState(() {
                          isRegister = !isRegister;
                          error = null;
                        });
                      },
                      child: Text(
                        isRegister ? '登录' : '注册账号',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
