import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:inter_knot/api/api_exception.dart';
import 'package:inter_knot/constants/api_config.dart';
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/captcha.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/models/pagination.dart';
import 'package:inter_knot/controllers/data.dart';

String? _captchaErrorMessage(String? code) {
  switch (code) {
    case 'CAPTCHA_REQUIRED':
      return '请先完成验证码验证';
    case 'CAPTCHA_INVALID':
      return '验证码未通过，请重试';
    case 'CAPTCHA_VERIFY_FAILED':
      return '验证码服务异常，请稍后重试';
    case 'CAPTCHA_NOT_CONFIGURED':
      return '验证码服务未配置完成，请稍后再试';
    default:
      return null;
  }
}

class AuthApi extends GetConnect {
  @override
  void onInit() {
    httpClient.baseUrl = ApiConfig.baseUrl;
    httpClient.timeout = ApiConfig.timeout;
    httpClient.defaultContentType = 'application/json';
    if (kIsWeb) {
      // Browsers reject manually setting Content-Length.
      httpClient.sendContentLength = false;
      httpClient.addRequestModifier<dynamic>((request) {
        request.headers.remove('content-length');
        return request;
      });
    }
  }

  String _getErrorMessage(Response res) {
    String msg = res.statusText ?? 'Request failed';
    if (msg.contains('XMLHttpRequest error')) {
      return '短时间内请求数量过多';
    }
    try {
      if (res.body is Map && res.body['error'] != null) {
        final error = res.body['error'];
        if (error is Map) {
          msg = _captchaErrorMessage(error['code']?.toString()) ??
              error['message']?.toString() ??
              msg;
        } else if (error is String) {
          msg = error;
        }
      }
    } catch (_) {}
    return msg;
  }

  Map<String, dynamic> _withCaptcha(
    Map<String, dynamic> payload,
    CaptchaPayload? captcha,
  ) {
    if (captcha == null) return payload;
    return {
      ...payload,
      'captcha': captcha.toJson(),
    };
  }

  Future<({String? token, AuthorModel user})> login(
      String email, String password,
      {CaptchaPayload? captcha}) async {
    final res = await post(
      captcha == null ? '/api/auth/local' : '/api/auth/local-with-captcha',
      _withCaptcha({'identifier': email, 'password': password}, captcha),
    );

    if (res.hasError) {
      debugPrint('Login Error: ${res.statusCode} - ${res.bodyString}');
      throw ApiException(_getErrorMessage(res), statusCode: res.statusCode);
    }

    final body = res.body as Map<String, dynamic>;
    return (
      token: body['jwt'] as String?,
      user: AuthorModel.fromJson(body['user'] as Map<String, dynamic>)
    );
  }

  Future<({String? token, AuthorModel user})> register(
      String username, String email, String password,
      {CaptchaPayload? captcha}) async {
    final res = await post(
      captcha == null
          ? '/api/auth/local/register'
          : '/api/auth/register-with-captcha',
      _withCaptcha(
        {'username': username, 'email': email, 'password': password},
        captcha,
      ),
    );

    if (res.hasError) {
      debugPrint('Register Error: ${res.statusCode} - ${res.bodyString}');
      throw ApiException(_getErrorMessage(res), statusCode: res.statusCode);
    }

    final body = res.body as Map<String, dynamic>;
    return (
      token: body['jwt'] as String?,
      user: AuthorModel.fromJson(body['user'] as Map<String, dynamic>)
    );
  }
}

class BaseConnect extends GetConnect {
  static final authApi = Get.put(AuthApi());

  // 重试配置
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(milliseconds: 500);
  static const Duration _maxRetryDelay = Duration(seconds: 5);

  @override
  void onInit() {
    httpClient.baseUrl = ApiConfig.baseUrl;
    httpClient.timeout = ApiConfig.timeout;
    httpClient.defaultContentType = 'application/json';
    if (kIsWeb) {
      // package:get sets Content-Length for requests with bodies, which
      // browsers forbid us from sending manually.
      httpClient.sendContentLength = false;
    }
    httpClient.addRequestModifier<dynamic>((request) {
      if (kIsWeb) {
        request.headers.remove('content-length');
      }
      final token = box.read<String>('access_token') ?? '';
      final path = request.url.path;

      // Define public endpoints that should not send auth token to maximize cache hits
      // Matches /api/articles, /api/comments, /api/authors and their sub-paths
      // EXCEPT specific user-related endpoints like /api/articles/my
      final isPublicEndpoint =
          (path.startsWith('/api/articles') && !path.contains('/my')) ||
              (path.startsWith('/api/comments') && !path.contains('/likes')) ||
              path.startsWith('/api/authors');

      // Only attach token if it exists AND (it's not a GET request OR it's not a public endpoint)
      // This ensures POST/PUT/DELETE always get auth, but GET public data stays anonymous for caching
      if (token.isNotEmpty &&
          !(request.method.toUpperCase() == 'GET' && isPublicEndpoint)) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      return Future.value(request);
    });
    httpClient.addResponseModifier((req, rep) {
      if (rep.statusCode == 401) {
        // Token is invalid/expired
        box.remove('access_token');
        // Do NOT redirect to login page automatically, let the UI handle the unauthenticated state
        // or let the user choose to login again.
        // Get.offAll(() => const LoginPage());
      }
      return rep;
    });
  }

  bool _shouldRetry(Response? response, dynamic error) {
    if (response == null) return true;

    final code = response.statusCode;
    if (code != null) {
      final s = code.toString();
      if (s.startsWith('5') ||
          s.startsWith('6') ||
          s.startsWith('7') ||
          code == 429) {
        return true;
      }
    }

    String? message;
    try {
      final body = response.body;
      if (body is Map && body['error'] != null) {
        final error = body['error'];
        if (error is Map && error['message'] != null) {
          message = error['message'].toString();
        } else if (error is String) {
          message = error;
        }
      }
    } catch (_) {}

    message ??= response.statusText ?? '';

    if (message.contains('短时间内请求数量过多') ||
        message.contains('XMLHttpRequest error')) {
      return true;
    }

    return false;
  }

  Duration _calculateDelay(int attempt) {
    final delayMs = _baseRetryDelay.inMilliseconds * (1 << attempt);
    final clampedDelayMs = delayMs.clamp(
      _baseRetryDelay.inMilliseconds,
      _maxRetryDelay.inMilliseconds,
    );
    return Duration(milliseconds: clampedDelayMs);
  }

