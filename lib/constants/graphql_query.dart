import 'package:inter_knot/helpers/query_encode.dart';

String getDiscussion(int number) =>
    '{ getDiscussion(number: $number) { author { avatarUrl username } createdAt updatedAt bodyHTML id bodyText title commentsCount } }';

String search(String query, String? endCur, [int length = 20]) =>
    '{ search(query: "${queryEncode(query)}", first: $length, after: ${endCur == null ? null : '"$endCur"'}) { pageInfo { endCursor hasNextPage } nodes { number updatedAt } } }';

String getUserInfo(String username) =>
    '{ user(username: "$username") { username avatarUrl createdAt } }'; // Simplified

String getSelfUserInfo() => '{ me { avatarUrl username } }';

// Pinned discussions not implemented in backend, falling back to search or empty
String getPinnedDiscussions(String? endCur) =>
    '{ search(query: "", first: 20, after: ${endCur == null ? null : '"$endCur"'}) { pageInfo { endCursor hasNextPage } nodes { number updatedAt } } }';

// Releases not implemented
String getNewVersion() => '';

String getComments(int number, String? endCur) =>
    '{ getDiscussion(number: $number) { comments(first: 20, after: ${endCur == null ? null : '"$endCur"'}) { pageInfo { endCursor hasNextPage } nodes { author { avatarUrl username } id bodyHTML createdAt updatedAt } } } }';

String deleteDiscussion(String id) =>
    'mutation { deleteDiscussion(id: "$id") { id } }'; // Not implemented in backend yet

String addDiscussionComment(int discussionId, String body) =>
    'mutation { addComment(discussionId: $discussionId, bodyHTML: "${queryEncode(body)}") { id } }';

String login(String email, String password) =>
    'mutation { login(email: "$email", password: "$password") { token user { username avatarUrl } } }';

String register(String username, String email, String password) =>
    'mutation { register(username: "$username", email: "$email", password: "$password") { token user { username avatarUrl } } }';

const String createDiscussionMutation = r'''
  mutation CreateDiscussion($title: String!, $bodyHTML: String!, $bodyText: String!, $cover: String) {
    createDiscussion(title: $title, bodyHTML: $bodyHTML, bodyText: $bodyText, cover: $cover) {
      id
    }
  }
''';