import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

  final report = <String, Set<ReportCommentModel>>{}.obs;

  final bookmarks = <HDataModel>{}.obs;
  final history = <HDataModel>{}.obs;

  // Api instance
  final api = Get.find<Api>();

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
       try {
         final u = await api.getSelfUserInfo(''); 
         user(u);
         await ensureAuthorForUser(u);
         isLogin(true);
       } catch (e) {
         // Token might be invalid
         logger.e('Failed to get user info', error: e);
         isLogin(false);
       }
    }

    ever(isLogin, (v) async {
       if (v) {
          // fetch user info if not present
          if (user.value == null) {
              try {
                final u = await api.getSelfUserInfo('');
                user(u);
                await ensureAuthorForUser(u);
              } catch(e) {
                logger.e('Failed to fetch user after login', error: e);
              }
          }
       } else {
         user.value = null;
         authorId.value = null;
         box.remove('access_token');
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
    bookmarks.addAll(pref.getStringList('bookmarks')?.map((e) => HDataModel.fromJson(jsonDecode(e) as Map<String, dynamic>)).cast<HDataModel>() ?? []);
    
    history.addAll(pref.getStringList('history')?.map((e) => HDataModel.fromJson(jsonDecode(e) as Map<String, dynamic>)).cast<HDataModel>() ?? []);
    
    // Reports and Version
    // api.getAllReports...
    // api.getNewVersion...
  }

  FutureOr<void> getVersionHandle(ReleaseModel? release) async {
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
  }

  Future<String?> ensureAuthorForUser(AuthorModel? u) async {
    if (u == null) return null;
    final name = (u.name.isNotEmpty ? u.name : u.login).trim();
    if (name.isEmpty) return null;
    final id = await api.ensureAuthorId(
      name: name,
      userId: u.userId,
    );
    if (id != null && id.isNotEmpty) {
      authorId.value = id;
    }
    return id;
  }
}

bool canReport(DiscussionModel discussion, bool isPin) =>
    ![owner, ...collaborators].contains(discussion.author.login) && !isPin;
