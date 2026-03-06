import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/api/api_exception.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/captcha.dart';
import 'package:inter_knot/services/captcha_service.dart';

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
  bool isWaitingForActivation = false;
  Timer? _activationTimer;
  String? error;

  @override
  void initState() {
    super.initState();
    // Check if we have pending activation credentials
    final pendingEmail = box.read<String>('pending_activation_email');
    final pendingPassword = box.read<String>('pending_activation_password');
    if (pendingEmail != null && pendingPassword != null) {
      emailController.text = pendingEmail;
      passwordController.text = pendingPassword;
      isRegister =
          true; // Stay on register-like screen to show activation status
      _startActivationCheck(pendingEmail, pendingPassword);
    }
  }

  @override
  void dispose() {
    _activationTimer?.cancel();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  Future<void> _onLoginSuccess(String token, AuthorModel user) async {
    // Clear pending activation credentials on success
    box.remove('pending_activation_email');
    box.remove('pending_activation_password');

    await box.write('access_token', token);

    // Update Controller state
    final c = Get.find<Controller>();
    AuthorModel currentUser = user;
    try {
      currentUser = await Get.find<Api>().getSelfUserInfo('');
    } catch (_) {}
    c.user(currentUser);
    await c.ensureAuthorForUser(currentUser);
    c.isLogin(true);
    
    // Refresh user data after login
    await c.refreshFavorites();
    await c.refreshUnreadNotificationCount();

    if (mounted) {
      Get.back();
      showToast('登录成功：欢迎回来，绳匠！');
    }
  }

  void _startActivationCheck(String email, String password) {
    setState(() {
      isWaitingForActivation = true;
      isLoading = false; // Stop form loading state
    });

    _activationTimer?.cancel();
    _activationTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final res = await BaseConnect.authApi.login(email, password);
        if (res.token != null) {
          timer.cancel();
          await _onLoginSuccess(res.token!, res.user);
        }
      } catch (e) {
        // Ignore errors while waiting (e.g. 400 not confirmed)
        // We just keep retrying until success or user cancel
      }
    });
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

      final captchaService = Get.find<CaptchaService>();
      final captcha = await captchaService.verifyIfNeeded(
        isRegister ? CaptchaScene.register : CaptchaScene.login,
      );

      final res = isRegister
          ? await BaseConnect.authApi.register(
              username,
              email,
              password,
              captcha: captcha,
            )
          : await BaseConnect.authApi.login(
              email,
              password,
              captcha: captcha,
            );

      if (res.token != null) {
        await _onLoginSuccess(res.token!, res.user);
      } else {
        if (isRegister) {
          // Save credentials for auto-activation check across restarts
          box.write('pending_activation_email', email);
          box.write('pending_activation_password', password);
          _startActivationCheck(email, password);
        } else {
          Get.back();
          showToast('登录失败：未获取到Token', isError: true);
        }
      }
    } catch (e, s) {
      logger.e('Login failed', error: e, stackTrace: s);
      setState(() {
        if (e is ApiException) {
          final captchaMessage =
              CaptchaService.resolveErrorMessageFromException(e);
          if (captchaMessage != null) {
            error = captchaMessage;
          } else if (!isRegister && e.statusCode == 400) {
            if (e.message.contains('not confirmed')) {
              error = '请先激活绳网账号';
            } else {
              error = '邮箱或密码错误';
            }
          } else {
            var msg = CaptchaService.resolveErrorMessageFromException(e) ?? e.message;
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
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 600;

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
                      constraints: BoxConstraints(
                        maxWidth:
                            isDesktop && isWaitingForActivation ? 600 : 400,
                      ),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves
                            .elasticOut, // Use elasticOut for ZZZ style bounciness
                        child: isWaitingForActivation
                            ? Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.mark_email_unread,
                                        size: 64, color: Color(0xffD7FF00)),
                                    const SizedBox(height: 16),
                                    const Text('注册成功',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    const Text('请前往邮箱激活账号',
                                        style: TextStyle(
                                            color: Color(0xffE0E0E0))),
                                    const SizedBox(height: 24),
                                    const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xffD7FF00))),
                                    const SizedBox(height: 8),
                                    const Text('正在等待激活...',
                                        style: TextStyle(
                                            color: Color(0xff808080),
                                            fontSize: 12)),
                                    const SizedBox(height: 24),
                                    TextButton(
                                      onPressed: () {
                                        _activationTimer?.cancel();
                                        // Clear pending credentials on cancel
                                        box.remove('pending_activation_email');
                                        box.remove(
                                            'pending_activation_password');
                                        setState(() {
                                          isWaitingForActivation = false;
                                        });
                                      },
                                      child: const Text('取消等待',
                                          style: TextStyle(color: Colors.grey)),
                                    )
                                  ],
                                ),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    switchInCurve: Curves
                                        .easeOutBack, // Add bounce to text entry
                                    switchOutCurve: Curves
                                        .easeInBack, // Add bounce to text exit
                                    transitionBuilder: (child, animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0,
                                                -0.5), // Increased slide distance
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      );
                                    },
                                    layoutBuilder:
                                        (currentChild, previousChildren) {
                                      return Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          ...previousChildren,
                                          if (currentChild != null)
                                            currentChild,
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
                                        color:
                                            Theme.of(context).colorScheme.error,
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
                                                decoration:
                                                    inputDecoration.copyWith(
                                                  labelText: '用户名',
                                                  prefixIcon:
                                                      const Icon(Icons.person),
                                                ),
                                                textInputAction: TextInputAction.next,
                                              ),
                                              const SizedBox(height: 16),
                                            ],
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  TextField(
                                    controller: emailController,
                                    style: const TextStyle(
                                        color: Color(0xffE0E0E0)),
                                    decoration: inputDecoration.copyWith(
                                      labelText: '邮箱',
                                      prefixIcon: const Icon(Icons.email),
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: passwordController,
                                    style: const TextStyle(
                                        color: Color(0xffE0E0E0)),
                                    decoration: inputDecoration.copyWith(
                                      labelText: '密码',
                                      prefixIcon: const Icon(Icons.lock),
                                    ),
                                    obscureText: true,
                                    textInputAction: isRegister ? TextInputAction.next : TextInputAction.done,
                                    onSubmitted: isRegister ? null : (_) => _submit(),
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
                                                controller:
                                                    confirmPasswordController,
                                                style: const TextStyle(
                                                    color: Color(0xffE0E0E0)),
                                                decoration:
                                                    inputDecoration.copyWith(
                                                  labelText: '确认密码',
                                                  prefixIcon: const Icon(
                                                      Icons.lock_outline),
                                                ),
                                                obscureText: true,
                                                textInputAction: TextInputAction.done,
                                                onSubmitted: (_) => _submit(),
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
                                        backgroundColor:
                                            const WidgetStatePropertyAll(
                                                Color(0xffD7FF00)),
                                        foregroundColor:
                                            const WidgetStatePropertyAll(
                                                Colors.black),
                                        overlayColor: WidgetStatePropertyAll(
                                            Colors.white
                                                .withValues(alpha: 0.3)),
                                      ),
                                      onPressed: isLoading ? null : _submit,
                                      child: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 300),
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
                                                child:
                                                    CircularProgressIndicator(
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
                                      overlayColor: WidgetStatePropertyAll(
                                          Colors.transparent),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        isRegister = !isRegister;
                                        error = null;
                                      });
                                    },
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 300),
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
