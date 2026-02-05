import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inter_knot/api/api.dart'; // Import Api
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:inter_knot/helpers/num2dur.dart';
import 'package:inter_knot/helpers/throttle.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/models/release.dart';
import 'package:inter_knot/models/report_comment.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Standard shared_preferences or specific wrapper?
// The file used SharedPreferencesWithCache which is new in flutter/packages?
// I'll stick to what was there or what works.

// Assuming Controller is registered
final c = Get.find<Controller>();

class Controller extends GetxController {
  late final SharedPreferencesWithCache pref;

  final searchQuery = ''.obs;
  final searchResult = <HDataModel>{}.obs; // HData -> HDataModel
  String? searchEndCur;
  final searchHasNextPage = true.obs;

  String rootToken = '';

  String getToken() => box.read<String>('access_token') ?? '';
  Future<void> setToken(String v) => box.write('access_token', v);
  String getRefreshToken() => pref.getString('refresh_token') ?? '';
  Future<void> setRefreshToken(String v) => pref.setString('refresh_token', v);

  final isLogin = false.obs;
  final user = Rx<AuthorModel?>(null); // Author -> AuthorModel
  final authorId = RxnString();
  final isUploadingAvatar = false.obs;

  final report = <String, Set<ReportCommentModel>>{}.obs;

  final bookmarks = <HDataModel>{}.obs;
  final favoriteIds = <String, String>{}.obs;
  final history = <HDataModel>{}.obs;

  // Api instance
  final api = Get.find<Api>();

