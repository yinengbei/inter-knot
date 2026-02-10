import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/api/api_exception.dart';
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
  final confirmPasswordController = TextEditingController();
  final usernameController = TextEditingController();

  bool isRegister = false;
  bool isLoading = false;
  String? error;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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
      final confirmPassword = confirmPasswordController.text.trim();
      final username = usernameController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw Exception('请输入邮箱和密码');
      }
      if (isRegister) {
        if (username.isEmpty) {
          throw Exception('请输入用户名');
        }
        if (password != confirmPassword) {
          throw Exception('两次输入的密码不一致');
        }
      }

      final res = isRegister
          ? await BaseConnect.authApi.register(username, email, password)
          : await BaseConnect.authApi.login(email, password);

      if (res.token != null) {
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
      } else {
        Get.back();
        Get.rawSnackbar(message: '注册成功：请查收邮件并激活账号');
      }
    } catch (e, s) {
      logger.e('Login failed', error: e, stackTrace: s);
      setState(() {
        if (e is ApiException) {
          if (!isRegister && e.statusCode == 400) {
            if (e.message.contains('not confirmed')) {
              error = '请先激活绳网账号';
            } else {
              error = '邮箱或密码错误';
            }
          } else {
            var msg = e.message;
            if (msg == 'email must be a valid email') {
              msg = '邮箱格式不正确';
            } else if (msg.contains('already taken')) {
              msg = '用户名或邮箱已被占用';
            }
            error = msg;
          }
        } else {
          // 处理其他类型的错误，包括 TypeError
          final errorString = e.toString();
          if (errorString.contains('TypeError') ||
              errorString.contains('Null')) {
            error = '应用状态异常，请尝试重新启动应用';
          } else {
            error = errorString.replaceAll('Exception: ', '');
          }
        }
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
    // Shared ZZZ style input decoration
    final inputDecoration = InputDecoration(
      labelStyle: const TextStyle(color: Color(0xff808080)),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xff333333)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xffD7FF00)),
      ),
      border: const OutlineInputBorder(),
      prefixIconColor: const Color(0xffE0E0E0),
    );

    // Using Scaffold with backgroundColor transparent to act as a dialog content
    return GestureDetector(
      onTap: () => Get.back(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent tap from closing when clicking on the card
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(59, 255, 255, 255),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xff1A1A1A), // Dark card background
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves
                            .elasticOut, // Use elasticOut for ZZZ style bounciness
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              switchInCurve: Curves
                                  .easeOutBack, // Add bounce to text entry
                              switchOutCurve:
                                  Curves.easeInBack, // Add bounce to text exit
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(
                                          0, -0.5), // Increased slide distance
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ...previousChildren,
                                    if (currentChild != null) currentChild,
                                  ],
                                );
                              },
                              child: Text(
                                key: ValueKey(isRegister),
                                isRegister ? '注册' : '登录',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (error != null) ...[
                              Text(
                                error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              switchInCurve: Curves.easeOutQuart,
                              switchOutCurve: Curves.easeInQuart,
                              transitionBuilder: (child, animation) {
                                return SizeTransition(
                                  sizeFactor: animation,
                                  axis: Axis.vertical,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, -0.2),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  ),
                                );
                              },
                              child: isRegister
                                  ? Column(
                                      children: [
                                        // Add spacing to prevent label clipping by SizeTransition
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: usernameController,
                                          style: const TextStyle(
                                              color: Color(0xffE0E0E0)),
                                          decoration: inputDecoration.copyWith(
                                            labelText: '用户名',
                                            prefixIcon:
                                                const Icon(Icons.person),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            TextField(
                              controller: emailController,
                              style: const TextStyle(color: Color(0xffE0E0E0)),
                              decoration: inputDecoration.copyWith(
                                labelText: '邮箱',
                                prefixIcon: const Icon(Icons.email),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: passwordController,
                              style: const TextStyle(color: Color(0xffE0E0E0)),
                              decoration: inputDecoration.copyWith(
                                labelText: '密码',
                                prefixIcon: const Icon(Icons.lock),
                              ),
                              obscureText: true,
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              switchInCurve: Curves.easeOutQuart,
                              switchOutCurve: Curves.easeInQuart,
                              transitionBuilder: (child, animation) {
                                return SizeTransition(
                                  sizeFactor: animation,
                                  axis: Axis.vertical,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, -0.2),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  ),
                                );
                              },
                              child: isRegister
                                  ? Column(
                                      children: [
                                        const SizedBox(height: 16),
                                        TextField(
                                          controller: confirmPasswordController,
                                          style: const TextStyle(
                                              color: Color(0xffE0E0E0)),
                                          decoration: inputDecoration.copyWith(
                                            labelText: '确认密码',
                                            prefixIcon:
                                                const Icon(Icons.lock_outline),
                                          ),
                                          obscureText: true,
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                style: ButtonStyle(
                                  backgroundColor: const WidgetStatePropertyAll(
                                      Color(0xffD7FF00)),
                                  foregroundColor: const WidgetStatePropertyAll(
                                      Colors.black),
                                  overlayColor: WidgetStatePropertyAll(
                                      Colors.white.withValues(alpha: 0.3)),
                                ),
                                onPressed: isLoading ? null : _submit,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : Text(
                                          key: ValueKey(isRegister),
                                          isRegister ? '注册' : '登录',
                                        ),
                                ),
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
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                                child: Text(
                                  key: ValueKey(isRegister),
                                  isRegister ? '登录' : '注册账号',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
