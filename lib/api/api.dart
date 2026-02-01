import 'dart:async';
import 'dart:io';
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
      print('Login Error: ${res.statusCode} - ${res.bodyString}');
      throw Exception(res.statusText);
    }

    final data = res.body['data']?['login'];
    if (data == null) {
      print('Login Data Null: ${res.body}');
      throw Exception('Login failed: ${res.body['errors']?[0]['message'] ?? "Unknown error"}');
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
      print('Register Error: ${res.statusCode} - ${res.bodyString}');
      throw Exception(res.statusText);
    }

    final data = res.body['data']?['register'];
    if (data == null) {
      print('Register Data Null: ${res.body}');
      throw Exception('Registration failed: ${res.body['errors']?[0]['message'] ?? "Unknown error"}');
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
    httpClient.addRequestModifier<dynamic>((request) async {
      var token = box.read<String>('access_token') ?? '';
      if (token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      return request;
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
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
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
      print('GetDiscussion Error: ${res.bodyString}');
      throw Exception(res.statusText);
    }

    final data = res.body?['data'];
    if (data == null || data['article'] == null) {
      print('GetDiscussion Data Null for ID: $id. Body: ${res.body}');
      throw Exception('Discussion not found');
    }

    return DiscussionModel.fromJson(
      data['article'] as Map<String, dynamic>,
    );
  }

  Future<PaginationModel<HDataModel>> search(
      String query, String endCur) async {
    final res = await graphql(graphql_query.search(query, endCur));
    final List<dynamic> nodes = res.body!['data']['articles'] as List? ?? [];

    return PaginationModel(
      nodes: nodes.map((e) => HDataModel.fromJson(e as Map<String, dynamic>)).toList(),
      endCursor: (int.parse(endCur.isEmpty ? "0" : endCur) + 20).toString(),
      hasNextPage: nodes.length >= 20,
    );
  }

  Future<PaginationModel<CommentModel>> getComments(
      String id, String endCur) async {
    final res = await graphql(graphql_query.getComments(id, endCur));
    
    if (res.hasError) {
      print('GetComments Error: ${res.statusCode} - ${res.bodyString}');
      throw Exception(res.statusText);
    }
    
    final data = res.body?['data'];
    if (data == null) {
      print('GetComments Data Null. Body: ${res.body}');
      throw Exception('Failed to get comments');
    }
    
    // Strapi GraphQL 返回的是直接的数组
    final commentsList = data['comments'] as List? ?? [];
    final comments = commentsList
        .cast<Map<String, dynamic>>()
        .map(CommentModel.fromJson)
        .toList();
    
    // 计算分页信息
    final start = int.tryParse(endCur.isEmpty ? '0' : endCur) ?? 0;
    final limit = 20;
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
    
    print('Adding comment to discussion: $discussionId, author: $authorId');
    
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

  Future<Response<Map<String, dynamic>>> createArticle({
    required String title,
    required String description,
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
            'description': description,
            'slug': slug,
            if (coverId != null && coverId.isNotEmpty) 'cover': coverId,
            if (authorId != null && authorId.isNotEmpty) 'author': authorId,
          },
        },
      );

  Future<String?> findAuthorIdByName(String name) async {
    final res = await graphql(graphql_query.getAuthorByName(name));
    if (res.hasError) {
      print('FindAuthor Error: ${res.bodyString}');
      return null;
    }
    final list = res.body?['data']?['authors'];
    if (list is List && list.isNotEmpty) {
      final first = list.first;
      if (first is Map) {
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
      print('CreateAuthor Error: ${res.bodyString}');
      if (res.bodyString?.contains('must be unique') == true) {
        print('Slug conflict detected, retrying find by name');
        await Future.delayed(const Duration(milliseconds: 300));
        return await findAuthorIdByName(name);
      }
      return null;
    }
    final data = res.body?['data']?['createAuthor'];
    if (data is Map) {
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
      print('UpdateAuthor Error: ${res.bodyString}');
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

    print('Warning: Author not found after retries, creating as fallback');
    return createAuthor(name: name, userId: null, ensureUniqueSlug: true);
  }

  Future<Response<Map<String, dynamic>>> deleteDiscussion(String id) =>
      graphql(graphql_query.deleteDiscussion(id));

  Future<PaginationModel<HDataModel>> getPinnedDiscussions(
      String? endCur) async {
    final res = await graphql(graphql_query.getPinnedDiscussions(endCur));
    // Mapping search results to pinned format (just re-using search result structure)
    return PaginationModel.fromJson(
      res.body!['data']['search'] as Map<String, dynamic>,
      HDataModel.fromPinnedJson,
    );
  }

  Future<AuthorModel> getSelfUserInfo(String login) async {
    final res = await graphql(graphql_query.getSelfUserInfo());
    final data = res.body?['data']?['me'];
    if (data == null) throw Exception('User not found');
    return AuthorModel.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthorModel> getUserInfo(String username) async {
    final res = await graphql(graphql_query.getUserInfo(username));
    return AuthorModel.fromJson(
      res.body!['data']['user'] as Map<String, dynamic>,
    );
  }

  Future<ReleaseModel?> getNewVersion(String login) async {
    // Disabled/Mocked
    return null;
  }

  Future<Report> getAllReports(String id) async {
    // Mocked empty report list as backend doesn't support it yet
    return {};
  }
}
