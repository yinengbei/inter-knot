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
    httpClient.baseUrl = 'http://localhost:4000/graphql';
  }

  Future<({String token, AuthorModel user})> login(
      String email, String password) async {
    final res = await post(
      '',
      {'query': graphql_query.login(email, password)},
    );
    if (res.hasError) throw Exception(res.statusText);
    
    final data = res.body['data']['login'];
    if (data == null) throw Exception('Login failed');

    return (
      token: data['token'] as String,
      user: AuthorModel.fromJson(data['user'] as Map<String, dynamic>)
    );
  }

  Future<({String token, AuthorModel user})> register(
      String username, String email, String password) async {
    final res = await post(
      '',
      {'query': graphql_query.register(username, email, password)},
    );
    if (res.hasError) throw Exception(res.statusText);

    final data = res.body['data']['register'];
    if (data == null) throw Exception('Registration failed');

    return (
      token: data['token'] as String,
      user: AuthorModel.fromJson(data['user'] as Map<String, dynamic>)
    );
  }
}

class BaseConnect extends GetConnect {
  static final authApi = Get.put(AuthApi());

  @override
  void onInit() {
    httpClient.baseUrl = 'http://localhost:4000';
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
  Future<DiscussionModel> getDiscussion(int number) async {
    final res = await graphql(graphql_query.getDiscussion(number));
    return DiscussionModel.fromJson(
      res.body!['data']['getDiscussion'] as Map<String, dynamic>,
    );
  }

  Future<PaginationModel<HDataModel>> search(
      String query, String endCur) async {
    final res = await graphql(graphql_query.search(query, endCur));
    return PaginationModel.fromJson(
      res.body!['data']['search'] as Map<String, dynamic>,
      HDataModel.fromJson,
    );
  }

  Future<PaginationModel<CommentModel>> getComments(
      int number, String endCur) async {
    final res = await graphql(graphql_query.getComments(number, endCur));
    return PaginationModel.fromJson(
      res.body!['data']['getDiscussion']['comments']
          as Map<String, dynamic>,
      CommentModel.fromJson,
    );
  }

  Future<Response<Map<String, dynamic>>> addDiscussionComment(
    int discussionId,
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

  Future<Report> getAllReports(int number) async {
    // Mocked empty report list as backend doesn't support it yet
    return {};
  }
}
