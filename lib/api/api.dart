import 'dart:async';
import 'dart:convert';
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
  }

  Future<({String token, AuthorModel user})> login(
      String email, String password) async {
    final res = await post(
      '/graphql',
      {'query': graphql_query.login(email, password)},
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
      post('/graphql', jsonEncode({'query': query, 'variables': variables}));
}

class Api extends BaseConnect {
  Future<DiscussionModel> getDiscussion(String id) async {
    // 目前 query 里的 getDiscussion 接受 String
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
    final List<dynamic> nodes = res.body!['data']['articles'] ?? [];
    
    // 手动构造分页模型
    return PaginationModel(
       nodes: nodes.map((e) => HDataModel.fromJson(e)).toList(),
       endCursor: (int.parse(endCur.isEmpty ? "0" : endCur) + 20).toString(), 
       hasNextPage: nodes.length >= 20
    );
  }

  Future<PaginationModel<CommentModel>> getComments(
      String id, String endCur) async {
    final res = await graphql(graphql_query.getComments(id, endCur));
    return PaginationModel.fromJson(
      res.body!['data']['getDiscussion']['comments']
          as Map<String, dynamic>,
      CommentModel.fromJson,
    );
  }

  Future<Response<Map<String, dynamic>>> addDiscussionComment(
    String discussionId,
    String body,
  ) =>
      graphql(graphql_query.addDiscussionComment(discussionId, body));

  Future<Response<Map<String, dynamic>>> createDiscussion(
    String title,
    String bodyHTML,
    String bodyText,
    String? cover,
  ) =>
      graphql(
        graphql_query.createDiscussionMutation,
        variables: {
          'title': title,
          'bodyHTML': bodyHTML,
          'bodyText': bodyText,
          'cover': cover,
        },
      );

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
        res.body!['data']['user'] as Map<String, dynamic>);
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
