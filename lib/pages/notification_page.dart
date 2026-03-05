import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/components/notification_card.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/dialog_helper.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/models/notification.dart';
import 'package:inter_knot/models/pagination.dart';
import 'package:inter_knot/pages/discussion_page.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage>
    with SingleTickerProviderStateMixin {
  final api = Get.find<Api>();
  final c = Get.find<Controller>();
  final scrollController = ScrollController();
  late TabController _tabController;

  final notifications = <NotificationModel>[].obs;
  final isLoading = false.obs;
  final hasMore = true.obs;
  final selectedTypes = Rx<List<NotificationType>?>(null);
  final currentTabIndex = 0.obs;
  String endCursor = '';

  final List<({List<NotificationType>? types, String label, IconData icon})> _tabs = [
    (types: null, label: '全部', icon: Icons.all_inbox),
    (types: [NotificationType.comment, NotificationType.reply], label: '回复', icon: Icons.reply),
    (types: [NotificationType.like], label: '点赞', icon: Icons.thumb_up),
    (types: [NotificationType.favorite], label: '收藏', icon: Icons.favorite),
    (types: [NotificationType.mention], label: '@我', icon: Icons.alternate_email),
    (types: [NotificationType.system], label: '系统', icon: Icons.notifications),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    scrollController.addListener(_onScroll);
    _loadNotifications();
    _loadUnreadCount();
    
    // 监听登录状态变化，登录后自动刷新数据
    ever(c.isLogin, (isLogin) {
      if (isLogin) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // 索引变化时立即刷新，不等待动画结束
    if (_tabController.index != currentTabIndex.value) {
      currentTabIndex.value = _tabController.index;
      selectedTypes.value = _tabs[_tabController.index].types;
      // 立即清空列表，避免显示旧数据
      notifications.clear();
      _refresh();
    }
  }

  void _onScroll() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !isLoading.value &&
        hasMore.value) {
      _loadMore();
    }
  }

  Future<void> _loadUnreadCount() async {
    await c.refreshUnreadNotificationCount();
  }

  Future<void> _loadNotifications([String endCursor = '']) async {
    if (isLoading.value) return;
    
    // 检查登录状态，未登录时直接返回，不显示错误
    if (!c.isLogin.value) {
      isLoading.value = false;
      return;
    }
    
    isLoading.value = true;

    try {
      final PaginationModel<dynamic> result =
          await api.getNotifications(endCursor);

      var newNotifications = result.nodes
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // 根据选中的类型过滤
      if (selectedTypes.value != null) {
        newNotifications = newNotifications
            .where((n) => selectedTypes.value!.contains(n.type))
            .toList();
      }

      if (endCursor.isEmpty) {
        notifications.value = newNotifications;
      } else {
        notifications.addAll(newNotifications);
      }

      endCursor = result.endCursor ?? '';
      hasMore.value = result.hasNextPage;
    } catch (e) {
      debugPrint('Load notifications error: $e');
      // 只在已登录时显示错误提示
      if (c.isLogin.value) {
        showToast('加载通知失败', isError: true);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadMore() async {
    if (hasMore.value && !isLoading.value) {
      await _loadNotifications();
    }
  }

  Future<void> _refresh() async {
    endCursor = '';
    hasMore.value = true;
    await _loadNotifications();
    await _loadUnreadCount();
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead || notification.documentId == null) return;

    try {
      final success = await api.markNotificationAsRead(notification.documentId!);
      if (success) {
        c.decrementUnreadNotificationCount();
        final index =
            notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          notifications[index] = NotificationModel(
            id: notification.id,
            documentId: notification.documentId,
            type: notification.type,
            isRead: true,
            sender: notification.sender,
            articleDocumentId: notification.articleDocumentId,
            articleTitle: notification.articleTitle,
            commentId: notification.commentId,
            commentContent: notification.commentContent,
            targetType: notification.targetType,
            createdAt: notification.createdAt,
            updatedAt: notification.updatedAt,
          );
          notifications.refresh();
        }
      }
    } catch (e) {
      debugPrint('Mark as read error: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final success = await api.markAllNotificationsAsRead();
      if (success) {
        notifications.value = notifications.map((n) {
          return NotificationModel(
            id: n.id,
            documentId: n.documentId,
            type: n.type,
            isRead: true,
            sender: n.sender,
            articleDocumentId: n.articleDocumentId,
            articleTitle: n.articleTitle,
            commentId: n.commentId,
            commentContent: n.commentContent,
            targetType: n.targetType,
            createdAt: n.createdAt,
            updatedAt: n.updatedAt,
          );
        }).toList();
        c.clearUnreadNotificationCount();
        showToast('全部标记已读');
      }
    } catch (e) {
      debugPrint('Mark all as read error: $e');
      showToast('操作失败', isError: true);
    }
  }

  void _handleNotificationTap(NotificationModel notification) async {
    _markAsRead(notification);

    if (notification.articleDocumentId != null &&
        notification.articleDocumentId!.isNotEmpty) {
      try {
        // 先获取文章详情
        final discussion = await api.getArticleDetail(notification.articleDocumentId!);
        
        // 缓存到HDataModel
        HDataModel.upsertCachedDiscussion(discussion);
        
        // 创建HDataModel实例
        final hData = HDataModel(
          id: discussion.id,
          updatedAt: discussion.lastEditedAt ?? discussion.createdAt,
          createdAt: discussion.createdAt,
          isPinned: false,
        );
        
        // 使用和主页一样的弹窗方式展示文章详情
        if (!mounted) return;
        await showZZZDialog(
          context: context,
          pageBuilder: (context) {
            return DiscussionPage(
              discussion: discussion,
              hData: hData,
            );
          },
        );
      } catch (e) {
        debugPrint('Load article error: $e');
        showToast('加载文章失败', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 640;
    if (isCompact) {
      // 移动端：全屏显示
      return _buildMobileLayout();
    } else {
      // 桌面端：直接显示，导航栏已在主页结构中
      return _buildDesktopLayout();
    }
  }

  // 移动端布局：顶部Tab + 列表（保持深色主题）
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xff0A0A0A),
      body: Column(
        children: [
          // Tab导航栏
          Container(
            color: const Color(0xff1A1A1A),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // 标题栏
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Get.back(),
                        ),
                        const Expanded(
                          child: Text(
                            '消息中心',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Obx(() {
                          if (c.unreadNotificationCount.value == 0) return const SizedBox.shrink();
                          return TextButton(
                            onPressed: _markAllAsRead,
                            child: const Text(
                              '全部已读',
                              style: TextStyle(color: Color(0xffD7FF00), fontSize: 14),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  // Tab栏
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: const Color(0xffD7FF00),
                    unselectedLabelColor: Colors.white60,
                    indicatorColor: const Color(0xffD7FF00),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontSize: 15),
                    tabs: _tabs.map((tab) => Tab(text: tab.label)).toList(),
                  ),
                ],
              ),
            ),
          ),
          // 内容区域
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(), // 禁用左右滑动
              children: List.generate(_tabs.length, (index) => _buildNotificationList()),
            ),
          ),
        ],
      ),
    );
  }

  // 桌面端布局：居中显示，左右留白（B站风格）
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xff0A0A0A),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            children: [
              // 左侧导航（B站风格）
              Container(
                width: 240,
                decoration: const BoxDecoration(
                  color: Color(0xff1A1A1A),
                  border: Border(
                    right: BorderSide(color: Color(0xff2A2A2A), width: 1),
                  ),
                ),
                child: Obx(() {
                  final currentIndex = currentTabIndex.value;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _tabs.length,
                    itemBuilder: (context, index) {
                      final tab = _tabs[index];
                      final isSelected = currentIndex == index;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              _tabController.animateTo(index);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xffD7FF00) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    tab.icon,
                                    color: isSelected ? Colors.black : Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    tab.label,
                                    style: TextStyle(
                                      color: isSelected ? Colors.black : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
              // 右侧内容区域
              Expanded(
                child: Column(
                  children: [
                    // 当前页面标题框（B站风格）
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      decoration: const BoxDecoration(
                        color: Color(0xff0A0A0A),
                        border: Border(
                          bottom: BorderSide(color: Color(0xff2A2A2A), width: 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Obx(() {
                            final currentIndex = currentTabIndex.value;
                            final currentTab = _tabs[currentIndex];
                            return Text(
                              currentTab.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }),
                          Obx(() {
                            if (c.unreadNotificationCount.value == 0) return const SizedBox.shrink();
                            return TextButton.icon(
                              onPressed: _markAllAsRead,
                              icon: const Icon(
                                Icons.done_all,
                                color: Color(0xffD7FF00),
                                size: 18,
                              ),
                              label: const Text(
                                '全部已读',
                                style: TextStyle(
                                  color: Color(0xffD7FF00),
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    // 消息列表
                    Expanded(
                      child: _buildNotificationList(),
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

  // 通知列表
  Widget _buildNotificationList() {
    return Obx(() {
      // 移除加载动画，直接显示列表

      if (notifications.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_none,
                size: 64,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                '暂无通知',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xffD7FF00),
        backgroundColor: const Color(0xff1A1A1A),
        child: ListView.builder(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: notifications.length + (hasMore.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == notifications.length) {
              // 移除加载更多时的圆圈动画
              return const SizedBox.shrink();
            }

            final notification = notifications[index];
            return NotificationCard(
              notification: notification,
              onTap: () => _handleNotificationTap(notification),
              onMarkRead: () => _markAsRead(notification),
            );
          },
        ),
      );
    });
  }
}