  Future<Response<T>> retryRequest<T>(
    Future<Response<T>> Function() requestFn, {
    String? operationName,
  }) async {
    int attempts = 0;

    while (true) {
      try {
        final response = await requestFn();

        if (!response.hasError || !_shouldRetry(response, null)) {
          return response;
        }

        attempts++;
        if (attempts > _maxRetries) {
          debugPrint(
              '${operationName ?? "Request"} failed after $_maxRetries retries');
          return response;
        }

        final delay = _calculateDelay(attempts - 1);
        debugPrint(
            '${operationName ?? "Request"} failed with ${response.statusCode}, '
            'retrying in ${delay.inMilliseconds}ms (attempt $attempts/$_maxRetries)');

        await Future.delayed(delay);
      } catch (e) {
        attempts++;
        if (attempts > _maxRetries) {
          debugPrint(
              '${operationName ?? "Request"} failed after $_maxRetries retries: $e');
          rethrow;
        }

        final delay = _calculateDelay(attempts - 1);
        debugPrint('${operationName ?? "Request"} error: $e, '
            'retrying in ${delay.inMilliseconds}ms (attempt $attempts/$_maxRetries)');

        await Future.delayed(delay);
      }
    }
  }

  Future<Response<T>> getWithRetry<T>(
    String url, {
    Map<String, String>? query,
    String? contentType,
    Map<String, String>? headers,
    String? operationName,
  }) async {
    return retryRequest(
      () =>
          get<T>(url, query: query, contentType: contentType, headers: headers),
      operationName: operationName ?? 'GET $url',
    );
  }

  Future<Response<T>> postWithRetry<T>(
    String url,
    dynamic body, {
    String? contentType,
    Map<String, String>? headers,
    Map<String, dynamic>? query,
    void Function(double)? uploadProgress,
    String? operationName,
  }) async {
    return retryRequest(
      () => post<T>(url, body,
          contentType: contentType,
          headers: headers,
          query: query,
          uploadProgress: uploadProgress),
      operationName: operationName ?? 'POST $url',
    );
  }

  Future<Response<T>> putWithRetry<T>(
    String url,
    dynamic body, {
    String? contentType,
    Map<String, String>? headers,
    Map<String, dynamic>? query,
    String? operationName,
  }) async {
    return retryRequest(
      () => put<T>(url, body,
          contentType: contentType, headers: headers, query: query),
      operationName: operationName ?? 'PUT $url',
    );
  }

  Future<Response<T>> deleteWithRetry<T>(
    String url, {
    String? contentType,
    Map<String, String>? headers,
    Map<String, dynamic>? query,
    String? operationName,
  }) async {
    return retryRequest(
      () => delete<T>(url,
          contentType: contentType, headers: headers, query: query),
      operationName: operationName ?? 'DELETE $url',
    );
  }

  /// Extracts 'data' from Strapi v5 response and handles errors
  T unwrapData<T>(Response response) {
    if (response.hasError) {
      debugPrint('API Error: ${response.statusCode} - ${response.bodyString}');
      final body = response.body;
      String? message = response.statusText;

      if (body is Map) {
        final error = body['error'];
        if (error is Map) {
          message = _captchaErrorMessage(error['code']?.toString()) ??
              error['message']?.toString();
        } else if (error is String) {
          message = error;
        }
      }

      final code = response.statusCode;
      if (code != null) {
        final s = code.toString();
        if (s.startsWith('5') || s.startsWith('6') || s.startsWith('7')) {
          message = '短时间内请求数量过多';
        }
      }

      if (message != null && message.contains('XMLHttpRequest error')) {
        message = '短时间内请求数量过多';
      }

      throw ApiException(message ?? 'Unknown error',
          statusCode: response.statusCode, details: response.body);
    }

    final body = response.body;
    if (body is Map<String, dynamic>) {
      if (body.containsKey('data')) {
        return body['data'] as T;
      }
      return body as T;
    }
    return body as T;
  }
}

// Top-level function for compute
DiscussionModel _parseDiscussionSync(Map<String, dynamic> data) {
  return parseDiscussionData(data);
}

DiscussionModel _parseEditableDraftDiscussionSync(Map<String, dynamic> data) {
  return parseDiscussionData(
    data,
    isEditableDraft: true,
  );
}

({List<HDataModel> nodes, List<DiscussionModel> discussions})
    _parseHDataListAndDiscussionsSync(List<dynamic> data) {
  final nodes = <HDataModel>[];
  final discussions = <DiscussionModel>[];

  for (final e in data) {
    if (e is! Map<String, dynamic>) continue;
    try {
      final hData = HDataModel.fromMap(e);
      nodes.add(hData);

      if (e['title'] != null) {
        final discussion = DiscussionModel.fromJson(e);
        discussions.add(discussion);
      }
    } catch (_) {
      // ignore
    }
  }
  return (nodes: nodes, discussions: discussions);
}

({List<HDataModel> nodes, List<DiscussionModel> discussions})
    _parseEditableDraftListAndDiscussionsSync(List<dynamic> data) {
  final nodes = <HDataModel>[];
  final discussions = <DiscussionModel>[];

  for (final e in data) {
    if (e is! Map<String, dynamic>) continue;
    try {
      final hData = HDataModel.fromMap(
        e,
        isEditableDraft: true,
      );
      nodes.add(hData);

      if (e['title'] != null) {
        final discussion = DiscussionModel.fromJson(
          e,
          isEditableDraft: true,
        );
        discussions.add(discussion);
      }
    } catch (_) {
      // ignore
    }
  }

  return (nodes: nodes, discussions: discussions);
}

List<CommentModel> _parseCommentListSync(List<dynamic> data) {
  return data.cast<Map<String, dynamic>>().map(CommentModel.fromJson).toList();
}

