import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:inter_knot/constants/graphql_query.dart' as graphql_query;
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/helpers/transform_reports.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/models/pagination.dart';
import 'package:inter_knot/models/release.dart';
import 'package:inter_knot/models/report_comment.dart';
import 'package:inter_knot/pages/login_page.dart';

class AuthApi extends GetConnect {
  @override
  void onInit() {
    httpClient.baseUrl = 'https://ik.tiwat.cn';
    httpClient.timeout = const Duration(seconds: 15);
    httpClient.defaultContentType = 'application/json';
  }

  Future<({String token, AuthorModel user})> login(
      String email, String password) async {
    final res = await post(
      '/graphql',
      {'query': graphql_query.login(email, password)},
      contentType: 'application/json',
    );

    if (res.hasError) {
      debugPrint('Login Error: ${res.statusCode} - ${res.bodyString}');
      throw Exception(res.statusText);
    }

    final body = res.body as Map<String, dynamic>?;
    final dataMap = body?['data'] as Map<String, dynamic>?;
    final data = dataMap?['login'] as Map<String, dynamic>?;
    if (data == null) {
      debugPrint('Login Data Null: ${res.body}');
      final errors = body?['errors'] as List<dynamic>?;
      final msg = errors != null && errors.isNotEmpty && errors[0] is Map
          ? (errors[0] as Map)['message']?.toString()
          : null;
      throw Exception('Login failed: ${msg ?? "Unknown error"}');
    }

    return (
      token: data['jwt'] as String,
      user: AuthorModel.fromJson(data['user'] as Map<String, dynamic>)
    );
  }

  Future<({String token, AuthorModel user})> register(
      String username, String email, String password) async {
    final res = await post(
      '/graphql',
      {'query': graphql_query.register(username, email, password)},
      contentType: 'application/json',
    );

    if (res.hasError) {
      debugPrint('Register Error: ${res.statusCode} - ${res.bodyString}');
      throw Exception(res.statusText);
    }

    final body = res.body as Map<String, dynamic>?;
    final dataMap = body?['data'] as Map<String, dynamic>?;
    final data = dataMap?['register'] as Map<String, dynamic>?;
    if (data == null) {
      debugPrint('Register Data Null: ${res.body}');
      final errors = body?['errors'] as List<dynamic>?;
      final msg = errors != null && errors.isNotEmpty && errors[0] is Map
          ? (errors[0] as Map)['message']?.toString()
          : null;
      throw Exception('Registration failed: ${msg ?? "Unknown error"}');
    }

    return (
      token: data['jwt'] as String,
      user: AuthorModel.fromJson(data['user'] as Map<String, dynamic>)
    );
  }
}

class BaseConnect extends GetConnect {
  static final authApi = Get.put(AuthApi());

  @override
  void onInit() {
    httpClient.baseUrl = 'https://ik.tiwat.cn';
    httpClient.defaultContentType = 'application/json';
    httpClient.addRequestModifier<dynamic>((request) {
      final token = box.read<String>('access_token') ?? '';
      if (token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      return Future.value(request);
    });
    httpClient.addResponseModifier((req, rep) {
      if (rep.statusCode == HttpStatus.unauthorized) {
        box.remove('access_token');
        Get.offAll(() => const LoginPage());
      }
      return rep;
    });
  }

  Future<Response<Map<String, dynamic>>> graphql(String query,
          {Map<String, dynamic>? variables}) =>
      post(
        '/graphql',
        {'query': query, 'variables': variables},
        contentType: 'application/json',
      );
}

class Api extends BaseConnect {
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

  Future<DiscussionModel> getDiscussion(String id) async {
    final res = await graphql(graphql_query.getDiscussion(id));

    if (res.hasError) {
      debugPrint('GetDiscussion Error: ${res.bodyString}');
      throw Exception(res.statusText);
    }

    final Map<String, dynamic>? body = res.body;
    final Map<String, dynamic>? data = body?['data'] as Map<String, dynamic>?;
    final article = data?['article'] as Map<String, dynamic>?;
    if (article == null) {
      debugPrint('GetDiscussion Data Null for ID: $id. Body: ${res.body}');
      throw Exception('Discussion not found');
    }

    return DiscussionModel.fromJson(article);
  }

