import 'package:inter_knot/helpers/query_encode.dart';

String getDiscussion(String id) => '''
  query {
    article(documentId: "$id") {
      title
      description
      cover {
        url
      }
      blocks {
        __typename
        ... on ComponentSharedRichText {
          body
        }
        ... on ComponentSharedQuote {
          title
          body
        }
        ... on ComponentSharedMedia {
          file {
            url
          }
        }
      }
      createdAt
      updatedAt
      author {
        name
        avatar {
          url
        }
      }
    }
  }
''';

String search(String query, String? endCur, [int length = 20]) => '''
  query {
    articles(
      pagination: { limit: $length, start: ${endCur == null || endCur.isEmpty ? 0 : endCur} }
      sort: "updatedAt:desc"
      filters: { title: { contains: "${queryEncode(query)}" } }
    ) {
      documentId
      title
      description
      cover {
        url
      }
      updatedAt
      author {
        name
        avatar {
          url
        }
      }
    }
  }
''';

String getUserInfo(String username) =>
    '{ user(username: "$username") { username avatarUrl createdAt } }'; // Simplified

String getSelfUserInfo() => '{ me { avatarUrl username } }';

// Pinned discussions not implemented in backend, falling back to search or empty
String getPinnedDiscussions(String? endCur) =>
    '{ search(query: "", first: 20, after: ${endCur == null ? null : '"$endCur"'}) { pageInfo { endCursor hasNextPage } nodes { number updatedAt } } }';

// Releases not implemented
String getNewVersion() => '';

String getComments(String id, String? endCur) => '''
  query {
    comments(
      filters: { article: { documentId: { eq: "$id" } } }
      pagination: { limit: 20, start: ${endCur == null || endCur.isEmpty ? 0 : endCur} }
      sort: "createdAt:asc"
    ) {
      documentId
      content
      createdAt
      updatedAt
      author {
        name
        avatar {
          url
        }
      }
    }
  }
''';

String deleteDiscussion(String id) =>
    'mutation { deleteDiscussion(id: "$id") { id } }'; // Not implemented in backend yet

String addDiscussionComment(String discussionId, String body) =>
    'mutation { createComment(data: { article: "$discussionId", content: "${queryEncode(body)}" }) { documentId } }';

String login(String email, String password) =>
    'mutation { login(input: { identifier: "$email", password: "$password" }) { jwt user { username email id } } }';

String register(String username, String email, String password) =>
    'mutation { register(input: { username: "$username", email: "$email", password: "$password" }) { jwt user { username email id } } }';

const String createDiscussionMutation = r'''
  mutation CreateDiscussion($title: String!, $bodyHTML: String!, $bodyText: String!, $cover: String) {
    createDiscussion(title: $title, bodyHTML: $bodyHTML, bodyText: $bodyText, cover: $cover) {
      id
    }
  }
''';