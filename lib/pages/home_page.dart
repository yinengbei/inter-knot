import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/api/api_exception.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/dialog_helper.dart';
import 'package:inter_knot/helpers/profile_dialogs.dart';
import 'package:inter_knot/models/captcha.dart';
import 'package:inter_knot/pages/history_page.dart';
import 'package:inter_knot/pages/liked_page.dart';
import 'package:inter_knot/pages/my_discussions_page.dart';
import 'package:inter_knot/helpers/page_transition_helper.dart';
import 'package:inter_knot/components/update_dialog.dart';
import 'package:inter_knot/services/captcha_service.dart';
import 'package:inter_knot/services/update_service.dart';

import 'package:inter_knot/pages/my_page_desktop.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  final scrollController = ScrollController();
  final api = Get.find<Api>();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Desktop/expanded layout uses new modern forum UI
    // Compact layout uses standard scrolling
    final isCompact = MediaQuery.of(context).size.width < 640;
    final showUpdateEntry =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    if (!isCompact) {
      return Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/pc-page-bg.png',
              fit: BoxFit.cover,
            ),
          ),
          const MyPageDesktop(),
        ],
      );
    }

    // Fixed header sections
    final fixedHeader = Column(
      children: [
        // ── Hero profile card ──
        Obx(() {
          final user = c.user.value;
          final isLogin = c.isLogin.value;
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff2A2A2A), Color(0xff1A1A1A)],
              ),
              border: Border.all(color: const Color(0xff333333), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: isLogin ? c.pickAndUploadAvatar : null,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xffD7FF00),
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Avatar(user?.avatar, size: 52),
                          ),
                        ),
                        if (isLogin)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Color(0xffD7FF00),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 12,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        if (c.isUploadingAvatar.value)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0x88000000),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xffD7FF00),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? '绳网用户',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isLogin) ...[
                          const SizedBox(height: 4),
                          Text(
                            'UID · ${user?.userId ?? "—"}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff606060),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isLogin)
                    GestureDetector(
                      onTap: () => showEditProfileDialog(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xff444444), width: 1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '编辑',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xffA0A0A0),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
        // ── Level & Check-in card ──
        Obx(() {
          final user = c.user.value;
          final isLogin = c.isLogin.value;
          c.nextEligibleAtUtc.value;

          if (!isLogin || user == null) {
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xff1E1E1E),
                border: Border.all(color: const Color(0xff2A2A2A), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xffD7FF00).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: Color(0xffD7FF00),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          '绳网等级',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '登录后可查看绳网等级',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xff606060),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: c.ensureLogin,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xffD7FF00)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '登录以解锁签到',
                          style: TextStyle(
                            color: Color(0xffD7FF00),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return _buildMobileLevelAndCheckInSection(context, user);
        }),
        const SizedBox(height: 16),
      ],
    );

    // Scrollable content section
    final scrollableContent = Column(
      children: [
        // ── Menu group label ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '我的内容',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── Menu items grouped card ──
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xff1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xff2A2A2A), width: 1),
          ),
          child: Column(
            children: [
              _buildMenuItem(
                icon: Icons.article_outlined,
                iconColor: const Color(0xff60A5FA),
                iconBg: const Color(0x1A60A5FA),
                title: '我的帖子',
                subtitleWidget: Obx(() => Text(
                      '共 ${c.myDiscussionsCount.value} 项',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xff606060)),
                    )),
                onTap: () async {
                  if (await c.ensureLogin()) {
                    await navigateWithSlideTransition(
                      context,
                      const MyDiscussionsPage(),
                      routeName: '/my-discussions',
                    );
                    // 返回后刷新用户信息和帖子数量
                    await c.refreshSelfUserInfo();
                    final aid = c.authorId.value ?? c.user.value?.authorId;
                    if (aid != null && aid.isNotEmpty) {
                      c.myDiscussionsCount.value = await api.getUserDiscussionCount(aid);
                    }
                  }
                },
              ),
              const Padding(
                padding: EdgeInsets.only(left: 56),
                child: Divider(height: 1, color: Color(0xff2A2A2A)),
              ),
              Obx(() => _buildMenuItem(
                    icon: Icons.favorite_rounded,
                    iconColor: const Color(0xffF87171),
                    iconBg: const Color(0x1AF87171),
                    title: '喜欢',
                    subtitleWidget: Text(
                      '共 ${c.bookmarks.length} 项',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xff606060)),
                    ),
                    onTap: () => navigateWithSlideTransition(
                      context,
                      const LikedPage(),
                      routeName: '/liked',
                    ),
                  )),
              const Padding(
                padding: EdgeInsets.only(left: 56),
                child: Divider(height: 1, color: Color(0xff2A2A2A)),
              ),
              Obx(() => _buildMenuItem(
                    icon: Icons.history_rounded,
                    iconColor: const Color(0xffA78BFA),
                    iconBg: const Color(0x1AA78BFA),
                    title: '历史记录',
                    subtitleWidget: Text(
                      '共 ${c.history.length} 项',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xff606060)),
                    ),
                    onTap: () => navigateWithSlideTransition(
                      context,
                      const HistoryPage(),
                      routeName: '/history',
                    ),
                    isLast: !showUpdateEntry,
                  )),
              if (showUpdateEntry)
                InkWell(
                  onTap: () async {
                    showToast('正在检查更新...',
                        duration: const Duration(seconds: 1));
                    final updateInfo = await UpdateService.checkForUpdate();
                    if (updateInfo != null) {
                      if (context.mounted) {
                        showUpdateDialog(context, updateInfo);
                      }
                    } else {
                      showToast('已是最新版本',
                          duration: const Duration(seconds: 2));
                    }
                  },
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0x1A60A5FA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.system_update_rounded,
                              color: Color(0xff60A5FA), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              const Text(
                                '检查更新',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (UpdateService.hasUpdate) ...[
                                const SizedBox(width: 4),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xffFF4444),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xff404040),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Login/Logout card ──
        Obx(() {
          if (c.isLogin()) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xff1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xff2A2A2A), width: 1),
              ),
              child: _buildMenuItem(
                icon: Icons.logout_rounded,
                iconColor: const Color(0xffFB923C),
                iconBg: const Color(0x1AFB923C),
                title: '退出登录',
                onTap: () => showLogoutDialog(context),
                isFirst: true,
                isLast: true,
              ),
            );
          } else {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xff1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xff2A2A2A), width: 1),
              ),
              child: _buildMenuItem(
                icon: Icons.login_rounded,
                iconColor: const Color(0xff34D399),
                iconBg: const Color(0x1A34D399),
                title: '登录',
                onTap: c.ensureLogin,
                isFirst: true,
                isLast: true,
              ),
            );
          }
        }),
        const SizedBox(height: 32),
      ],
    );

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/pc-page-bg.png',
            fit: BoxFit.cover,
          ),
        ),
        Column(
          children: [
            fixedHeader,
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: scrollableContent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    Widget? subtitleWidget,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
    int? badgeCount,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                if (badgeCount != null && badgeCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xff1E1E1E),
                          width: 1.5,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitleWidget != null) ...[
                    const SizedBox(height: 2),
                    subtitleWidget,
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xff444444), size: 20),
          ],
        ),
      ),
    );
  }

  void _showLevelRulesDialog(BuildContext context) {
    showZZZDialog(
      context: context,
      pageBuilder: (context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 330,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xff1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xff313132),
                  width: 3,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '经验规则说明',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '每日签到：\n- 基础经验：10 XP\n- 连签奖励：每天额外 +2 XP\n- 每日上限：50 XP（基础 + 奖励）\n\n发布文章：\n- 每次发布：12 XP\n\n发表评论：\n- 每次评论：3 XP',
                    style: TextStyle(
                      color: Color(0xffB8B8B8),
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        '我知道了',
                        style: TextStyle(
                          color: Color(0xffD7FF00),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileLevelAndCheckInSection(BuildContext context, dynamic user) {
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
      orElse: () => levelTable.last,
    );

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

    final cannotCheckInNow = !user.canCheckIn;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xff1E1E1E),
        border: Border.all(color: const Color(0xff2A2A2A), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xffD7FF00).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xffD7FF00),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  '绳网等级',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showLevelRulesDialog(context),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.help_outline_rounded,
                      size: 16,
                      color: Color(0xff505050),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Level badge + exp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xffD7FF00).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xffD7FF00).withValues(alpha: 0.4),
                            width: 1),
                      ),
                      child: Text(
                        'Lv.$currentLevel',
                        style: const TextStyle(
                          color: Color(0xffD7FF00),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentConfig.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$currentExp / $nextExpTarget XP',
                  style: const TextStyle(
                    color: Color(0xff606060),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xff2C2C2C),
                color: const Color(0xffD7FF00),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 16),
            // Check-in button
            SizedBox(
              width: double.infinity,
              child: cannotCheckInNow
                  ? Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xff2A2A2A),
                        border: Border.all(
                            color: const Color(0xff383838), width: 1),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 16, color: Color(0xff606060)),
                          SizedBox(width: 6),
                          Text(
                            '今日已签到',
                            style: TextStyle(
                                color: Color(0xff606060),
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  : ElevatedButton(
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

                                  checkInDay ??= details['checkInDay'
                                          .toString()]
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
                                      final y =
                                          utc.year.toString().padLeft(4, '0');
                                      final m = utc.month
                                          .toString()
                                          .padLeft(2, '0');
                                      final d =
                                          utc.day.toString().padLeft(2, '0');
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
                            showToast(msg, isError: true);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffD7FF00),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('每日签到'),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
