import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api_exception.dart';
import 'package:inter_knot/constants/api_config.dart';
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/models/pagination.dart';
import 'package:inter_knot/controllers/data.dart';

class AuthApi extends GetConnect {
  @override
  void onInit() {
    httpClient.baseUrl = ApiConfig.baseUrl;
    httpClient.timeout = ApiConfig.timeout;
    httpClient.defaultContentType = 'application/json';
  }

  String _getErrorMessage(Response res) {
    String msg = res.statusText ?? 'Request failed';
    if (msg.contains('XMLHttpRequest error')) {
      return '短时间内请求数量过多';
    }
    try {
      if (res.body is Map && res.body['error'] != null) {
        final error = res.body['error'];
        if (error is Map && error['message'] != null) {
          msg = error['message'];
        } else if (error is String) {
          msg = error;
        }
      }
    } catch (_) {}
    return msg;
  }

  Future<({String? token, AuthorModel user})> login(
      String email, String password) async {
    final res = await post(
      '/api/auth/local',
      {'identifier': email, 'password': password},
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
      String username, String email, String password) async {
    final res = await post(
      '/api/auth/local/register',
      {'username': username, 'email': email, 'password': password},
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
    httpClient.addRequestModifier<dynamic>((request) {
      final token = box.read<String>('access_token') ?? '';
      final path = request.url.path;

      // Define public endpoints that should not send auth token to maximize cache hits
      // Matches /api/articles, /api/comments, /api/authors and their sub-paths
      // EXCEPT specific user-related endpoints like /api/articles/my
      final isPublicEndpoint =
          (path.startsWith('/api/articles') && !path.contains('/my')) ||
              path.startsWith('/api/comments') ||
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
          message = error['message']?.toString();
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
          statusCode: response.statusCode, details: response.bodyString);
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

List<CommentModel> _parseCommentListSync(List<dynamic> data) {
  return data.cast<Map<String, dynamic>>().map(CommentModel.fromJson).toList();
}

class Api extends BaseConnect {
  String? _normalizeFileUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '${ApiConfig.baseUrl}$url';
  }

  String _contentTypeFromFilename(String filename) {
    final ext = filename.toLowerCase();
    if (ext.endsWith('.png')) return 'image/png';
    if (ext.endsWith('.webp')) return 'image/webp';
    if (ext.endsWith('.gif')) return 'image/gif';
    if (ext.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
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

    final articleFuture = get(
      '/api/articles/$id',
      query: {
        'populate[author][populate]': 'avatar',
        'populate[cover][fields][0]': 'url',
        'populate[cover][fields][1]': 'width',
        'populate[cover][fields][2]': 'height',
        'populate[blocks][populate]': '*',
      },
    );

    Future<Response>? readStatusFuture;
    if (userId != null && userId.isNotEmpty) {
      readStatusFuture = post(
        '/api/article-reads/batch',
        {
          'articleDocumentIds': [id],
        },
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

    final discussion = await compute(_parseDiscussionSync, data);
    final controller = Get.find<Controller>();
    controller.applyLocalOverrides(discussion);
    HDataModel.upsertCachedDiscussion(discussion);
    return discussion;
  }

  Future<DiscussionModel> getArticleDetail(String documentId) async {
    final res = await get('/api/articles/detail/$documentId');
    final data = unwrapData<Map<String, dynamic>>(res);
    return _parseDiscussionSync(data);
  }

  Future<void> viewArticle(String id) async {
    await post('/api/articles/$id/view', {});
  }

  Future<({
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
      )
          ?.toUtc(),
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
      {'data': data},
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

  Future<Response<Map<String, dynamic>>> createArticle({
    required String title,
    required String text,
    required String slug,
    dynamic coverId, // String or List<String>
    String? authorId,
  }) {
    final Map<String, dynamic> data = {
      'title': title,
      'text': text,
      'slug': slug,
      'publishedAt': DateTime.now().toIso8601String(),
    };

    if (coverId != null) {
      if (coverId is String && coverId.isNotEmpty) {
        data['cover'] = _coerceId(coverId);
      } else if (coverId is List && coverId.isNotEmpty) {
        data['cover'] =
            coverId.map((e) => e is String ? _coerceId(e) : e).toList();
      }
    }

    if (authorId != null && authorId.isNotEmpty) {
      data['author'] = _coerceId(authorId);
    }

    return post(
      '/api/articles',
      {'data': data},
    );
  }

  Future<Response<Map<String, dynamic>>> updateDiscussion({
    required String id,
    String? title,
    String? text,
    String? slug,
    dynamic coverId,
  }) {
    final Map<String, dynamic> data = {};
    if (title != null) data['title'] = title;
    if (text != null) data['text'] = text;
    if (slug != null) data['slug'] = slug;

    if (coverId != null) {
      if (coverId is String && coverId.isNotEmpty) {
        data['cover'] = _coerceId(coverId);
      } else if (coverId is List && coverId.isNotEmpty) {
        data['cover'] =
            coverId.map((e) => e is String ? _coerceId(e) : e).toList();
      } else if (coverId is List && coverId.isEmpty) {
        // Clear cover if empty list passed
        data['cover'] = [];
      }
    }

    return put(
      '/api/articles/$id',
      {'data': data},
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

  Future<({
    String message,
    int? reward,
    int? consecutiveDays,
    int? rank,
    int? currentExp,
    int? currentLevel,
  })>
      checkIn() async {
    final res = await post('/api/check-in', {});

    if (res.hasError) {
      String errorMessage = '签到失败';
      dynamic details;
      if (res.body is Map) {
        final error = res.body['error'];
        if (error is Map) {
          final code = error['code']?.toString();
          details = error['details'];

          if (code == 'CHECK_IN_ALREADY_TODAY') {
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
    final uploadRes = await post(
      '/api/upload',
      FormData({
        'files': MultipartFile(
          bytes,
          filename: filename,
          contentType: contentType ?? _contentTypeFromFilename(filename),
        ),
      }),
      contentType: 'multipart/form-data',
    );

    // upload response in strapi is typically a list of files
    final uploadedList = unwrapData<List<dynamic>>(uploadRes);
    if (uploadedList.isEmpty) {
      throw ApiException('Upload failed');
    }

    final uploaded = uploadedList.first as Map;
    final rawAvatarId = uploaded['id'] ?? uploaded['documentId'];
    if (rawAvatarId == null) {
      throw ApiException('Upload response missing file id');
    }
    final uploadedUrl = _normalizeFileUrl(uploaded['url'] as String?);

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

  /// 通用图片上传，支持所有平台
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
    final form = FormData({
      'files': MultipartFile(bytes, filename: filename, contentType: mimeType),
    });

    final res = await post(
      '/api/upload',
      form,
      uploadProgress: (percent) => onProgress((percent * 100).round()),
    );

    if (res.hasError) {
      throw ApiException(res.statusText ?? 'Upload failed',
          statusCode: res.statusCode);
    }

    final body = res.body;
    if (body is List && body.isNotEmpty) {
      return body.first as Map<String, dynamic>;
    } else if (body is Map<String, dynamic>) {
      // Sometimes Strapi returns a single object depending on plugin config?
      // Standard upload returns array.
      return body;
    }

    return null;
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final res = await get('/api/notifications/unread-count');
      if (res.hasError) {
        debugPrint('GetUnreadCount Error: ${res.statusCode} - ${res.bodyString}');
        if (res.statusCode == 403) {
          debugPrint('Permission denied. Make sure user is logged in and has proper permissions.');
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
        debugPrint('GetNotifications Error: ${res.statusCode} - ${res.bodyString}');
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
      debugPrint('MarkNotificationRead Error: ${res.statusCode} - ${res.bodyString}');
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
      debugPrint('MarkAllNotificationsRead Error: ${res.statusCode} - ${res.bodyString}');
      return false;
    }
    final body = res.body;
    if (body is Map<String, dynamic>) {
      return body['success'] == true;
    }
    return false;
  }
}