class Api extends BaseConnect {
  String? _normalizeFileUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '${ApiConfig.baseUrl}$url';
  }

  Map<String, dynamic> _withCaptcha(
    Map<String, dynamic> payload,
    CaptchaPayload? captcha,
  ) {
    if (captcha == null) return payload;
    return {
      ...payload,
      'captcha': captcha.toJson(),
    };
  }

  String _contentTypeFromFilename(String filename) {
    final ext = filename.toLowerCase();
    if (ext.endsWith('.png')) return 'image/png';
    if (ext.endsWith('.webp')) return 'image/webp';
    if (ext.endsWith('.gif')) return 'image/gif';
    if (ext.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }

  Future<CaptchaConfigModel> getCaptchaConfig() async {
    final res = await get('/api/captcha/config');
    final body = unwrapData<Map<String, dynamic>>(res);
    return CaptchaConfigModel.fromJson(body);
  }

  String _slugify(String input, {bool ensureUnique = false}) {
    final normalized = input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp('-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    var slug = normalized.isEmpty ? 'author' : normalized;

    if (ensureUnique) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      slug = '$slug-$timestamp';
    }

    return slug;
  }

  Object _coerceId(String value) {
    final asInt = int.tryParse(value);
    return asInt ?? value;
  }

  Future<void> _mergeReadStatus(List<dynamic> data,
      {required String tag}) async {
    final userId = box.read<String>('userId');
    if (userId == null || userId.isEmpty || data.isEmpty) return;

    final ids = <String>[];
    for (final item in data) {
      if (item is Map) {
        final id = item['documentId'];
        if (id != null) ids.add(id.toString());
      }
    }
    if (ids.isEmpty) return;

    try {
      final readRes = await post(
        '/api/article-reads/batch',
        {
          'articleDocumentIds': ids,
        },
      );
      final readList = unwrapData<List<dynamic>>(readRes);
      final readMap = <String, bool>{};
      for (final r in readList) {
        if (r is Map) {
          final articleId = r['articleDocumentId'];
          final isRead = r['isRead'] == true;
          if (isRead && articleId != null) {
            readMap[articleId.toString()] = true;
          }
        }
      }

      if (readMap.isEmpty) return;

      for (final d in data) {
        if (d is Map) {
          final id = d['documentId'];
          if (id != null && readMap.containsKey(id.toString())) {
            d['isRead'] = true;
          }
        }
      }
    } catch (e) {
      debugPrint('$tag Read Status Error: $e');
    }
  }

  Future<DiscussionModel> getDiscussion(String id) async {
    final userId = box.read<String>('userId');

    final articleFuture = get('/api/articles/detail/$id');

    Future<Response>? readStatusFuture;
    if (userId != null && userId.isNotEmpty) {
      readStatusFuture = post(
        '/api/article-reads/batch',
        {
          'articleDocumentIds': [id],
        },
      );
    }

    final token = box.read<String>('access_token') ?? '';
    Future<Map<String, bool>>? likedFuture;
    if (token.isNotEmpty) {
      likedFuture = batchCheckLikes(
        targetType: 'article',
        targetIds: [id],
      );
    }

    final res = await articleFuture;
    final data = unwrapData<Map<String, dynamic>>(res);

    if (readStatusFuture != null) {
      try {
        final readRes = await readStatusFuture;
        final readData = unwrapData<List<dynamic>>(readRes);
        if (readData.isNotEmpty) {
          final first = readData.first;
          if (first is Map) {
            final isRead = first['isRead'] == true;
            data['isRead'] = isRead;
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch read status: $e');
      }
    }

    if (likedFuture != null) {
      try {
        final likedMap = await likedFuture;
        if (likedMap.containsKey(id)) {
          data['liked'] = likedMap[id];
        }
      } catch (e) {
        debugPrint('Failed to fetch liked status: $e');
      }
    }

    final discussion = await compute(_parseDiscussionSync, data);
    final controller = Get.find<Controller>();
    controller.applyLocalOverrides(discussion);
    HDataModel.upsertCachedDiscussion(discussion);
    return discussion;
  }

  Future<DiscussionModel> getMyDraftDetail(String documentId) async {
    final res = await get('/api/articles/my/$documentId');
    final data = unwrapData<Map<String, dynamic>>(res);

    final discussion = await compute(_parseEditableDraftDiscussionSync, data);
    final controller = Get.find<Controller>();
    controller.applyLocalOverrides(discussion);

    final user = controller.user.value;
    if (discussion.author.authorId == null ||
        discussion.author.authorId!.isEmpty ||
        discussion.author.name == 'Unknown') {
      discussion.author
        ..name = user?.name ?? user?.login ?? discussion.author.name
        ..login = user?.login ?? discussion.author.login
        ..avatar = user?.avatar ?? discussion.author.avatar
        ..authorId = controller.authorId.value ??
            user?.authorId ??
            discussion.author.authorId;
    }

    HDataModel.upsertCachedDiscussion(discussion);
    return discussion;
  }

  Future<DiscussionModel> getArticleDetail(String documentId) async {
    final res = await get('/api/articles/detail/$documentId');
    final data = unwrapData<Map<String, dynamic>>(res);

    final token = box.read<String>('access_token') ?? '';
    if (token.isNotEmpty) {
      try {
        final likedMap = await batchCheckLikes(
          targetType: 'article',
          targetIds: [documentId],
        );
        if (likedMap.containsKey(documentId)) {
          data['liked'] = likedMap[documentId];
        }
      } catch (e) {
        debugPrint('ArticleDetail Liked Status Error: $e');
      }
    }

    return _parseDiscussionSync(data);
  }

  Future<void> viewArticle(String id) async {
    await post('/api/articles/$id/view', {});
  }

  Future<
      ({
        int exp,
        int level,
        String? lastCheckInDate,
        int? consecutiveCheckInDays,
        DateTime? nextEligibleAtUtc,
        bool canCheckIn,
      })> getMyExp() async {
    final res = await get('/api/me/exp');

    if (res.hasError) {
      throw ApiException(res.statusText ?? 'Failed to fetch exp',
          statusCode: res.statusCode, details: res.bodyString);
    }

    final body = res.body;
    if (body is! Map) {
      throw ApiException('Invalid exp response');
    }

    return (
      exp: (body['exp'] as num?)?.toInt() ?? 0,
      level: (body['level'] as num?)?.toInt() ?? 1,
      lastCheckInDate: body['lastCheckInDate']?.toString(),
      consecutiveCheckInDays: (body['consecutiveCheckInDays'] as num?)?.toInt(),
      nextEligibleAtUtc: DateTime.tryParse(
        body['nextEligibleAt']?.toString() ?? '',
      )?.toUtc(),
      canCheckIn: body['canCheckIn'] as bool? ?? true,
    );
  }

  Future<PaginationModel<HDataModel>> search(
      String query, String endCur) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    if (query.isEmpty) {
      final res = await get(
        '/api/articles/list',
        query: {
          'start': start.toString(),
          'limit': ApiConfig.defaultPageSize.toString(),
        },
      );

      final data = unwrapData<List<dynamic>>(res);

      await _mergeReadStatus(data, tag: 'Search');

      final hasNext = data.length >= ApiConfig.defaultPageSize;

      final result = await compute(_parseHDataListAndDiscussionsSync, data);

      final controller = Get.find<Controller>();
      for (final discussion in result.discussions) {
        controller.applyLocalOverrides(discussion);
        HDataModel.upsertCachedDiscussion(discussion);
      }

      return PaginationModel(
        nodes: result.nodes,
        endCursor: (start + ApiConfig.defaultPageSize).toString(),
        hasNextPage: hasNext,
      );
    }

    final res = await get(
      '/api/articles/search',
      query: {
        'q': query,
        'start': start.toString(),
        'limit': ApiConfig.defaultPageSize.toString(),
      },
    );

    final data = unwrapData<List<dynamic>>(res);

    await _mergeReadStatus(data, tag: 'Search');

    final hasNext = data.length >= ApiConfig.defaultPageSize;

    final result = await compute(_parseHDataListAndDiscussionsSync, data);

    final controller = Get.find<Controller>();
    for (final discussion in result.discussions) {
      controller.applyLocalOverrides(discussion);
      HDataModel.upsertCachedDiscussion(discussion);
    }

    return PaginationModel(
      nodes: result.nodes,
      endCursor: (start + ApiConfig.defaultPageSize).toString(),
      hasNextPage: hasNext,
    );
  }

  Future<PaginationModel<HDataModel>> getUserDiscussions(
      String authorId, String endCur) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    final currentAuthorId = Get.find<Controller>().authorId.value;

    if (currentAuthorId == authorId) {
      final res = await get(
        '/api/articles/my',
        query: {
          'start': start.toString(),
          'limit': ApiConfig.defaultPageSize.toString(),
        },
      );

      final data = unwrapData<List<dynamic>>(res);
      final hasNext = data.length >= ApiConfig.defaultPageSize;
      final result =
          await compute(_parseEditableDraftListAndDiscussionsSync, data);

      final controller = Get.find<Controller>();
      for (final discussion in result.discussions) {
        controller.applyLocalOverrides(discussion);
        final user = controller.user.value;
        if (discussion.author.authorId == null ||
            discussion.author.authorId!.isEmpty ||
            discussion.author.name == 'Unknown') {
          discussion.author
            ..name = user?.name ?? user?.login ?? discussion.author.name
            ..login = user?.login ?? discussion.author.login
            ..avatar = user?.avatar ?? discussion.author.avatar
            ..authorId = controller.authorId.value ??
                user?.authorId ??
                discussion.author.authorId;
        }
        HDataModel.upsertCachedDiscussion(discussion);
      }

      return PaginationModel(
        nodes: result.nodes,
        endCursor: (start + ApiConfig.defaultPageSize).toString(),
        hasNextPage: hasNext,
      );
    }

    final queryParams = <String, dynamic>{
      'pagination[start]': start.toString(),
      'pagination[limit]': ApiConfig.defaultPageSize.toString(),
      'sort': 'updatedAt:desc',
      'filters[author][documentId][\$eq]': authorId,
      'populate[author][populate]': 'avatar',
      'populate[cover][fields][0]': 'url',
      'populate[cover][fields][1]': 'width',
      'populate[cover][fields][2]': 'height',
      'populate[blocks][populate]': '*',
    };

    final res = await get(
      '/api/articles',
      query: queryParams,
    );

    final data = unwrapData<List<dynamic>>(res);

    await _mergeReadStatus(data, tag: 'UserDiscussions');

    final hasNext = data.length >= ApiConfig.defaultPageSize;

    final result = await compute(_parseHDataListAndDiscussionsSync, data);

    final controller = Get.find<Controller>();
    for (final discussion in result.discussions) {
      controller.applyLocalOverrides(discussion);
      HDataModel.upsertCachedDiscussion(discussion);
    }

    return PaginationModel(
      nodes: result.nodes,
      endCursor: (start + ApiConfig.defaultPageSize).toString(),
      hasNextPage: hasNext,
    );
  }

  Future<int> getUserDiscussionCount(String authorId) async {
    final res = await get(
      '/api/articles',
      query: {
        'filters[author][documentId][\$eq]': authorId,
        'pagination[limit]': '1',
        'fields[0]': 'documentId',
      },
    );

    if (res.hasError) return 0;

    final body = res.body;
    if (body is Map<String, dynamic>) {
      final meta = body['meta'];
      if (meta is Map<String, dynamic>) {
        final pagination = meta['pagination'];
        if (pagination is Map<String, dynamic>) {
          return pagination['total'] as int? ?? 0;
        }
      }
    }
    return 0;
  }

  Future<int> getCommentCount(String discussionId) async {
    final res = await get(
      '/api/comments/count',
      query: {
        'article': discussionId,
      },
    );

    if (res.hasError) return 0;

    final body = res.body;
    if (body is Map<String, dynamic>) {
      return body['count'] as int? ?? 0;
    }
    return 0;
  }

  Future<PaginationModel<CommentModel>> getComments(
      String id, String endCur) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    final queryParams = {
      'article': id,
      'start': start.toString(),
      'limit': ApiConfig.defaultPageSize.toString(),
      'ts': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    final res = await get(
      '/api/comments/list',
      query: queryParams,
    );

    final data = unwrapData<List<dynamic>>(res);
    final comments = await compute(_parseCommentListSync, data);

    // Batch check liked status for comments
    try {
      final token = box.read<String>('access_token') ?? '';
      if (token.isNotEmpty && comments.isNotEmpty) {
        final allIds = <String>[];
        for (final c in comments) {
          allIds.add(c.id);
          for (final r in c.replies) {
            allIds.add(r.id);
          }
        }
        if (allIds.isNotEmpty) {
          final likedMap = await batchCheckLikes(
            targetType: 'comment',
            targetIds: allIds,
          );
          if (likedMap.isNotEmpty) {
            for (final c in comments) {
              if (likedMap.containsKey(c.id)) c.liked = likedMap[c.id]!;
              for (final r in c.replies) {
                if (likedMap.containsKey(r.id)) r.liked = likedMap[r.id]!;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Comment Liked Status Error: $e');
    }

    final hasNextPage = comments.length >= ApiConfig.defaultPageSize;
    final nextEndCur =
        hasNextPage ? (start + ApiConfig.defaultPageSize).toString() : null;

    return PaginationModel(
      nodes: comments,
      hasNextPage: hasNextPage,
      endCursor: nextEndCur,
    );
  }

  Future<Response<Map<String, dynamic>>> addDiscussionComment(
    String discussionId,
    String body, {
    String? authorId,
    String? parentId,
    CaptchaPayload? captcha,
  }) {
    if (discussionId.isEmpty) {
      throw ApiException('Discussion ID cannot be empty');
    }

    debugPrint(
        'Adding comment to discussion: $discussionId, author: $authorId, parent: $parentId');

    final data = <String, dynamic>{
      'article': discussionId,
      'content': body,
      if (authorId != null && authorId.isNotEmpty) 'author': authorId,
      if (parentId != null && parentId.isNotEmpty) 'parent': parentId,
    };

    return post(
      '/api/comments',
      _withCaptcha({'data': data}, captcha),
    );
  }

  Future<({List<HDataModel> items, Map<String, String> favoriteIds})>
      getFavorites(String username, String endCur) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    final res = await get(
      '/api/favorites/list',
      query: {
        'start': start.toString(),
        'limit': ApiConfig.defaultPageSize.toString(),
      },
    );

    List<dynamic> list;
    try {
      list = unwrapData<List<dynamic>>(res);
    } catch (e) {
      return (items: <HDataModel>[], favoriteIds: <String, String>{});
    }

    final items = <HDataModel>[];
    final favoriteIds = <String, String>{};

    for (final entry in list) {
      if (entry is! Map) continue;
      final favoriteId = entry['documentId']?.toString();
      final article = entry['article'];

      if (article is Map<String, dynamic>) {
        final hData = HDataModel.fromJson(article);
        if (hData.id.isNotEmpty) {
          items.add(hData);
          if (favoriteId != null && favoriteId.isNotEmpty) {
            favoriteIds[hData.id] = favoriteId;
          }
        }
      }
    }
    return (items: items, favoriteIds: favoriteIds);
  }

  Future<String?> getFavoriteId({
    required String username,
    required String articleId,
  }) async {
    final res = await get(
      '/api/favorites',
      query: {
        'filters[user][username][\$eq]': username,
        'filters[article][documentId][\$eq]': articleId,
        'pagination[limit]': '1',
      },
    );

    try {
      final list = unwrapData<List<dynamic>>(res);
      if (list.isNotEmpty) {
        final first = list.first;
        if (first is Map) {
          return first['documentId']?.toString();
        }
      }
    } catch (e) {
      debugPrint('GetFavoriteId Error: $e');
    }
    return null;
  }

  Future<String?> createFavorite({
    required String userId,
    required String articleId,
  }) async {
    final res = await post(
      '/api/favorites',
      {
        'data': {
          'user': _coerceId(userId),
          'article': articleId,
        },
      },
    );

    try {
      final data = unwrapData<Map<String, dynamic>>(res);
      return data['documentId']?.toString();
    } catch (e) {
      debugPrint('CreateFavorite Error: $e');
      return null;
    }
  }

  Future<bool> deleteFavorite(String favoriteId) async {
    final res = await delete('/api/favorites/$favoriteId');
    return !res.hasError;
  }

  dynamic _normalizeArticleCover(dynamic coverId) {
    if (coverId == null) return null;

    if (coverId is String) {
      if (coverId.isEmpty) return null;
      return _coerceId(coverId);
    }

    if (coverId is List) {
      final normalized = coverId
          .map((e) => e is String ? _coerceId(e) : e)
          .where((e) => e != null && e.toString().isNotEmpty)
          .toList();
      return normalized;
    }

    return coverId;
  }

  Future<Response<Map<String, dynamic>>> createArticleDraft({
    String title = '',
    String text = '',
    List<dynamic>? editorState,
    dynamic coverId,
    String? authorId,
  }) {
    final Map<String, dynamic> data = {
      'title': title,
      'text': text,
      'editorState': editorState,
    };

    final normalizedCover = _normalizeArticleCover(coverId);
    if (normalizedCover != null) {
      data['cover'] = normalizedCover;
    }

    if (authorId != null && authorId.isNotEmpty) {
      data['author'] = _coerceId(authorId);
    }

    return post(
      '/api/articles',
      {'data': data},
      query: {'status': 'draft'},
    );
  }

  Future<Response<Map<String, dynamic>>> updateArticleDraft({
    required String id,
    String? title,
    String? text,
    List<dynamic>? editorState,
    dynamic coverId,
    String? authorId,
  }) {
    final Map<String, dynamic> data = {};
    if (title != null) data['title'] = title;
    if (text != null) data['text'] = text;
    data['editorState'] = editorState;
    final normalizedCover = _normalizeArticleCover(coverId);
    if (coverId is List && coverId.isEmpty) {
      data['cover'] = [];
    } else if (normalizedCover != null) {
      data['cover'] = normalizedCover;
    }
    if (authorId != null && authorId.isNotEmpty) {
      data['author'] = _coerceId(authorId);
    }

    return put(
      '/api/articles/$id',
      {'data': data},
      query: {'status': 'draft'},
    );
  }

  Future<Response<Map<String, dynamic>>> publishArticleDraft({
    required String id,
    CaptchaPayload? captcha,
  }) {
    return post(
      '/api/articles/$id/publish',
      _withCaptcha(<String, dynamic>{}, captcha),
    );
  }

  Future<Response<Map<String, dynamic>>> unpublishArticleDraft(
    String id, {
    bool discardDraft = false,
  }) {
    return post(
      '/api/articles/$id/unpublish',
      {
        'discardDraft': discardDraft,
      },
    );
  }

  Future<String?> findAuthorIdByName(String name) async {
    final res = await get(
      '/api/authors',
      query: {
        'filters[name][\$eq]': name,
        'pagination[limit]': '1',
      },
    );

    try {
      final list = unwrapData<List<dynamic>>(res);
      if (list.isNotEmpty) {
        final first = list.first;
        if (first is Map) {
          return first['documentId'] as String?;
        }
      }
    } catch (e) {
      debugPrint('FindAuthor Error: $e');
    }
    return null;
  }

  Future<String?> createAuthor({
    required String name,
    String? userId,
    bool ensureUniqueSlug = false,
  }) async {
    final slug = _slugify(name, ensureUnique: ensureUniqueSlug);
    final res = await post(
      '/api/authors',
      {
        'data': {
          'name': name,
          'slug': slug,
        },
      },
    );

    if (res.hasError) {
      // Simple retry logic for slug conflict if needed,
      // but strictly we should check the error message.
      if (res.bodyString?.contains('unique') == true) {
        debugPrint('Slug conflict detected, retrying find by name');
        await Future.delayed(const Duration(milliseconds: 300));
        return await findAuthorIdByName(name);
      }
    }

    try {
      final data = unwrapData<Map<String, dynamic>>(res);
      return data['documentId'] as String?;
    } catch (e) {
      debugPrint('CreateAuthor Error: $e');
      return null;
    }
  }

  Future<void> linkAuthorToUser({
    required String authorId,
    required String userId,
  }) async {
    final res = await put(
      '/api/authors/$authorId',
      {
        'data': {
          'user': _coerceId(userId),
        },
      },
    );
    if (res.hasError) {
      debugPrint('UpdateAuthor Error: ${res.bodyString}');
    }
  }

  Future<void> updateAuthor({
    required String authorId,
    required Map<String, dynamic> data,
  }) async {
    final res = await put(
      '/api/authors/$authorId',
      {'data': data},
    );
    if (res.hasError) {
      debugPrint('UpdateAuthorGeneric Error: ${res.bodyString}');
      throw ApiException(res.statusText ?? 'Update author failed');
    }
  }

  Future<String?> ensureAuthorId({
    required String name,
    String? userId,
  }) async {
    var existingId = await findAuthorIdByName(name);
    if (existingId != null && existingId.isNotEmpty) return existingId;

    // Exponential backoff
    int delay = 200;
    for (int i = 0; i < 3; i++) {
      await Future.delayed(Duration(milliseconds: delay));
      existingId = await findAuthorIdByName(name);
      if (existingId != null && existingId.isNotEmpty) return existingId;
      delay *= 2; // 200, 400, 800
    }

    debugPrint('Warning: Author not found after retries, creating as fallback');
    return createAuthor(name: name, ensureUniqueSlug: true);
  }

  Future<Response<Map<String, dynamic>>> deleteComment(String id) =>
      delete('/api/comments/$id');

  Future<Response<Map<String, dynamic>>> deleteDiscussion(String id) =>
      delete('/api/articles/$id');

  Future<PaginationModel<HDataModel>> getPinnedDiscussions(String? endCur) {
    // Reusing search/list endpoint with isPinned=true filter
    final start = int.tryParse(endCur?.isEmpty == true ? '0' : endCur!) ?? 0;

    final queryParams = <String, dynamic>{
      'pagination[start]': start.toString(),
      'pagination[limit]': ApiConfig.defaultPageSize.toString(),
      'sort[0]': 'updatedAt:desc',
      'filters[isPinned][\$eq]': 'true',
      'populate[author][populate]': 'avatar',
      'populate[cover][fields][0]': 'url',
      'populate[cover][fields][1]': 'width',
      'populate[cover][fields][2]': 'height',
      'populate[blocks][populate]': '*',
    };

    return get(
      '/api/articles',
      query: queryParams.map((k, v) => MapEntry(k, v.toString())),
    ).then((res) {
      final data = unwrapData<List<dynamic>>(res);
      final hasNext = data.length >= ApiConfig.defaultPageSize;
      return PaginationModel(
        nodes: data
            .map((e) => HDataModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        endCursor: (start + ApiConfig.defaultPageSize).toString(),
        hasNextPage: hasNext,
      );
    });
  }

  Future<void> _fetchAndSetAvatar(AuthorModel user) async {
    if (user.avatar.isEmpty &&
        user.authorId != null &&
        user.authorId!.isNotEmpty) {
      try {
        final url = await getAuthorAvatarUrl(user.authorId!);
        if (url != null && url.isNotEmpty) {
          user.avatar = url;
        }
      } catch (_) {
        // Ignore avatar fetch errors
      }
    }
  }

  Future<AuthorModel> getSelfUserInfo(String login) async {
    // /api/users/me returns the user directly
    final res = await get(
      '/api/users/me',
      query: {'populate': '*'},
    );

    final data = unwrapData<Map<String, dynamic>>(res);
    final user = AuthorModel.fromJson(data);
    await _fetchAndSetAvatar(user);
    return user;
  }

  Future<AuthorModel> updateUser(
      String userId, Map<String, dynamic> data) async {
    final res = await put(
      '/api/users/$userId',
      data,
    );

    final body = unwrapData<Map<String, dynamic>>(res);
    final user = AuthorModel.fromJson(body);
    return user;
  }

  Future<AuthorModel> getUserInfo(String username) async {
    // We need to search for the user by username
    final res = await get(
      '/api/users',
      query: {
        'filters[username][\$eq]': username,
        'populate': '*',
      },
    );

    final list = unwrapData<List<dynamic>>(res);
    if (list.isEmpty) throw ApiException('User not found');

    final user = AuthorModel.fromJson(list.first as Map<String, dynamic>);
    await _fetchAndSetAvatar(user);
    return user;
  }

  Future<String?> getAuthorAvatarUrl(String authorId) async {
    final res = await get(
      '/api/authors/$authorId',
      query: {'populate': 'avatar'},
    );
    final authorData = unwrapData<Map<String, dynamic>>(res);
    String? url = AuthorModel.extractAvatarUrl(authorData['avatar']);
    if (url != null && !url.startsWith('http')) {
      url = '${ApiConfig.baseUrl}$url';
    }
    return url;
  }

  Future<void> markAsRead(String articleId) async {
    final userId = box.read<String>('userId');
    if (userId == null || userId.isEmpty) return;

    // Check if exists
    final checkRes = await get(
      '/api/article-reads',
      query: {
        'filters[user][id][\$eq]': userId,
        'filters[article][documentId][\$eq]': articleId,
        'fields[0]': 'isRead',
        'fields[1]': 'documentId',
      },
    );

    try {
      final list = unwrapData<List<dynamic>>(checkRes);
      if (list.isNotEmpty) {
        final item = list.first as Map;
        final isRead = item['isRead'] == true;
        final docId = item['documentId'] as String?;
        if (!isRead && docId != null) {
          // Update
          await put(
            '/api/article-reads/$docId',
            {
              'data': {'isRead': true}
            },
          );
        }
      } else {
        // Create
        await post(
          '/api/article-reads',
          {
            'data': {
              'user': _coerceId(userId),
              'article': articleId,
              'isRead': true,
            }
          },
        );
      }
    } catch (e) {
      debugPrint('MarkAsRead Error: $e');
    }
  }

  Future<
      ({
        String message,
        int? reward,
        int? consecutiveDays,
        int? rank,
        int? currentExp,
        int? currentLevel,
      })> checkIn({CaptchaPayload? captcha}) async {
    final res = await post(
      '/api/check-in',
      captcha == null ? <String, dynamic>{} : {'captcha': captcha.toJson()},
    );

    if (res.hasError) {
      String errorMessage = '签到失败';
      dynamic details;
      if (res.body is Map) {
        final error = res.body['error'];
        if (error is Map) {
          final code = error['code']?.toString();
          details = error['details'] ?? res.body;

          final captchaMessage = _captchaErrorMessage(code);
          if (captchaMessage != null) {
            errorMessage = captchaMessage;
          } else if (code == 'CHECK_IN_ALREADY_TODAY') {
            errorMessage = '今日已签到';
          } else if (error['message'] == 'Already checked in today.') {
            // Backward compatibility for old backend message.
            errorMessage = '今日已签到';
          }
        }
      }
      throw ApiException(
        errorMessage,
        statusCode: res.statusCode,
        details: details,
      );
    }

    final body = res.body as Map<String, dynamic>;
    return (
      message: body['message'] as String? ?? '签到成功',
      reward: body['reward'] as int?,
      consecutiveDays: body['consecutiveDays'] as int?,
      rank: (body['rank'] as num?)?.toInt(),
      currentExp: (body['currentExp'] as num?)?.toInt(),
      currentLevel: (body['currentLevel'] as num?)?.toInt(),
    );
  }

  Future<String?> uploadAvatar({
    required String authorId,
    required List<int> bytes,
    required String filename,
    String? contentType,
  }) async {
    final result = await uploadImageDirect(
      bytes: bytes,
      filename: filename,
      mimeType: contentType ?? _contentTypeFromFilename(filename),
      path: 'avatars',
      onProgress: (_) {}, // 头像上传不需要进度回调
    );

    if (result == null) {
      throw ApiException('Upload failed');
    }

    final rawAvatarId = result['id'];
    if (rawAvatarId == null) {
      throw ApiException('Upload response missing file id');
    }
    final uploadedUrl = _normalizeFileUrl(result['url'] as String?);

    // Update Author with new avatar
    final updateRes = await put(
      '/api/authors/$authorId',
      {
        'data': {
          'avatar': _coerceId(rawAvatarId.toString()),
        },
      },
    );

    if (updateRes.hasError) {
      throw ApiException(updateRes.bodyString ??
          updateRes.statusText ??
          'Failed to bind avatar');
    }

    if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
      return uploadedUrl;
    }

    try {
      return await getAuthorAvatarUrl(authorId);
    } catch (_) {
      return null;
    }
  }

  /// 直传图片到对象存储
  ///
  /// [bytes] - 图片二进制数据
  /// [filename] - 文件名
  /// [mimeType] - MIME 类型，如 'image/png'
  /// [path] - 存储路径，如 'avatars', 'editor'
  /// [onProgress] - 进度回调，参数为 0-100
  Future<Map<String, dynamic>?> uploadImageDirect({
    required List<int> bytes,
    required String filename,
    required String mimeType,
    String path = 'editor',
    required void Function(int percent) onProgress,
  }) async {
    final token = box.read<String>('access_token') ?? '';
    final authHeaders = token.isNotEmpty
        ? {'Authorization': 'Bearer $token'}
        : <String, String>{};

    // 1. 获取签名
    final signRes = await postWithRetry(
      '/api/direct-upload/sign',
      {
        'filename': filename,
        'mimeType': mimeType,
        'size': bytes.length,
        'path': path,
        'fileInfo': {
          'name': filename,
          'alternativeText': filename,
        },
      },
      headers: authHeaders,
      operationName: 'DirectUpload Sign',
    );

    if (signRes.hasError) {
      throw ApiException(
        signRes.statusText ?? '获取上传签名失败',
        statusCode: signRes.statusCode,
      );
    }

    final signData = unwrapData<Map<String, dynamic>>(signRes);
    final uploadUrl = signData['uploadUrl'] as String;
    final uploadToken = signData['uploadToken'] as String;
    final headers = (signData['headers'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v.toString())) ??
        <String, String>{};

    onProgress(10);

    // 2. 直传到对象存储（使用原始字节流）
    try {
      final uploadResp = await http.put(
        Uri.parse(uploadUrl),
        headers: headers,
        body: bytes,
      );

      if (uploadResp.statusCode != 200 && uploadResp.statusCode != 204) {
        throw ApiException(
          '上传到对象存储失败: ${uploadResp.statusCode} ${uploadResp.body}',
          statusCode: uploadResp.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('上传到对象存储失败: $e');
    }

    onProgress(80);

    // 3. 完成上传
    final completeRes = await postWithRetry(
      '/api/direct-upload/complete',
      {
        'uploadToken': uploadToken,
      },
      headers: authHeaders,
      operationName: 'DirectUpload Complete',
    );

    if (completeRes.hasError) {
      throw ApiException(
        completeRes.statusText ?? '完成上传失败',
        statusCode: completeRes.statusCode,
      );
    }

    onProgress(100);

    final completeData = unwrapData<Map<String, dynamic>>(completeRes);
    return completeData;
  }

  /// 通用图片上传（使用直传）
  ///
  /// [bytes] - 图片二进制数据
  /// [filename] - 文件名
  /// [mimeType] - MIME 类型，如 'image/png'
  /// [onProgress] - 进度回调，参数为 0-100
  Future<Map<String, dynamic>?> uploadImage({
    required List<int> bytes,
    required String filename,
    required String mimeType,
    required void Function(int percent) onProgress,
  }) async {
    return uploadImageDirect(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      onProgress: onProgress,
    );
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final res = await get('/api/notifications/unread-count');
      if (res.hasError) {
        debugPrint(
            'GetUnreadCount Error: ${res.statusCode} - ${res.bodyString}');
        if (res.statusCode == 403) {
          debugPrint(
              'Permission denied. Make sure user is logged in and has proper permissions.');
        }
        return 0;
      }
      final body = res.body;
      if (body is Map<String, dynamic>) {
        return body['count'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('GetUnreadCount Exception: $e');
      return 0;
    }
  }

  Future<PaginationModel<dynamic>> getNotifications(String endCur) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    final queryParams = {
      'start': start.toString(),
      'limit': ApiConfig.defaultPageSize.toString(),
    };

    try {
      final res = await get(
        '/api/notifications/list',
        query: queryParams,
      );

      if (res.hasError) {
        debugPrint(
            'GetNotifications Error: ${res.statusCode} - ${res.bodyString}');
        if (res.statusCode == 403) {
          throw ApiException('没有权限访问通知', statusCode: 403);
        }
        throw ApiException('获取通知失败', statusCode: res.statusCode);
      }

      final data = unwrapData<List<dynamic>>(res);
      final hasNext = data.length >= ApiConfig.defaultPageSize;

      return PaginationModel(
        nodes: data,
        endCursor: (start + ApiConfig.defaultPageSize).toString(),
        hasNextPage: hasNext,
      );
    } catch (e) {
      debugPrint('GetNotifications Exception: $e');
      rethrow;
    }
  }

  Future<bool> markNotificationAsRead(String documentId) async {
    final res = await put(
      '/api/notifications/$documentId/mark-read',
      {},
    );
    if (res.hasError) {
      debugPrint(
          'MarkNotificationRead Error: ${res.statusCode} - ${res.bodyString}');
      return false;
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return body['success'] == true;
    }
    return false;
  }

  Future<bool> markAllNotificationsAsRead() async {
    final res = await put(
      '/api/notifications/mark-all-read',
      {},
    );
    if (res.hasError) {
      debugPrint(
          'MarkAllNotificationsRead Error: ${res.statusCode} - ${res.bodyString}');
      return false;
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return body['success'] == true;
    }
    return false;
  }

  // ─── Like API ───

  Future<({bool liked, int likesCount})> toggleLike({
    required String targetType,
    required String targetId,
  }) async {
    final res = await post(
      '/api/likes/toggle',
      {
        'targetType': targetType,
        'targetId': targetId,
      },
    );

    if (res.hasError) {
      debugPrint('ToggleLike Error: ${res.statusCode} - ${res.bodyString}');
      final body = res.body;
      String msg = 'Toggle like failed';
      if (body is Map) {
        final error = body['error'];
        if (error is Map && error['message'] != null) {
          msg = error['message'].toString();
        }
      }
      throw ApiException(msg, statusCode: res.statusCode);
    }

    final body = res.body;
    if (body is Map<String, dynamic>) {
      return (
        liked: body['liked'] == true,
        likesCount: (body['likesCount'] as num?)?.toInt() ?? 0,
      );
    }
    throw ApiException('Invalid toggle like response');
  }

  Future<Map<String, bool>> batchCheckLikes({
    required String targetType,
    required List<String> targetIds,
  }) async {
    if (targetIds.isEmpty) return {};

    final token = box.read<String>('access_token') ?? '';
    if (token.isEmpty) return {};

    final res = await get(
      '/api/likes/check',
      query: {
        'targetType': targetType,
        'targetIds': targetIds.join(','),
      },
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.hasError) {
      debugPrint(
          'BatchCheckLikes Error: ${res.statusCode} - ${res.bodyString}');
      return {};
    }

    final body = res.body;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map) {
        return data.map((k, v) => MapEntry(k.toString(), v == true));
      }
    }
    return {};
  }

  // ─── Profile API ───

  Future<Map<String, dynamic>> getProfile(String documentId) async {
    final res = await get('/api/profiles/$documentId');
    return unwrapData<Map<String, dynamic>>(res);
  }

  Future<PaginationModel<HDataModel>> getProfileArticles(
    String documentId,
    String endCur, {
    Map<String, dynamic>? authorData,
  }) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    final res = await get(
      '/api/profiles/$documentId/articles',
      query: {
        'start': start.toString(),
        'limit': ApiConfig.defaultPageSize.toString(),
      },
    );

    final data = unwrapData<List<dynamic>>(res);

    // Inject author data into each article if provided
    if (authorData != null) {
      for (final article in data) {
        if (article is Map<String, dynamic>) {
          article['author'] = authorData;
        }
      }
    }

    await _mergeReadStatus(data, tag: 'ProfileArticles');

    final hasNext = data.length >= ApiConfig.defaultPageSize;
    final result = await compute(_parseHDataListAndDiscussionsSync, data);

    final controller = Get.find<Controller>();
    for (final discussion in result.discussions) {
      controller.applyLocalOverrides(discussion);
      HDataModel.upsertCachedDiscussion(discussion);
    }

    return PaginationModel(
      nodes: result.nodes,
      endCursor: (start + ApiConfig.defaultPageSize).toString(),
      hasNextPage: hasNext,
    );
  }

  Future<PaginationModel<Map<String, dynamic>>> getProfileComments(
    String documentId,
    String endCur,
  ) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    final res = await get(
      '/api/profiles/$documentId/comments',
      query: {
        'start': start.toString(),
        'limit': ApiConfig.defaultPageSize.toString(),
      },
    );

    final data = unwrapData<List<dynamic>>(res);
    final comments = data.cast<Map<String, dynamic>>();

    final hasNext = comments.length >= ApiConfig.defaultPageSize;

    return PaginationModel(
      nodes: comments,
      endCursor: (start + ApiConfig.defaultPageSize).toString(),
      hasNextPage: hasNext,
    );
  }
}
