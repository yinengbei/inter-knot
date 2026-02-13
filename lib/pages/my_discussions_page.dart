import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/components/discussions_grid.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/throttle.dart';
import 'package:inter_knot/models/h_data.dart';

class MyDiscussionsPage extends StatefulWidget {
  const MyDiscussionsPage({super.key});

  @override
  State<MyDiscussionsPage> createState() => _MyDiscussionsPageState();
}

class _MyDiscussionsPageState extends State<MyDiscussionsPage>
    with AutomaticKeepAliveClientMixin {
  final c = Get.find<Controller>();
  final api = Get.find<Api>();

  final discussions = <HDataModel>{}.obs;
  final hasNextPage = true.obs;
  String? endCursor;
  bool isLoading = false;

  late final fetchData = retryThrottle(
    _loadMore,
    const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (isLoading || !hasNextPage.value) return;
    
    final authorId = c.authorId.value ?? c.user.value?.authorId;
    if (authorId == null || authorId.isEmpty) {
      // 尝试刷新用户信息以获取 authorId
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
      Get.rawSnackbar(message: '加载失败: $e');
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
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xff121212),
      appBar: AppBar(title: const Text('我的帖子')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Obx(() {
          if (discussions.isEmpty && !hasNextPage.value) {
            return const Center(
              child: Text(
                '暂无帖子',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return DiscussionGrid(
            list: discussions,
            hasNextPage: hasNextPage.value,
            fetchData: fetchData,
          );
        }),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
