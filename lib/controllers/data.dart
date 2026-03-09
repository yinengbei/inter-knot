import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inter_knot/api/api.dart'; // Import Api
import 'package:inter_knot/api/api_exception.dart';
import 'package:inter_knot/constants/api_config.dart';
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/helpers/dialog_helper.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:inter_knot/helpers/num2dur.dart';
import 'package:inter_knot/helpers/throttle.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/pages/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Standard shared_preferences or specific wrapper?
// The file used SharedPreferencesWithCache which is new in flutter/packages?
// I'll stick to what was there or what works.

// Assuming Controller is registered
final c = Get.find<Controller>();

class Controller extends GetxController {
  late final SharedPreferencesWithCache pref;

  final searchQuery = ''.obs;
  final searchResult = <HDataModel>{}.obs; // HData -> HDataModel
  // Persistent storage key for offline cache
  static const String _searchCacheKey = 'offline_search_cache';
  String? searchEndCur;
  final searchHasNextPage = true.obs;
  final isSearching = false.obs;
  final newPostCount = 0.obs;
  final hasContentChange = false.obs;
  final newlyInsertedPostIds = <String>{}.obs;
  Timer? _newPostCheckTimer;
  Timer? _clearInsertedPostsTimer;
  Timer? _checkInEligibilityTimer;

  String rootToken = '';

  String getToken() => box.read<String>('access_token') ?? '';
  Future<void> setToken(String v) => box.write('access_token', v);
  String getRefreshToken() => pref.getString('refresh_token') ?? '';
  Future<void> setRefreshToken(String v) => pref.setString('refresh_token', v);

  final isLogin = false.obs;
  final user = Rx<AuthorModel?>(null); // Author -> AuthorModel
  final authorId = RxnString();
  final nextEligibleAtUtc = Rxn<DateTime>();
  final myDiscussionsCount = 0.obs;
  final isUploadingAvatar = false.obs;
  final unreadNotificationCount = 0.obs;

  final bookmarks = <HDataModel>{}.obs;
  final favoriteIds = <String, String>{}.obs;
  final history = <HDataModel>{}.obs;
  static const String _historyKey = 'history';
  static const String _localReadCacheKey = 'local_read_cache';
  static const String _localViewCacheKey = 'local_view_cache';
  static const int _localCacheMax = 500;
  final _localReadCache = <String, bool>{};
  final _localViewCache = <String, int>{};

  List<String> _encodeHistoryForStorage(Iterable<HDataModel> list) {
    final result = <String>[];
    var count = 0;
    for (final item in list) {
      if (count >= _localCacheMax) break;
      try {
        result.add(jsonEncode(item.toJson()));
        count++;
      } catch (_) {
        // Ignore invalid entries.
      }
    }
    return result;
  }

  void _saveHistoryToLocal() {
    try {
      pref.setStringList(_historyKey, _encodeHistoryForStorage(history));
    } catch (_) {
      // Ignore persistence failures.
    }
  }

  void _cancelCheckInEligibilityTimer() {
    _checkInEligibilityTimer?.cancel();
    _checkInEligibilityTimer = null;
  }

  void _scheduleCheckInEligibilityRefresh(DateTime? nextEligibleAt) {
    _cancelCheckInEligibilityTimer();

    if (!isLogin.value || nextEligibleAt == null) return;

    final now = DateTime.now().toUtc();
    if (!now.isBefore(nextEligibleAt)) {
      nextEligibleAtUtc.value = null;
      unawaited(refreshMyExp());
      return;
    }

    final delay = nextEligibleAt.difference(now) + const Duration(seconds: 1);
    _checkInEligibilityTimer = Timer(delay, () async {
      if (!isLogin.value) return;
      await refreshMyExp();
    });
  }