  String _withCacheBuster(String url) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return url.contains('?') ? '$url&v=$ts' : '$url?v=$ts';
  }

  Future<void> updateUserAvatarFromDiscussionsCache() async {
    final login = user.value?.login;
    if (login == null || login.isEmpty) return;
    if (user.value?.avatar.isNotEmpty == true) return;

    for (final future in HDataModel.discussionsCache.values) {
      try {
        final discussion = await future;
        if (discussion != null && discussion.author.login == login) {
          final avatar = discussion.author.avatar;
          if (avatar.isNotEmpty) {
            user.value?.avatar = avatar;
            user.refresh();
            return;
          }
        }
      } catch (_) {
        // Ignore cache errors; continue scanning.
      }
    }
  }

  Future<void> _refreshAvatarCaches(String newUrl) async {
    final login = user.value?.login;
    if (login == null || login.isEmpty) return;

    final futures = HDataModel.discussionsCache.values.toList();
    for (final future in futures) {
      try {
        final discussion = await future;
        if (discussion != null && discussion.author.login == login) {
          discussion.author.avatar = newUrl;
        }
      } catch (_) {
        // Ignore cache update errors.
      }
    }

    searchResult.refresh();
    bookmarks.refresh();
    history.refresh();
  }

  Future<void> refreshSelfUserInfo({bool forceAvatarFetch = true}) async {
    try {
      final u = await api.getSelfUserInfo('');
      user(u);
      await ensureAuthorForUser(u);

      if (forceAvatarFetch) {
        final id = authorId.value ?? u.authorId;
        if (id != null && id.isNotEmpty) {
          final url = await api.getAuthorAvatarUrl(id);
          if (url != null && url.isNotEmpty) {
            u.avatar = _withCacheBuster(url);
          }
        }
      }
      user.refresh();
      await updateUserAvatarFromDiscussionsCache();
    } catch (e) {
      logger.e('Failed to refresh self user info', error: e);
    }
  }

  bool canVisit(DiscussionModel discussion, bool isPin) =>
      report[discussion.id] == null ||
      [owner, ...collaborators].contains(discussion.author.login) ||
      isPin ||
      report[discussion.id]!.length < 6;

  final curPage = 0.obs;

  final accelerator = ''.obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    pref = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    pageController
        .addListener(() => curPage(pageController.page?.round() ?? 0));
    pref.remove('root_token');
    isLogin(pref.getBool('isLogin') ?? false);
    ever(isLogin, (v) => pref.setBool('isLogin', v));
    logger.i(isLogin());
    accelerator(pref.getString('accelerator') ?? '');
    ever(accelerator, (v) => pref.setString('accelerator', v));
    
    // Always check for user info if token exists
    if (getToken().isNotEmpty) {
       isLogin(true);
       try {
         await refreshSelfUserInfo();
         await refreshFavorites();
       } catch (e) {
         // Keep login state; token will be cleared on 401 by BaseConnect
         logger.e('Failed to get user info', error: e);
       }
    }

    ever(isLogin, (v) async {
       if (v) {
          // fetch user info if not present
          if (user.value == null) {
              try {
                await refreshSelfUserInfo();
                await refreshFavorites();
              } catch(e) {
                logger.e('Failed to fetch user after login', error: e);
              }
          } else {
            await refreshFavorites();
          }
       } else {
         user.value = null;
         authorId.value = null;
         box.remove('access_token');
         bookmarks.clear();
         favoriteIds.clear();
       }
    });

    debounce(
      searchQuery,
      (query) {
        searchController.text = query;
        searchResult.clear();
        searchEndCur = null;
        searchHasNextPage.value = true;
        searchCache.clear();
        searchData();
      },
      time: 500.ms,
    );
    searchData();
    history.addAll(pref.getStringList('history')?.map((e) => HDataModel.fromJson(jsonDecode(e) as Map<String, dynamic>)).cast<HDataModel>() ?? []);
    
    // Reports and Version
    // api.getAllReports...
    // api.getNewVersion...
  }

  Future<void> refreshFavorites() async {
    final username = user.value?.login ?? '';
    if (isLogin.isFalse || username.isEmpty) {
      bookmarks.clear();
      favoriteIds.clear();
      return;
    }

    final result = await api.getFavorites(username, '');
    bookmarks(result.items.toSet());
    favoriteIds.assignAll(result.favoriteIds);
  }

  Future<void> toggleFavorite(HDataModel hData) async {
    if (isLogin.isFalse) {
      Get.rawSnackbar(message: '请先登录');
      return;
    }
    final userId = user.value?.userId;
    final username = user.value?.login ?? '';
    if (userId == null || userId.isEmpty || username.isEmpty) {
      Get.rawSnackbar(message: '用户信息获取失败');
      return;
    }

    final articleId = hData.id;
    if (articleId.isEmpty) return;

    var favoriteId = favoriteIds[articleId];
    if (favoriteId == null) {
      favoriteId = await api.getFavoriteId(
        username: username,
        articleId: articleId,
      );
      if (favoriteId != null && favoriteId.isNotEmpty) {
        favoriteIds[articleId] = favoriteId;
        bookmarks({hData, ...bookmarks});
      }
    }

    if (favoriteId != null && favoriteId.isNotEmpty) {
      final ok = await api.deleteFavorite(favoriteId);
      if (ok) {
        favoriteIds.remove(articleId);
        bookmarks.removeWhere((e) => e.id == articleId);
      } else {
        Get.rawSnackbar(message: '取消收藏失败');
      }
    } else {
      final newId = await api.createFavorite(
        userId: userId,
        articleId: articleId,
      );
      if (newId != null && newId.isNotEmpty) {
        favoriteIds[articleId] = newId;
        bookmarks({hData, ...bookmarks});
      } else {
        Get.rawSnackbar(message: '收藏失败');
      }
    }
  }

  void getVersionHandle(ReleaseModel? release) {
    // Keep existing logic if compatible
  }

  bool mustUpdate(Version newVer, Version curVer) =>
      newVer.major > curVer.major || newVer.minor > curVer.minor;

  final selectedIndex = 0.obs;
  final pageController = PageController();

  Future<void> animateToPage(int index) {
    selectedIndex.value = index;
    return pageController.animateToPage(
      index,
      duration: 0.5.s,
      curve: Curves.ease,
    );
  }

  bool isFetchPinDiscussions = true;
  final searchController = SearchController();

  late final refreshSearchData = throttle(() async {
    logger.i('Refreshing search data...');
    searchHasNextPage.value = true;
    searchEndCur = null;
    searchCache.clear();
    HDataModel.discussionsCache.clear(); // 清空详情缓存
    searchResult.clear();
    await searchData();
    logger.i('Refreshed. Result count: ${searchResult.length}');
  });

  final searchCache = <String?>{};
  Future<void> searchData() async {
    if (searchHasNextPage.isFalse || searchCache.contains(searchEndCur)) return;
    searchCache.add(searchEndCur);
    final pagination = await api.search(searchQuery(), searchEndCur ?? '');
    // pagination returns PaginationModel<HDataModel>
    // destructure:
    searchEndCur = pagination.endCursor;
    searchHasNextPage.value = pagination.hasNextPage;
    searchResult.addAll(pagination.nodes);
    await updateUserAvatarFromDiscussionsCache();
  }

  Future<String?> ensureAuthorForUser(AuthorModel? u) async {
    if (u == null) return null;
    if (u.authorId != null && u.authorId!.isNotEmpty) {
      authorId.value = u.authorId;
      return u.authorId;
    }
    final name = (u.name.isNotEmpty ? u.name : u.login).trim();
    if (name.isEmpty) return null;
    final id = await api.ensureAuthorId(
      name: name,
      userId: u.userId,
    );
    if (id != null && id.isNotEmpty) {
      authorId.value = id;
      if (u.userId != null && u.userId!.isNotEmpty) {
        try {
          await api.linkAuthorToUser(authorId: id, userId: u.userId!);
        } catch (_) {
          // Best-effort linking; avoid blocking login flow.
        }
      }
    }
    return id;
  }

  Future<void> pickAndUploadAvatar() async {
    if (isLogin.isFalse) {
      Get.rawSnackbar(message: '请先登录'.tr);
      return;
    }
    if (isUploadingAvatar.value) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (file == null) return;

    isUploadingAvatar(true);
    try {
      final curUser = user.value;
      final targetAuthorId =
          authorId.value ?? curUser?.authorId ?? await ensureAuthorForUser(curUser);
      if (targetAuthorId == null || targetAuthorId.isEmpty) {
        throw Exception('未找到作者信息');
      }

      final bytes = await file.readAsBytes();
      final avatarUrl = await api.uploadAvatar(
        authorId: targetAuthorId,
        bytes: bytes,
        filename: file.name,
      );
      final current = user.value;
      if (current != null && avatarUrl != null && avatarUrl.isNotEmpty) {
        final refreshed = _withCacheBuster(avatarUrl);
        current.avatar = refreshed;
        user.refresh();
        await _refreshAvatarCaches(refreshed);
      }
      await refreshSelfUserInfo();
      Get.rawSnackbar(message: '头像已更新'.tr);
    } catch (e) {
      Get.rawSnackbar(message: '头像上传失败: $e');
    } finally {
      isUploadingAvatar(false);
    }
  }
}

bool canReport(DiscussionModel discussion, bool isPin) =>
    ![owner, ...collaborators].contains(discussion.author.login) && !isPin;