  Future<PaginationModel<HDataModel>> search(
      String query, String endCur) async {
    final res = await graphql(graphql_query.search(query, endCur));
    final Map<String, dynamic> body = res.body!;
    final List<dynamic> nodes = (body['data'] as Map<String, dynamic>)['articles'] as List<dynamic>? ?? [];

    return PaginationModel(
      nodes: nodes.map((e) => HDataModel.fromJson(e as Map<String, dynamic>)).toList(),
      endCursor: (int.parse(endCur.isEmpty ? '0' : endCur) + 20).toString(),
      hasNextPage: nodes.length >= 20,
    );
  }

  Future<PaginationModel<CommentModel>> getComments(
      String id, String endCur) async {
    final res = await graphql(graphql_query.getComments(id, endCur));
    
    if (res.hasError) {
      debugPrint('GetComments Error: ${res.statusCode} - ${res.bodyString}');
      throw Exception(res.statusText);
    }

    final Map<String, dynamic>? body = res.body;
    final Map<String, dynamic>? data = body?['data'] as Map<String, dynamic>?;
    if (data == null) {
      debugPrint('GetComments Data Null. Body: ${res.body}');
      throw Exception('Failed to get comments');
    }

    // Strapi GraphQL 返回的是直接的数组
    final commentsList = data['comments'] as List<dynamic>? ?? [];
    final comments = commentsList
        .cast<Map<String, dynamic>>()
        .map(CommentModel.fromJson)
        .toList();
    
    // 计算分页信息
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;
    const limit = 20;
    final hasNextPage = comments.length >= limit;
    final nextEndCur = hasNextPage ? (start + limit).toString() : null;
    
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
      throw Exception('Discussion ID cannot be empty');
    }
    
    debugPrint('Adding comment to discussion: $discussionId, author: $authorId');

