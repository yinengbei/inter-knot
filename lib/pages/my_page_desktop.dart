import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/api/api_exception.dart';
import 'package:inter_knot/constants/api_config.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/discussions_grid.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/profile_dialogs.dart';
import 'package:inter_knot/helpers/throttle.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/models/captcha.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/services/captcha_service.dart';
import 'package:intl/intl.dart';

class MyPageDesktop extends StatefulWidget {
  const MyPageDesktop({super.key});

  @override
  State<MyPageDesktop> createState() => _MyPageDesktopState();
}

class _MyPageDesktopState extends State<MyPageDesktop>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              // 1. Header Box
              _buildHeaderCard(context),
              const SizedBox(height: 24),
              // 2. Main Content
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Box (Large) - Tabs & Content
                    Expanded(
                      flex: 3,
                      child: _buildLeftContentBox(context),
                    ),
                    const SizedBox(width: 24),
                    // Right Box (Small) - Placeholder
                    Expanded(
                      flex: 1,
                      child: _buildRightPlaceholderBox(context),
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

  Widget _buildHeaderCard(BuildContext context) {
    return Card(
      color: const Color(0xff1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.1),
          width: 2,
        ),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Obx(() {
          final user = c.user.value;
          final isLogin = c.isLogin.value;
          c.nextEligibleAtUtc.value;
          final dateFormat = DateFormat('yyyy-MM-dd');
          final regTime = user?.createdAt != null
              ? dateFormat.format(user!.createdAt!)
              : '未知';

          return Row(
            children: [
              // Avatar
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context)
                            .primaryColor
                            .withValues(alpha: 0.5),
                        width: 4,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Avatar(
                        user?.avatar,
                        size: 100,
                      ),
                    ),
                  ),
                  if (c.isUploadingAvatar.value)
                    const Positioned.fill(
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              const SizedBox(width: 24),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user?.name ?? '绳网用户',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isLogin)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'UID: ${user?.userId ?? "未知"}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[400],
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '注册时间: $regTime',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: c.ensureLogin,
                        icon: const Icon(Icons.login),
                        label: const Text('立即登录'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffD7FF00),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              // Account Actions (Logout)
              if (isLogin)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => showEditProfileDialog(context),
                      icon: const Icon(Icons.edit, color: Colors.grey),
                      label: const Text('编辑资料',
                          style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => showLogoutDialog(context),
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('退出登录',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildLeftContentBox(BuildContext context) {
    return Card(
      color: const Color(0xff1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _buildCustomTabBar(context),
          ),
          const Divider(height: 1, color: Color(0xff333333)),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MyDiscussionsTab(),
                _MyFavoritesTab(),
                Obx(() => DiscussionGrid(
                      list: c.history(),
                      hasNextPage: false,
                      reorderHistoryOnOpen: false,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPlaceholderBox(BuildContext context) {
    final api = Get.find<Api>();
    return Card(
      color: const Color(0xff1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Obx(() {
          final user = c.user.value;
          final isLogin = c.isLogin.value;

          if (!isLogin || user == null) {
            return const Center(
              child: Text(
                '登录后查看更多功能',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          const levelTable = [
            (level: 6, exp: 3200, title: '传奇绳匠'),
            (level: 5, exp: 1600, title: '精英绳匠'),
            (level: 4, exp: 800, title: '资深绳匠'),
            (level: 3, exp: 400, title: '正式绳匠'),
            (level: 2, exp: 200, title: '见习绳匠'),
            (level: 1, exp: 0, title: '新手绳匠'),
          ];

          final currentLevel = user.level ?? 1;
          final currentExp = user.exp ?? 0;

          final currentConfig = levelTable.firstWhere(
              (e) => e.level == currentLevel,
              orElse: () => levelTable.last);

          final nextConfig = levelTable
              .cast<({int level, int exp, String title})?>()
              .firstWhere(
                (e) => e != null && e.level == currentLevel + 1,
                orElse: () => null,
              );

          double progress = 0.0;
          int nextExpTarget = currentExp;

          if (nextConfig != null) {
            final levelExp = currentConfig.exp;
            final nextExp = nextConfig.exp;
            nextExpTarget = nextExp;
            if (nextExp > levelExp) {
              progress = (currentExp - levelExp) / (nextExp - levelExp);
            }
            progress = progress.clamp(0.0, 1.0);
          } else {
            progress = 1.0;
            nextExpTarget = currentExp;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('绳网等级',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(width: 8),
                  Tooltip(
                    message:
                        '每日签到 ：\n- 基础经验： 10 XP\n- 连签奖励：每天额外 +2 XP\n- 每日上限： 50 XP (基础 + 奖励)\n发布文章 ：\n- 每次发布： 12 XP\n发表评论 ：\n- 每次评论： 3 XP',
                    child: Icon(
                      Icons.help_outline,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Lv.$currentLevel ${currentConfig.title}',
                      style: const TextStyle(
                          color: Color(0xffD7FF00),
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text('$currentExp / $nextExpTarget',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[800],
                color: const Color(0xffD7FF00),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: user.canCheckIn
                    ? ElevatedButton(
                        onPressed: () async {
                          try {
                            final captcha = await Get.find<CaptchaService>()
                                .verifyIfNeeded(CaptchaScene.checkIn);
                            final result = await api.checkIn(captcha: captcha);
                            await c.refreshMyExp();
                            if (context.mounted) {
                              final rank = result.rank;
                              final reward = result.reward;
                              final days = result.consecutiveDays;
                              showToast(
                                '今日签到第${rank ?? "?"}名，经验+${reward ?? 0}，连续签到${days ?? "?"}天',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              String msg = e.toString();
                              if (e is ApiException) {
                                msg = CaptchaService.resolveErrorMessageFromException(e) ??
                                    e.message;
                                if (e.statusCode == 409) {
                                  final details = e.details;
                                  String? checkInDay;
                                  if (details is Map) {
                                    checkInDay =
                                        details['checkInDay']?.toString();
                                    checkInDay = (checkInDay != null &&
                                            checkInDay.isNotEmpty)
                                        ? checkInDay
                                        : null;

                                    checkInDay ??=
                                        details['checkInDay'.toString()]
                                            ?.toString();

                                    final nextEligibleAt =
                                        details['nextEligibleAt']?.toString();
                                    if (nextEligibleAt != null &&
                                        nextEligibleAt.isNotEmpty) {
                                      final dt =
                                          DateTime.tryParse(nextEligibleAt);
                                      if (dt != null) {
                                        c.nextEligibleAtUtc.value = dt.toUtc();
                                      }
                                    }
                                    if (checkInDay == null &&
                                        nextEligibleAt != null &&
                                        nextEligibleAt.isNotEmpty) {
                                      final dt =
                                          DateTime.tryParse(nextEligibleAt);
                                      if (dt != null) {
                                        final utc = dt
                                            .toUtc()
                                            .subtract(const Duration(days: 1));
                                        final y = utc.year
                                            .toString()
                                            .padLeft(4, '0');
                                        final m = utc.month
                                            .toString()
                                            .padLeft(2, '0');
                                        final d = utc.day
                                            .toString()
                                            .padLeft(2, '0');
                                        checkInDay = '$y-$m-$d';
                                      }
                                    }
                                  }
                                  if (checkInDay != null &&
                                      checkInDay.isNotEmpty) {
                                    c.user.value?.lastCheckInDate = checkInDay;
                                    c.user.refresh();
                                  }
                                  await c.refreshMyExp();
                                }
                              }
                              showToast(
                                msg,
                                isError: true,
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffD7FF00),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        child: const Text('每日签到'),
                      )
                    : OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('今日已签到',
                            style: TextStyle(color: Colors.grey)),
                      ),
              )
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCustomTabBar(BuildContext context) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        final selectedIndex = _tabController.index;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTabItem(context, '我的帖子', 0, selectedIndex == 0),
              _buildTabItem(context, '我的收藏', 1, selectedIndex == 1),
              _buildTabItem(context, '浏览历史', 2, selectedIndex == 2),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabItem(
      BuildContext context, String text, int index, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            _tabController.animateTo(index);
          },
          child: SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xffD7FF00),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MyDiscussionsTab extends StatefulWidget {
  @override
  State<_MyDiscussionsTab> createState() => _MyDiscussionsTabState();
}

class _MyDiscussionsTabState extends State<_MyDiscussionsTab> {
  final api = Get.find<Api>();
  final discussions = <HDataModel>{}.obs;
  final hasNextPage = true.obs;
  String? endCursor;
  bool isLoading = false;
  late final Worker _loginWorker;

  late final fetchData = retryThrottle(
    _loadMore,
    const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    _loadMore();
    _loginWorker = ever(c.isLogin, (v) {
      if (v == true) {
        _refresh();
      } else {
        discussions.clear();
        endCursor = null;
        hasNextPage.value = true;
      }
    });
  }

  Future<void> _loadMore() async {
    if (isLoading || !hasNextPage.value) return;

    final authorId = c.authorId.value ?? c.user.value?.authorId;
    if (authorId == null || authorId.isEmpty) {
      await c.refreshSelfUserInfo();
      if (c.authorId.value == null && c.user.value?.authorId == null) {
        hasNextPage.value = false;
        return;
      }
    }

    isLoading = true;
    try {
      final res = await api.getUserDiscussions(
        c.authorId.value ?? c.user.value!.authorId!,
        endCursor ?? '',
      );

      if (res.nodes.isNotEmpty) {
        discussions.addAll(res.nodes);
        endCursor = res.endCursor;
        hasNextPage.value = res.hasNextPage;
      } else {
        hasNextPage.value = false;
      }
    } catch (e) {
      // Quiet fail or log
    } finally {
      isLoading = false;
    }
  }

  Future<void> _refresh() async {
    discussions.clear();
    endCursor = null;
    hasNextPage.value = true;
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Show login prompt if not logged in
      if (!c.isLogin.value) {
        return const Center(
          child: DiscussionEmptyState(
            message: '请登录后查看',
            textStyle: TextStyle(
              color: Color(0xff808080),
              fontSize: 16,
            ),
          ),
        );
      }
      
      return DiscussionGrid(
        list: discussions(),
        hasNextPage: hasNextPage(),
        fetchData: fetchData,
      );
    });
  }

  @override
  void dispose() {
    _loginWorker.dispose();
    super.dispose();
  }
}

class _MyFavoritesTab extends StatefulWidget {
  @override
  State<_MyFavoritesTab> createState() => _MyFavoritesTabState();
}

class _MyFavoritesTabState extends State<_MyFavoritesTab> {
  final api = Get.find<Api>();
  final discussions = <HDataModel>{}.obs;
  final hasNextPage = true.obs;
  String? endCursor;
  bool isLoading = false;
  late final Worker _loginWorker;

  late final fetchData = retryThrottle(
    _loadMore,
    const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    _loadMore();
    _loginWorker = ever(c.isLogin, (v) {
      if (v == true) {
        _refresh();
      } else {
        discussions.clear();
        endCursor = null;
        hasNextPage.value = true;
      }
    });
  }

  Future<void> _loadMore() async {
    if (isLoading || !hasNextPage.value) return;

    final authorId = c.authorId.value ?? c.user.value?.authorId;
    if (authorId == null || authorId.isEmpty) {
      await c.refreshSelfUserInfo();
      if (c.authorId.value == null && c.user.value?.authorId == null) {
        hasNextPage.value = false;
        return;
      }
    }

    isLoading = true;
    try {
      final res = await api.getFavorites(
        c.user.value!.login,
        endCursor ?? '',
      );

      if (res.items.isNotEmpty) {
        discussions.addAll(res.items);
        endCursor = (int.parse(endCursor ?? '0') + ApiConfig.defaultPageSize)
            .toString();
        hasNextPage.value = res.items.length >= ApiConfig.defaultPageSize;
      } else {
        hasNextPage.value = false;
      }
    } catch (e) {
      // Quiet fail or log
    } finally {
      isLoading = false;
    }
  }

  Future<void> _refresh() async {
    discussions.clear();
    endCursor = null;
    hasNextPage.value = true;
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Show login prompt if not logged in
      if (!c.isLogin.value) {
        return const Center(
          child: DiscussionEmptyState(
            message: '请登录后查看',
            textStyle: TextStyle(
              color: Color(0xff808080),
              fontSize: 16,
            ),
          ),
        );
      }
      
      return DiscussionGrid(
        list: discussions(),
        hasNextPage: hasNextPage(),
        fetchData: fetchData,
      );
    });
  }

  @override
  void dispose() {
    _loginWorker.dispose();
    super.dispose();
  }
}
