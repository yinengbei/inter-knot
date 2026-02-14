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
import 'package:inter_knot/models/release.dart';

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

  @override
  void onInit() {
    httpClient.baseUrl = ApiConfig.baseUrl;
    httpClient.timeout = ApiConfig.timeout;
    httpClient.defaultContentType = 'application/json';
    httpClient.addRequestModifier<dynamic>((request) {
      final token = box.read<String>('access_token') ?? '';

      // Define public endpoints that should not send auth token to maximize cache hits
      // Matches /api/articles, /api/comments, /api/authors and their sub-paths
      final isPublicEndpoint = request.url.path.startsWith('/api/articles') ||
          request.url.path.startsWith('/api/comments') ||
          request.url.path.startsWith('/api/authors');

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

  Map<String, String> _buildPaginationQuery({
    required int start,
    int limit = ApiConfig.defaultPageSize,
    Map<String, String>? filters,
    Map<String, String>? populate,
    String? sort,
  }) {
    return {
      'pagination[start]': start.toString(),
      'pagination[limit]': limit.toString(),
      if (sort != null) 'sort': sort,
      ...?filters,
      ...?populate,
    };
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
      readStatusFuture = get(
        '/api/article-reads',
        query: {
          'filters[user][id][\$eq]': userId,
          'filters[article][documentId][\$eq]': id,
          'fields[0]': 'isRead',
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

    // Use compute to parse heavy markdown/html in isolate
    return compute(_parseDiscussionSync, data);
  }

  Future<PaginationModel<HDataModel>> search(
      String query, String endCur) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    final filters = <String, String>{};
    if (query.isNotEmpty) {
      filters['filters[\$or][0][title][\$contains]'] = query;
      filters['filters[\$or][1][text][\$contains]'] = query;
    }

    final queryParams = _buildPaginationQuery(
      start: start,
      sort: 'updatedAt:desc',
      filters: filters,
      populate: {
        'populate[author][populate]': 'avatar',
        'populate[cover][fields][0]': 'url',
        'populate[cover][fields][1]': 'width',
        'populate[cover][fields][2]': 'height',
        'populate[blocks][populate]': '*',
      },
    );

    final res = await get(
      '/api/articles',
      query: queryParams,
    );

    final data = unwrapData<List<dynamic>>(res);

    // Optimization: Bulk fetch read status
    final userId = box.read<String>('userId');
    if (userId != null && userId.isNotEmpty && data.isNotEmpty) {
      final ids =
          data.map((e) => e['documentId']).where((e) => e != null).toList();
      if (ids.isNotEmpty) {
        final readQuery = <String, String>{
          'filters[user][id][\$eq]': userId,
          'populate[article][fields][0]': 'documentId',
          'fields[0]': 'isRead',
          'pagination[limit]': '${ids.length}',
        };
        for (var i = 0; i < ids.length; i++) {
          readQuery['filters[article][documentId][\$in][$i]'] =
              ids[i].toString();
        }

        try {
          final readRes = await get('/api/article-reads', query: readQuery);
          final readList = unwrapData<List<dynamic>>(readRes);
          final readMap = <String, bool>{};
          for (final r in readList) {
            if (r is Map) {
              final article = r['article'];
              final isRead = r['isRead'] == true;
              String? aId;
              if (article is Map) aId = article['documentId'];
              if (aId != null && isRead) {
                readMap[aId] = true;
              }
            }
          }

          for (final d in data) {
            if (d is Map) {
              final id = d['documentId'];
              if (readMap.containsKey(id)) {
                d['isRead'] = true;
              }
            }
          }
        } catch (e) {
          debugPrint('Search Read Status Error: $e');
        }
      }
    }

    final hasNext = data.length >= ApiConfig.defaultPageSize;

    return PaginationModel(
      nodes: data
          .map((e) => HDataModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      endCursor: (start + ApiConfig.defaultPageSize).toString(),
      hasNextPage: hasNext,
    );
  }

  Future<PaginationModel<HDataModel>> getUserDiscussions(
      String authorId, String endCur) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    final queryParams = _buildPaginationQuery(
      start: start,
      sort: 'updatedAt:desc',
      filters: {'filters[author][documentId][\$eq]': authorId},
      populate: {
        'populate[author][populate]': 'avatar',
        'populate[cover][fields][0]': 'url',
        'populate[cover][fields][1]': 'width',
        'populate[cover][fields][2]': 'height',
        'populate[blocks][populate]': '*',
      },
    );

    final res = await get(
      '/api/articles',
      query: queryParams,
    );

    final data = unwrapData<List<dynamic>>(res);

    // Optimization: Bulk fetch read status
    final userId = box.read<String>('userId');
    if (userId != null && userId.isNotEmpty && data.isNotEmpty) {
      final ids =
          data.map((e) => e['documentId']).where((e) => e != null).toList();
      if (ids.isNotEmpty) {
        final readQuery = <String, String>{
          'filters[user][id][\$eq]': userId,
          'populate[article][fields][0]': 'documentId',
          'fields[0]': 'isRead',
          'pagination[limit]': '${ids.length}',
        };
        for (var i = 0; i < ids.length; i++) {
          readQuery['filters[article][documentId][\$in][$i]'] =
              ids[i].toString();
        }

        try {
          final readRes = await get('/api/article-reads', query: readQuery);
          final readList = unwrapData<List<dynamic>>(readRes);
          final readMap = <String, bool>{};
          for (final r in readList) {
            if (r is Map) {
              final article = r['article'];
              final isRead = r['isRead'] == true;
              String? aId;
              if (article is Map) aId = article['documentId'];
              if (aId != null && isRead) {
                readMap[aId] = true;
              }
            }
          }

          for (final d in data) {
            if (d is Map) {
              final id = d['documentId'];
              if (readMap.containsKey(id)) {
                d['isRead'] = true;
              }
            }
          }
        } catch (e) {
          debugPrint('UserDiscussions Read Status Error: $e');
        }
      }
    }

    final hasNext = data.length >= ApiConfig.defaultPageSize;

    return PaginationModel(
      nodes: data
          .map((e) => HDataModel.fromJson(e as Map<String, dynamic>))
          .toList(),
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
      '/api/comments',
      query: {
        'filters[article][documentId][\$eq]': discussionId,
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

  Future<PaginationModel<CommentModel>> getComments(
      String id, String endCur) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    final queryParams = _buildPaginationQuery(
      start: start,
      sort: 'createdAt:asc',
      filters: {'filters[article][documentId][\$eq]': id},
      populate: {'populate[author][populate]': 'avatar'},
    );
    // Add cache buster
    queryParams['ts'] = DateTime.now().millisecondsSinceEpoch.toString();

    final res = await get(
      '/api/comments',
      query: queryParams,
    );

    final data = unwrapData<List<dynamic>>(res);
    final comments =
        data.cast<Map<String, dynamic>>().map(CommentModel.fromJson).toList();

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
  }) {
    if (discussionId.isEmpty) {
      throw ApiException('Discussion ID cannot be empty');
    }

    debugPrint(
        'Adding comment to discussion: $discussionId, author: $authorId');

    return post(
      '/api/comments',
      {
        'data': {
          'article': discussionId,
          'content': body,
          if (authorId != null && authorId.isNotEmpty) 'author': authorId,
        },
      },
    );
  }

  Future<({List<HDataModel> items, Map<String, String> favoriteIds})>
      getFavorites(String username, String endCur) async {
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;

    final queryParams = _buildPaginationQuery(
      start: start,
      filters: {'filters[user][username][\$eq]': username},
      populate: {
        'populate[article][fields][0]': 'documentId',
        'populate[article][fields][1]': 'updatedAt',
      },
    );

    final res = await get(
      '/api/favorites',
      query: queryParams,
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

  Future<Response<Map<String, dynamic>>> deleteDiscussion(String id) =>
      delete('/api/articles/$id');

  Future<PaginationModel<HDataModel>> getPinnedDiscussions(String? endCur) {
    // Reusing search/list endpoint for now as placeholder
    return search('', endCur ?? '');
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

  Future<ReleaseModel?> getNewVersion(String login) async {
    // Disabled/Mocked
    return null;
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
}