    return graphql(
      graphql_query.addDiscussionCommentMutation,
      variables: {
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
    final res = await graphql(graphql_query.getFavorites(username, endCur));
    if (res.hasError) {
      debugPrint('GetFavorites Error: ${res.bodyString}');
      return (items: <HDataModel>[], favoriteIds: <String, String>{});
    }
    final Map<String, dynamic>? body = res.body;
    final data = body?['data'] as Map<String, dynamic>?;
    final list = data?['favorites'] as List<dynamic>?;
    if (list == null || list.isEmpty) {
      return (items: <HDataModel>[], favoriteIds: <String, String>{});
    }

    final items = <HDataModel>[];
    final favoriteIds = <String, String>{};
    for (final entry in list) {
      if (entry is! Map<String, dynamic>) continue;
      final favoriteId = entry['documentId']?.toString();
      final article = entry['article'];
      // Client-side filtering removed as per performance optimization
      
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
    final res = await graphql(graphql_query.getFavoriteId(username, articleId));
    if (res.hasError) {
      debugPrint('GetFavoriteId Error: ${res.bodyString}');
      return null;
    }
    final Map<String, dynamic>? body = res.body;
    final data = body?['data'] as Map<String, dynamic>?;
    final list = data?['favorites'] as List<dynamic>?;
    if (list != null && list.isNotEmpty) {
      final first = list.first;
      if (first is Map<String, dynamic>) {
        return first['documentId']?.toString();
      }
    }
    return null;
  }

  Future<String?> createFavorite({
    required String userId,
    required String articleId,
  }) async {
    final res = await graphql(
      graphql_query.createFavoriteMutation,
      variables: {
        'user': _coerceId(userId),
        'article': articleId,
      },
    );
    if (res.hasError) {
      debugPrint('CreateFavorite Error: ${res.bodyString}');
      return null;
    }
    final Map<String, dynamic>? body = res.body;
    final dataMap = body?['data'] as Map<String, dynamic>?;
    final data = dataMap?['createFavorite'] as Map<String, dynamic>?;
    if (data != null) {
      return data['documentId']?.toString();
    }
    return null;
  }

  Future<bool> deleteFavorite(String favoriteId) async {
    final res = await graphql(graphql_query.deleteFavorite(favoriteId));
    if (res.hasError) {
      debugPrint('DeleteFavorite Error: ${res.bodyString}');
      return false;
    }
    return true;
  }

  Future<Response<Map<String, dynamic>>> createArticle({
    required String title,
    required String text,
    required String slug,
    String? coverId,
    String? authorId,
    String status = 'PUBLISHED',
  }) =>
      graphql(
        graphql_query.createArticleMutation,
        variables: {
          'status': status,
          'data': {
            'title': title,
            'text': text,
            'slug': slug,
            if (coverId != null && coverId.isNotEmpty) 'cover': coverId,
            if (authorId != null && authorId.isNotEmpty) 'author': authorId,
          },
        },
      );

  Future<String?> findAuthorIdByName(String name) async {
    final res = await graphql(graphql_query.getAuthorByName(name));
    if (res.hasError) {
      debugPrint('FindAuthor Error: ${res.bodyString}');
      return null;
    }
    final Map<String, dynamic>? body = res.body;
    final data = body?['data'] as Map<String, dynamic>?;
    final list = data?['authors'] as List<dynamic>?;
    if (list != null && list.isNotEmpty) {
      final first = list.first;
      if (first is Map<String, dynamic>) {
        return first['documentId'] as String?;
      }
    }
    return null;
  }

  Future<String?> createAuthor({
    required String name,
    String? userId,
    bool ensureUniqueSlug = false,
  }) async {
    final slug = _slugify(name, ensureUnique: ensureUniqueSlug);
    final res = await graphql(
      graphql_query.createAuthorMutation,
      variables: {
        'data': {
          'name': name,
          'slug': slug,
        },
      },
    );
    if (res.hasError) {
      debugPrint('CreateAuthor Error: ${res.bodyString}');
      if (res.bodyString?.contains('must be unique') == true) {
        debugPrint('Slug conflict detected, retrying find by name');
        await Future.delayed(const Duration(milliseconds: 300));
        return await findAuthorIdByName(name);
      }
      return null;
    }
    final Map<String, dynamic>? body = res.body;
    final dataMap = body?['data'] as Map<String, dynamic>?;
    final data = dataMap?['createAuthor'] as Map<String, dynamic>?;
    if (data != null) {
      return data['documentId'] as String?;
    }
    return null;
  }

  Future<void> linkAuthorToUser({
    required String authorId,
    required String userId,
  }) async {
    final res = await graphql(
      graphql_query.updateAuthorMutation,
      variables: {
        'documentId': authorId,
        'data': {
          'user': _coerceId(userId),
        },
      },
    );
    if (res.hasError) {
      debugPrint('UpdateAuthor Error: ${res.bodyString}');
    }
  }

  Future<String?> ensureAuthorId({
    required String name,
    String? userId,
  }) async {
    var existingId = await findAuthorIdByName(name);
    if (existingId != null && existingId.isNotEmpty) return existingId;

    await Future.delayed(const Duration(milliseconds: 500));
    existingId = await findAuthorIdByName(name);
    if (existingId != null && existingId.isNotEmpty) return existingId;

    await Future.delayed(const Duration(milliseconds: 500));
    existingId = await findAuthorIdByName(name);
    if (existingId != null && existingId.isNotEmpty) return existingId;

    debugPrint('Warning: Author not found after retries, creating as fallback');
    return createAuthor(name: name, ensureUniqueSlug: true);
  }

  Future<Response<Map<String, dynamic>>> deleteDiscussion(String id) =>
      graphql(graphql_query.deleteDiscussion(id));

  Future<PaginationModel<HDataModel>> getPinnedDiscussions(
      String? endCur) async {
    final res = await graphql(graphql_query.getPinnedDiscussions(endCur));
    final Map<String, dynamic> body = res.body!;
    final data = body['data'] as Map<String, dynamic>;
    return PaginationModel.fromJson(
      data['search'] as Map<String, dynamic>,
      HDataModel.fromPinnedJson,
    );
  }

  Future<AuthorModel> getSelfUserInfo(String login) async {
    final res = await graphql(graphql_query.getSelfUserInfo());
    final Map<String, dynamic>? body = res.body;
    final dataMap = body?['data'] as Map<String, dynamic>?;
    final data = dataMap?['me'] as Map<String, dynamic>?;
    if (data == null) throw Exception('User not found');
    return AuthorModel.fromJson(data);
  }

  Future<AuthorModel> getUserInfo(String username) async {
    final res = await graphql(graphql_query.getUserInfo(username));
    final Map<String, dynamic> body = res.body!;
    final Map<String, dynamic> data = body['data'] as Map<String, dynamic>;
    return AuthorModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<ReleaseModel?> getNewVersion(String login) async {
    // Disabled/Mocked
    return null;
  }

  Future<Report> getAllReports(String id) {
    // Mocked empty report list as backend doesn't support it yet
    return Future.value(<int, Set<ReportCommentModel>>{});
  }
}
