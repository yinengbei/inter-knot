import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/close_svg_button.dart';
import 'package:inter_knot/components/discussions_grid.dart';
import 'package:inter_knot/helpers/deferred_routes.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:inter_knot/helpers/time_formatter.dart';
import 'package:inter_knot/models/h_data.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.authorDocumentId,
  });

  final String authorDocumentId;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final _api = Get.find<Api>();
  late TabController _tabController;

  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  final RxSet<HDataModel> _articles = <HDataModel>{}.obs;
  final List<Map<String, dynamic>> _comments = [];
  String _articlesEndCursor = '0';
  String _commentsEndCursor = '0';
  bool _hasMoreArticles = true;
  bool _hasMoreComments = true;
  bool _isLoadingArticles = false;
  bool _isLoadingComments = false;

  String _extractBioText(List? bio) {
    if (bio == null || bio.isEmpty) return '';

    final buffer = StringBuffer();
    for (final block in bio) {
      if (block is Map && block['type'] == 'paragraph') {
        final children = block['children'] as List?;
        if (children == null) continue;

        for (final child in children) {
          if (child is Map && child['type'] == 'text') {
            buffer.write(child['text'] as String? ?? '');
          }
        }
      }
    }
    return buffer.toString();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      if (_tabController.index == 0 && _articles.isEmpty) {
        _loadArticles();
      } else if (_tabController.index == 1 && _comments.isEmpty) {
        _loadComments();
      }
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _api.getProfile(widget.authorDocumentId);
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
        _loadArticles();
      }
    } catch (e) {
      logger.e('Failed to load profile', error: e);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadArticles() async {
    if (_isLoadingArticles || !_hasMoreArticles) return;

    setState(() => _isLoadingArticles = true);

    try {
      // Prepare author data from profile
      Map<String, dynamic>? authorData;
      if (_profile != null) {
        authorData = {
          'documentId': _profile!['documentId'],
          'name': _profile!['name'],
          'slug': _profile!['slug'],
          'avatar': _profile!['avatar'],
          'user': _profile!['user'],
        };
      }

      final result = await _api.getProfileArticles(
        widget.authorDocumentId,
        _articlesEndCursor,
        authorData: authorData,
      );

      if (mounted) {
        setState(() {
          _articles.addAll(result.nodes);
          _articlesEndCursor = result.endCursor ?? _articlesEndCursor;
          _hasMoreArticles = result.hasNextPage;
          _isLoadingArticles = false;
        });
      }
    } catch (e) {
      logger.e('Failed to load articles', error: e);
      if (mounted) {
        setState(() => _isLoadingArticles = false);
      }
    }
  }

  Future<void> _loadComments() async {
    if (_isLoadingComments || !_hasMoreComments) return;

    setState(() => _isLoadingComments = true);

    try {
      final result = await _api.getProfileComments(
        widget.authorDocumentId,
        _commentsEndCursor,
      );

      if (mounted) {
        setState(() {
          _comments.addAll(result.nodes);
          _commentsEndCursor = result.endCursor ?? _commentsEndCursor;
          _hasMoreComments = result.hasNextPage;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      logger.e('Failed to load comments', error: e);
      if (mounted) {
        setState(() => _isLoadingComments = false);
      }
    }
  }

  Widget _buildProfileHeader() {
    if (_profile == null) return const SizedBox.shrink();

    final name = _profile!['name'] as String? ?? 'Unknown';
    final bio = _profile!['bio'] as List?;
    final avatar = _profile!['avatar'] as Map?;
    final user = _profile!['user'] as Map?;
    final stats = _profile!['stats'] as Map?;

    final avatarUrl = avatar?['url'] as String?;
    final level = user?['level'] as int? ?? 1;
    final exp = user?['exp'] as int? ?? 0;

    final totalViews = stats?['totalViews'] as int? ?? 0;
    final totalComments = stats?['totalComments'] as int? ?? 0;
    final totalLikes = stats?['totalLikes'] as int? ?? 0;

    final bioText = _extractBioText(bio);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xff1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Avatar(avatarUrl, size: 80),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffD7FF00),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Lv.$level',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'EXP: $exp',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xffD7FF00),
                      ),
                    ),
                    if (bioText.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        bioText,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xffB0B0B0),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xff404040)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('浏览', totalViews),
              _buildStatItem('收到评论', totalComments),
              _buildStatItem('点赞', totalLikes),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xff808080),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTabBar() {
    final stats = _profile?['stats'] as Map?;
    final articleCount = stats?['articleCount'] as int? ?? 0;
    final commentCount = stats?['commentCount'] as int? ?? 0;

    return TabBar(
      controller: _tabController,
      indicatorColor: const Color(0xffD7FF00),
      labelColor: const Color(0xffD7FF00),
      unselectedLabelColor: const Color(0xff808080),
      tabs: [
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('文章'),
              const SizedBox(width: 8),
              Text(
                articleCount.toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('评论'),
              const SizedBox(width: 8),
              Text(
                commentCount.toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArticlesList() {
    return DiscussionGrid(
      list: _articles,
      hasNextPage: _hasMoreArticles,
      fetchData: _loadArticles,
      reorderHistoryOnOpen: false,
    );
  }

  Widget _buildCommentsList() {
    if (_comments.isEmpty && _isLoadingComments) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Image.asset(
            'assets/images/Bangboo.gif',
            width: 80,
            height: 80,
          ),
        ),
      );
    }

    if (_comments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '暂无评论',
            style: TextStyle(color: Color(0xff808080)),
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200) {
          _loadComments();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _comments.length + (_hasMoreComments ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _comments.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Image.asset(
                  'assets/images/Bangboo.gif',
                  width: 80,
                  height: 80,
                ),
              ),
            );
          }

          final comment = _comments[index];
          return _buildCommentCard(comment);
        },
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final content = comment['content'] as String? ?? '';
    final createdAt = comment['createdAt'] as String?;
    final likesCount = comment['likescount'] as int? ?? 0;
    final liked = comment['liked'] as bool? ?? false;
    final article = comment['article'] as Map?;
    final parent = comment['parent'] as Map?;

    final articleTitle = article?['title'] as String? ?? '';
    final articleDocumentId = article?['documentId'] as String?;

    DateTime? createdDate;
    if (createdAt != null) {
      createdDate = DateTime.tryParse(createdAt);
    }

    return Card(
      color: const Color(0xff1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          if (articleDocumentId != null) {
            try {
              final discussion = await _api.getDiscussion(articleDocumentId);
              final hData = HDataModel(
                id: articleDocumentId,
                updatedAt: createdDate,
                createdAt: createdDate,
                isPinned: false,
              );
              await showDiscussionPageDialog(
                context,
                discussion: discussion,
                hData: hData,
                reorderHistoryOnOpen: false,
              );
            } catch (e) {
              logger.e('Failed to load discussion', error: e);
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (parent != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xff2A2A2A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '回复 ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xff808080),
                            ),
                          ),
                          Text(
                            parent['author']?['name'] as String? ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xffD7FF00),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        parent['content'] as String? ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xffB0B0B0),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SelectionArea(
                child: Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xffE0E0E0),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (createdDate != null)
                    Text(
                      formatRelativeTime(
                        createdDate,
                        fallbackPattern: 'yyyy-MM-dd HH:mm',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xff808080),
                      ),
                    ),
                  const Spacer(),
                  Icon(
                    liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: 14,
                    color: liked ? const Color(0xffD7FF00) : Colors.grey,
                  ),
                  if (likesCount > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      likesCount.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: liked ? const Color(0xffD7FF00) : Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
              if (articleTitle.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(color: Color(0xff404040)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.article_outlined,
                      size: 16,
                      color: Color(0xff808080),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        articleTitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xff808080),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    // 桌面端使用对话框样式，移动端使用全屏页面
    if (isDesktop) {
      return _buildDesktopDialog();
    }

    return _buildMobileLayout();
  }

  Widget _buildDesktopDialog() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 半透明背景
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
              ),
            ),
          ),
          // 内容区域
          Center(
            child: GestureDetector(
              onTap: () {}, // 阻止点击穿透
              child: Container(
                constraints:
                    const BoxConstraints(maxWidth: 1200, maxHeight: 900),
                margin: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/pc-page-bg.png'),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildDesktopHeader(),
                          const SizedBox(height: 24),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildDesktopContentBox(),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 1,
                                  child: _buildDesktopStatsBox(),
                                ),
                              ],
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
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xff121212),
      appBar: AppBar(
        backgroundColor: const Color(0xff1E1E1E),
        title: const Text('个人主页'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '加载失败',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xff808080),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildProfileHeader(),
                    ),
                    Container(
                      color: const Color(0xff1E1E1E),
                      child: _buildMobileTabBar(),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildArticlesList(),
                          _buildCommentsList(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildDesktopHeader() {
    if (_isLoading) {
      return Card(
        color: const Color(0xff1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 2,
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null || _profile == null) {
      return Card(
        color: const Color(0xff1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              _error ?? '加载失败',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    final name = _profile!['name'] as String? ?? 'Unknown';
    final bio = _profile!['bio'] as List?;
    final avatar = _profile!['avatar'] as Map?;
    final user = _profile!['user'] as Map?;

    final avatarUrl = avatar?['url'] as String?;
    final level = user?['level'] as int? ?? 1;
    final exp = user?['exp'] as int? ?? 0;

    final bioText = _extractBioText(bio);

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
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xffD7FF00).withValues(alpha: 0.5),
                  width: 4,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Avatar(avatarUrl, size: 100),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffD7FF00),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Lv.$level',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'EXP: $exp',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xffD7FF00),
                    ),
                  ),
                  if (bioText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      bioText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            CloseSvgButton(onTap: () => Get.back()),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopContentBox() {
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
            child: _buildDesktopTabBar(),
          ),
          const Divider(height: 1, color: Color(0xff333333)),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildArticlesList(),
                _buildCommentsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTabBar() {
    final stats = _profile?['stats'] as Map?;
    final articleCount = stats?['articleCount'] as int? ?? 0;
    final commentCount = stats?['commentCount'] as int? ?? 0;

    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        final selectedIndex = _tabController.index;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDesktopTabItem('文章', articleCount, 0, selectedIndex == 0),
              _buildDesktopTabItem('评论', commentCount, 1, selectedIndex == 1),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopTabItem(
      String text, int count, int index, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _tabController.animateTo(index),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        count.toString(),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.black.withValues(alpha: 0.6)
                              : const Color(0xff808080),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopStatsBox() {
    if (_profile == null) {
      return Card(
        color: const Color(0xff1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final stats = _profile!['stats'] as Map?;
    final totalViews = stats?['totalViews'] as int? ?? 0;
    final totalComments = stats?['totalComments'] as int? ?? 0;
    final totalLikes = stats?['totalLikes'] as int? ?? 0;

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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '统计数据',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            _buildDesktopStatItem(Icons.visibility_outlined, '浏览', totalViews),
            const SizedBox(height: 16),
            _buildDesktopStatItem(
                Icons.comment_outlined, '收到评论', totalComments),
            const SizedBox(height: 16),
            _buildDesktopStatItem(Icons.thumb_up_outlined, '点赞', totalLikes),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopStatItem(IconData icon, String label, int value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xffD7FF00), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