  Future<void> refreshMyExp() async {
    final u = user.value;
    if (u == null) return;

    try {
      final expInfo = await api.getMyExp();
      u.exp = expInfo.exp;
      u.level = expInfo.level;
      u.canCheckIn = expInfo.canCheckIn;
      final last = expInfo.lastCheckInDate;
      if (last != null && last.isNotEmpty) {
        u.lastCheckInDate = last;
      }
      final days = expInfo.consecutiveCheckInDays;
      if (days != null) {
        u.consecutiveCheckInDays = days;
      }

      final nextEligibleAt = expInfo.nextEligibleAtUtc;
      if (nextEligibleAt != null) {
        nextEligibleAtUtc.value = nextEligibleAt;
      }

      if (u.canCheckIn) {
        nextEligibleAtUtc.value = null;
      }

      final next = nextEligibleAtUtc.value;
      if (next != null && !DateTime.now().toUtc().isBefore(next)) {
        nextEligibleAtUtc.value = null;
      }

      _scheduleCheckInEligibilityRefresh(nextEligibleAtUtc.value);
      user.refresh();
    } catch (e) {
      logger.w('Failed to refresh my exp', error: e);
    }
  }

  // Api instance
  final api = Get.find<Api>();

  String _withCacheBuster(String url) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return url.contains('?') ? '$url&v=$ts' : '$url?v=$ts';
  }

  String? _avatarCacheKeyForUser(AuthorModel? u) {
    final id = u?.userId;
    if (id != null && id.isNotEmpty) return 'avatar_url_$id';
    final login = u?.login;
    if (login != null && login.isNotEmpty) return 'avatar_url_$login';
    return null;
  }

  void _cacheAvatarForUser(AuthorModel? u, String url) {
    final key = _avatarCacheKeyForUser(u);
    if (key == null) return;
    box.write(key, url);
  }

  String? _getCachedAvatarForUser(AuthorModel? u) {
    final key = _avatarCacheKeyForUser(u);
    if (key == null) return null;
    return box.read<String>(key);
  }

  void _clearCachedAvatarForUser(AuthorModel? u) {
    final key = _avatarCacheKeyForUser(u);
    if (key == null) return;
    box.remove(key);
  }

  bool _isAuthRequiredError(Object error) {
    if (error is! ApiException) return false;
    if (error.statusCode == 401 || error.statusCode == 403) return true;

    final message = error.message.toLowerCase();
    if (message.contains('forbidden') || message.contains('unauthorized')) {
      return true;
    }

    final details = error.details;
    if (details is Map) {
      final rawError = details['error'];
      if (rawError is Map) {
        final code = rawError['code']?.toString().toLowerCase() ?? '';
        final detailMessage =
            rawError['message']?.toString().toLowerCase() ?? '';
        if (code.contains('forbidden') ||
            code.contains('unauthorized') ||
            detailMessage.contains('forbidden') ||
            detailMessage.contains('unauthorized')) {
          return true;
        }
      } else if (rawError is String) {
        final raw = rawError.toLowerCase();
        if (raw.contains('forbidden') || raw.contains('unauthorized')) {
          return true;
        }
      }
    }

    return false;
  }

  Future<void> _clearStoredSession({bool clearPersistedLogin = true}) async {
    final u = user.value;
    user.value = null;
    authorId.value = null;
    nextEligibleAtUtc.value = null;
    _cancelCheckInEligibilityTimer();
    clearUnreadNotificationCount();
    myDiscussionsCount.value = 0;
    _clearCachedAvatarForUser(u);
    await box.remove('access_token');
    await box.remove('userId');
    bookmarks.clear();
    favoriteIds.clear();
    _localReadCache.clear();
    _localViewCache.clear();
    await box.remove(_localReadCacheKey);
    await box.remove(_localViewCacheKey);
    if (clearPersistedLogin) {
      await pref.setBool('isLogin', false);
    }
    isLogin.value = false;
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
            _cacheAvatarForUser(user.value, avatar);
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

  Future<void> refreshSelfUserInfo({
    bool forceAvatarFetch = true,
    bool rethrowOnError = false,
  }) async {
    try {
      final u = await api.getSelfUserInfo('');

      try {
        final expInfo = await api.getMyExp();
        u.exp = expInfo.exp;
        u.level = expInfo.level;
        u.canCheckIn = expInfo.canCheckIn;
        final last = expInfo.lastCheckInDate;
        if (last != null && last.isNotEmpty) {
          u.lastCheckInDate = last;
        }
        final days = expInfo.consecutiveCheckInDays;
        if (days != null) {
          u.consecutiveCheckInDays = days;
        }
        final nextEligibleAt = expInfo.nextEligibleAtUtc;
        if (nextEligibleAt != null) {
          nextEligibleAtUtc.value = nextEligibleAt;
        } else if (u.canCheckIn) {
          nextEligibleAtUtc.value = null;
        }
      } catch (_) {
        // Ignore exp refresh failures; keep user info usable.
      }

      user(u);
      await ensureAuthorForUser(u);

      // Only fetch avatar if it's still empty after getSelfUserInfo
      // (getSelfUserInfo already calls _fetchAndSetAvatar)
      if (forceAvatarFetch && u.avatar.isEmpty) {
        final id = authorId.value ?? u.authorId;
        if (id != null && id.isNotEmpty) {
          try {
            final url = await api.getAuthorAvatarUrl(id);
            if (url != null && url.isNotEmpty) {
              u.avatar = url;
            }
          } catch (_) {
            // Ignore forbidden or missing permission.
          }
        }
      }
      if (u.avatar.isEmpty) {
        final cached = _getCachedAvatarForUser(u);
        if (cached != null && cached.isNotEmpty) {
          u.avatar = cached;
        }
      } else {
        _cacheAvatarForUser(u, u.avatar);
      }
      user.refresh();
      await updateUserAvatarFromDiscussionsCache();

      // Refresh discussion count
      final aid = authorId.value ?? u.authorId;
      if (aid != null && aid.isNotEmpty) {
        myDiscussionsCount.value = await api.getUserDiscussionCount(aid);
      }
    } catch (e) {
      logger.e('Failed to refresh self user info', error: e);
      if (rethrowOnError) rethrow;
    }
  }


  void _loadLocalCaches() {
    final read = box.read<Map>(_localReadCacheKey);
    if (read != null) {
      for (final entry in read.entries) {
        final key = entry.key.toString();
        final value = entry.value == true;
        _localReadCache[key] = value;
      }
    }
    final views = box.read<Map>(_localViewCacheKey);
    if (views != null) {
      for (final entry in views.entries) {
        final key = entry.key.toString();
        final value = int.tryParse(entry.value.toString());
        if (value != null) _localViewCache[key] = value;
      }
    }
  }

  void _trimLocalCache<K, V>(Map<K, V> cache) {
    while (cache.length > _localCacheMax) {
      cache.remove(cache.keys.first);
    }
  }

  void _persistLocalReadCache() {
    _trimLocalCache(_localReadCache);
    box.write(_localReadCacheKey, Map<String, bool>.from(_localReadCache));
  }

  void _persistLocalViewCache() {
    _trimLocalCache(_localViewCache);
    box.write(_localViewCacheKey, Map<String, int>.from(_localViewCache));
  }

  void applyLocalOverrides(DiscussionModel discussion) {
    final id = discussion.id;
    final read = _localReadCache[id];
    if (read == true) discussion.isRead = true;
    final views = _localViewCache[id];
    if (views != null && views > discussion.views) {
      discussion.views = views;
    }
  }

  void markDiscussionReadAndViewed(DiscussionModel discussion) {
    final id = discussion.id;
    if (id.isEmpty) return;
    discussion.isRead = true;
    _localReadCache[id] = true;
    final nextViews = discussion.views + 1;
    discussion.views = nextViews;
    final cachedViews = _localViewCache[id];
    if (cachedViews == null || nextViews > cachedViews) {
      _localViewCache[id] = nextViews;
    }
    _persistLocalReadCache();
    _persistLocalViewCache();
    HDataModel.upsertCachedDiscussion(discussion);
    searchResult.refresh();
    bookmarks.refresh();
    history.refresh();
  }

  bool canVisit(DiscussionModel discussion, bool isPin) => true;

  final curPage = 0.obs;

  final accelerator = ''.obs;

  @override
  void onClose() {
    _newPostCheckTimer?.cancel();
    _clearInsertedPostsTimer?.cancel();
    _cancelCheckInEligibilityTimer();
    super.onClose();
  }

  @override
  Future<void> onInit() async {
    super.onInit();
    pref = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    _loadLocalCaches();
    pageController
        .addListener(() => curPage(pageController.page?.round() ?? 0));
    pref.remove('root_token');
    isLogin(false);
    await pref.setBool('isLogin', false);
    ever(isLogin, (v) => pref.setBool('isLogin', v));
    ever(user, (u) {
      if (u?.userId != null) {
        box.write('userId', u!.userId);
      } else {
        box.remove('userId');
      }
    });
    ever<DateTime?>(nextEligibleAtUtc, _scheduleCheckInEligibilityRefresh);
    logger.i(isLogin());
    accelerator(pref.getString('accelerator') ?? '');
    ever(accelerator, (v) => pref.setString('accelerator', v));

    // Always check for user info if token exists
    final token = getToken();
    if (token.isNotEmpty) {
      try {
        await refreshSelfUserInfo(rethrowOnError: true);
        isLogin(true);
        await refreshFavorites();
        await refreshUnreadNotificationCount();
      } catch (e) {
        if (_isAuthRequiredError(e)) {
          await _clearStoredSession();
        } else {
          logger.e('Failed to get user info', error: e);
        }
      }
    } else {
      // Check for pending activation credentials
      final pendingEmail = box.read<String>('pending_activation_email');
      final pendingPassword = box.read<String>('pending_activation_password');
      if (pendingEmail != null && pendingPassword != null) {
        // Try to login silently
        try {
          final res =
              await BaseConnect.authApi.login(pendingEmail, pendingPassword);
          if (res.token != null) {
            await setToken(res.token!);
            user(res.user);
            await ensureAuthorForUser(res.user);
            isLogin(true);
            await refreshSelfUserInfo(rethrowOnError: true);
            await refreshFavorites();
            await refreshUnreadNotificationCount();
            // Clear pending credentials
            box.remove('pending_activation_email');
            box.remove('pending_activation_password');
            showToast('登录成功：欢迎回来，绳匠！');
          }
        } catch (e) {
          // Ignore failures, user will see waiting screen in LoginPage if they go there
          logger.w('Auto-login from pending activation failed: $e');
        }
      }
    }

    ever(isLogin, (v) async {
      if (v) {
        _scheduleCheckInEligibilityRefresh(nextEligibleAtUtc.value);
        // Only fetch if user info is missing (e.g., after manual login action)
        // Initial login in onInit already handles data fetching
        if (user.value == null) {
          try {
            await refreshSelfUserInfo(rethrowOnError: true);
            await refreshFavorites();
            await refreshUnreadNotificationCount();
          } catch (e) {
            if (_isAuthRequiredError(e)) {
              await _clearStoredSession(clearPersistedLogin: false);
            } else {
              logger.e('Failed to fetch user after login', error: e);
            }
          }
        }
        // Note: Removed redundant refreshFavorites/refreshUnreadNotificationCount
        // when user.value exists, as they're already called during login
      } else {
        await _clearStoredSession(clearPersistedLogin: false);
      }
    });

    debounce(
      searchQuery,
      (query) async {
        searchController.text = query;
        searchResult.clear();
        searchEndCur = null;
        searchHasNextPage.value = true;
        searchCache.clear();
        isSearching(true);
        await searchData();
        isSearching(false);
      },
      time: 500.ms,
    );
    isSearching(true);
    // Load cached search result if available (offline support)
    final cachedSearch = box.read<List<dynamic>>(_searchCacheKey);
    if (cachedSearch != null && cachedSearch.isNotEmpty) {
      try {
        final list = cachedSearch
            .map((e) => HDataModel.fromJson(e as Map<String, dynamic>))
            .toSet();
        searchResult.addAll(list);
      } catch (e) {
        logger.e('Failed to load offline cache', error: e);
      }
    }

    try {
      await searchData();
    } catch (e) {
      logger.e('Initial search failed', error: e);
    } finally {
      isSearching(false);
    }
    history.addAll(pref
            .getStringList(_historyKey)
            ?.map((e) =>
                HDataModel.fromJson(jsonDecode(e) as Map<String, dynamic>))
            .cast<HDataModel>() ??
        []);
    debounce(
      history,
      (_) => _saveHistoryToLocal(),
      time: 800.ms,
    );

    // Reports and Version
    // api.getAllReports...
    // api.getNewVersion...

    _startNewPostCheck();
  }

  void _startNewPostCheck() {
    _newPostCheckTimer?.cancel();
    _newPostCheckTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _checkNewPosts();
    });
  }

  void _markNewlyInsertedPosts(Iterable<HDataModel> posts) {
    final ids = posts
        .map((e) => e.id)
        .where((id) => id.isNotEmpty)
        .toSet();

    _clearInsertedPostsTimer?.cancel();
    newlyInsertedPostIds.assignAll(ids);

    if (ids.isNotEmpty) {
      _clearInsertedPostsTimer = Timer(const Duration(milliseconds: 1100), () {
        newlyInsertedPostIds.clear();
      });
    }
  }

  Future<void> _checkNewPosts() async {
    if (searchQuery.isNotEmpty) return;
    // Don't check if we are currently searching/refreshing
    if (isSearching.value) return;

    try {
      final pagination = await api.search('', '');

      // Check again if we started searching while waiting for api
      if (isSearching.value) return;

      if (pagination.nodes.isEmpty) return;

      // Remote non-pinned posts
      final remoteList = pagination.nodes.where((e) => !e.isPinned).toList();

      // Local non-pinned posts
      final localList = searchResult.where((e) => !e.isPinned).toList();

      if (localList.isEmpty) {
        // Only trigger update if we expect local list to be populated but it is empty
        // However, if searchResult was cleared by refreshSearchData, we should skip
        if (isSearching.value) return;

        // If we really have no local data (e.g. initial load failed?), then maybe we should sync
        // But usually this means a refresh is pending or happened.
        // Let's be safe: if local is empty, don't report "20 new posts" unless we are sure.
        return;
      }

      final localNewestCreatedAt = localList
          .map((e) => e.createdAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      final count = remoteList
          .where((e) => e.createdAt.isAfter(localNewestCreatedAt))
          .length;

      if (count > 0) {
        newPostCount.value = count;
      } else {
        newPostCount.value = 0;
      }
      hasContentChange.value = false;
    } catch (e) {
      // Silent error
    }
  }

  Future<void> showNewPosts() async {
    // Only applies to default feed mode.
    if (searchQuery.isNotEmpty) {
      await refreshSearchData();
      return;
    }

    // Reset timer to avoid polling conflicts while inserting new items.
    _startNewPostCheck();
    isSearching(true);
    try {
      final pagination = await api.search('', '');
      final existingIds = searchResult.map((e) => e.id).toSet();
      final inserted = pagination.nodes
          .where((e) => e.id.isNotEmpty && !existingIds.contains(e.id))
          .toList(growable: false);

      // Prepend latest first-page items while preserving current list,
      // so UI won't flash empty and feels smoother.
      final merged = <HDataModel>{};
      merged.addAll(pagination.nodes);
      merged.addAll(searchResult);
      searchResult.assignAll(merged);
      _markNewlyInsertedPosts(inserted);

      // Keep pagination progress if user has already loaded more pages.
      if (searchEndCur == null || searchEndCur!.isEmpty) {
        searchEndCur = pagination.endCursor;
        searchHasNextPage.value = pagination.hasNextPage;
      }

      // Keep offline cache in sync with latest merged list.
      try {
        final cacheList = searchResult.map((e) => e.toJson()).toList();
        box.write(_searchCacheKey, cacheList);
      } catch (e) {
        logger.e('Failed to save offline cache', error: e);
      }

      newPostCount.value = 0;
      hasContentChange.value = false;
    } finally {
      isSearching(false);
    }
  }

  Future<void> refreshUnreadNotificationCount() async {
    if (!isLogin.value) {
      unreadNotificationCount.value = 0;
      return;
    }
    try {
      final count = await api.getUnreadNotificationCount();
      unreadNotificationCount.value = count;
    } catch (_) {
      // Keep current unread count on transient failures.
    }
  }

  void decrementUnreadNotificationCount({int by = 1}) {
    final next = unreadNotificationCount.value - by;
    unreadNotificationCount.value = next < 0 ? 0 : next;
  }

  void clearUnreadNotificationCount() {
    unreadNotificationCount.value = 0;
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
      showToast('请先登录', isError: true);
      return;
    }
    final userId = user.value?.userId;
    final username = user.value?.login ?? '';
    if (userId == null || userId.isEmpty || username.isEmpty) {
      showToast('用户信息获取失败', isError: true);
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
        showToast('取消收藏失败', isError: true);
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
        showToast('收藏失败', isError: true);
      }
    }
  }

  final selectedIndex = 0.obs;
  final pageController = PageController();

  Future<void> animateToPage(int index, {bool animate = false}) {
    selectedIndex.value = index;
    if (animate) {
      return pageController.animateToPage(
        index,
        duration: 0.5.s,
        curve: Curves.ease,
      );
    } else {
      if (pageController.hasClients) {
        pageController.jumpToPage(index);
      } else {
        // Desktop/Compact mode where PageView is not used
        curPage.value = index;
      }
      return Future.value();
    }
  }

  bool isFetchPinDiscussions = true;
  final searchController = SearchController();

  late final refreshSearchData = throttle(() async {
    // 重置定时器，避免刷新时刚好触发轮询
    _startNewPostCheck();
    isSearching(true);
    try {
      logger.i('Refreshing search data...');
      searchHasNextPage.value = true;
      searchEndCur = null;
      searchCache.clear();
      HDataModel.discussionsCache.clear(); // 清空详情缓存
      _clearInsertedPostsTimer?.cancel();
      newlyInsertedPostIds.clear();
      searchResult.clear();
      newPostCount.value = 0;
      hasContentChange.value = false;
      await searchData();
      logger.i('Refreshed. Result count: ${searchResult.length}');
    } finally {
      isSearching(false);
    }
  }, Duration.zero);

  final searchCache = <String?>{};
  Future<void> searchData() async {
    if (searchHasNextPage.isFalse || searchCache.contains(searchEndCur)) return;
    searchCache.add(searchEndCur);

    final isFirstPage = searchEndCur == null || searchEndCur!.isEmpty;

    final pagination = await api.search(searchQuery(), searchEndCur ?? '');
    // pagination returns PaginationModel<HDataModel>
    // destructure:
    searchEndCur = pagination.endCursor;
    searchHasNextPage.value = pagination.hasNextPage;

    if (isFirstPage) {
      searchResult.assignAll(pagination.nodes);
    } else {
      searchResult.addAll(pagination.nodes);
    }

    // Save to offline cache if this is the first page of default search
    if ((searchEndCur == null ||
            searchEndCur!.isEmpty ||
            searchEndCur == ApiConfig.defaultPageSize.toString()) &&
        searchQuery().isEmpty) {
      try {
        final cacheList = searchResult.map((e) => e.toJson()).toList();
        box.write(_searchCacheKey, cacheList);
      } catch (e) {
        logger.e('Failed to save offline cache', error: e);
      }
    }

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

  Future<bool> ensureLogin() async {
    if (isLogin.value) return true;
    final context = Get.context;
    if (context != null) {
      await showZZZDialog(
        context: context,
        pageBuilder: (context) => const LoginPage(),
      );
    }
    return isLogin.value;
  }

  Future<void> pickAndUploadAvatar() async {
    if (isLogin.isFalse) {
      if (!await ensureLogin()) return;
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

    final allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    final ext = file.name.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      showToast('不支持的文件格式，仅支持 JPEG, PNG, GIF, WEBP', isError: true);
      return;
    }

    isUploadingAvatar(true);
    try {
      final curUser = user.value;
      final targetAuthorId = authorId.value ??
          curUser?.authorId ??
          await ensureAuthorForUser(curUser);
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
        // Keep cache buster for uploaded avatar to force refresh
        final refreshed = _withCacheBuster(avatarUrl);
        current.avatar = refreshed;
        _cacheAvatarForUser(current, refreshed);
        user.refresh();
        await _refreshAvatarCaches(refreshed);
      }
      await refreshSelfUserInfo();
      showToast('头像已更新'.tr);
    } catch (e) {
      showToast('头像上传失败: $e', isError: true);
    } finally {
      isUploadingAvatar(false);
    }
  }

  Future<void> toggleArticleLike(DiscussionModel discussion) async {
    if (isLogin.isFalse) {
      if (!await ensureLogin()) return;
    }

    final oldLiked = discussion.liked;
    final oldCount = discussion.likesCount;

    // Optimistic update
    discussion.liked = !oldLiked;
    discussion.likesCount = oldLiked
        ? (oldCount > 0 ? oldCount - 1 : 0)
        : oldCount + 1;

    // Update cached discussion
    HDataModel.upsertCachedDiscussion(discussion);
    searchResult.refresh();
    bookmarks.refresh();
    history.refresh();

    try {
      final result = await api.toggleLike(
        targetType: 'article',
        targetId: discussion.id,
      );
      // Reconcile with server response
      discussion.liked = result.liked;
      discussion.likesCount = result.likesCount;
      HDataModel.upsertCachedDiscussion(discussion);
      searchResult.refresh();
      bookmarks.refresh();
      history.refresh();
    } catch (e) {
      // Rollback on error
      discussion.liked = oldLiked;
      discussion.likesCount = oldCount;
      HDataModel.upsertCachedDiscussion(discussion);
      searchResult.refresh();
      bookmarks.refresh();
      history.refresh();
      showToast('操作失败: $e', isError: true);
    }
  }

  Future<void> toggleCommentLike(CommentModel comment) async {
    if (isLogin.isFalse) {
      if (!await ensureLogin()) return;
    }

    final oldLiked = comment.liked;
    final oldCount = comment.likesCount;

    // Optimistic update
    comment.liked = !oldLiked;
    comment.likesCount = oldLiked
        ? (oldCount > 0 ? oldCount - 1 : 0)
        : oldCount + 1;

    try {
      final result = await api.toggleLike(
        targetType: 'comment',
        targetId: comment.id,
      );
      // Reconcile with server response
      comment.liked = result.liked;
      comment.likesCount = result.likesCount;
    } catch (e) {
      // Rollback on error
      comment.liked = oldLiked;
      comment.likesCount = oldCount;
      showToast('操作失败: $e', isError: true);
    }
  }

  Future<void> updateUsername(String newName) async {
    if (isLogin.isFalse) {
      showToast('请先登录', isError: true);
      return;
    }

    final curUser = user.value;
    if (curUser == null || curUser.userId == null) {
      showToast('用户信息异常', isError: true);
      return;
    }

    if (curUser.login == newName) return;

    try {
      // 1. Update User (username)
      final updatedUser = await api.updateUser(
        curUser.userId!,
        {'username': newName},
      );

      // 2. Update Author (name) if exists
      final authorIdVal = authorId.value ?? curUser.authorId;
      if (authorIdVal != null && authorIdVal.isNotEmpty) {
        try {
          await api.updateAuthor(
            authorId: authorIdVal,
            data: {'name': newName},
          );
        } catch (e) {
          logger.w('Failed to update Author name', error: e);
        }
      }

      // 3. Update local state
      updatedUser.avatar = curUser.avatar;
      user(updatedUser);
      await ensureAuthorForUser(updatedUser);

      showToast('用户名已更新');
    } catch (e) {
      logger.e('Update username failed', error: e);
      showToast('用户名更新失败: $e', isError: true);
    }
  }
}
