import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/helpers/parse_html.dart';
import 'package:inter_knot/helpers/use.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/pagination.dart';
import 'package:markdown/markdown.dart' as md;

class DiscussionModel {
  String title;
  String bodyHTML;
  String rawBodyText;
  String? cover;
  String id;
  // int number; // Removed, merged into id
  DateTime createdAt;
  DateTime? lastEditedAt;
  int commentsCount;
  AuthorModel author;
  List<PaginationModel<CommentModel>> comments;
  String get bodyText => rawBodyText.replaceAll(RegExp(r'\s+'), ' ').trim();
  String get url => ''; // Placeholder
  
  Api? _api;
  Api get api => _api ??= Get.find<Api>();
  
  bool hasNextPage() {

    if (comments.isEmpty) return true;

    return comments.last.hasNextPage;
  }
  
  bool _isLoadingComments = false;
  
  Future<void> fetchComments() async {
    if (_isLoadingComments) return;
    if (comments.isNotEmpty && !comments.last.hasNextPage) return;
    
    _isLoadingComments = true;
    final lastPage = comments.isEmpty ? null : comments.last;
    final endCur = lastPage?.endCursor ?? '0';
    
    try {
      final pagination = await api.getComments(id, endCur);
      
      if (comments.isEmpty) {
        comments = [pagination];
      } else {
        comments.last.nodes.addAll(pagination.nodes);
        comments.last.hasNextPage = pagination.hasNextPage;
        comments.last.endCursor = pagination.endCursor;
      }
    } catch (e) {
      debugPrint('Failed to fetch comments: $e');
      rethrow;
    } finally {
      _isLoadingComments = false;
    }
  }

  DiscussionModel({
    required this.title,
    required this.bodyHTML,
    required this.rawBodyText,
    required this.cover,
    // required this.number, // Removed
    required this.id,
    required this.createdAt,
    required this.commentsCount,
    required this.lastEditedAt,
    required this.author,
    required this.comments,
  });

  factory DiscussionModel.fromJson(Map<String, dynamic> json) {
 
    final textVal = json['text'];
    String rawBody = textVal is String ? textVal : '';
    
    if (json['blocks'] != null) {
      final blocks = json['blocks'] as List<dynamic>;
      for (final block in blocks) {
        if (block is! Map<String, dynamic>) continue;
        final type = block['__typename'] as String?;
        // ComponentSharedRichText -> body
        if (type == 'ComponentSharedRichText' && block['body'] != null) {
          rawBody += '\n\n${block['body'] as String}';
        }
        // ComponentSharedQuote -> body
        else if (type == 'ComponentSharedQuote' && block['body'] != null) {
          rawBody += '\n\n> ${block['body'] as String}';
        }
      }
    }

    // Convert Markdown to HTML
    final htmlBody = md.markdownToHtml(
      rawBody,
      extensionSet: md.ExtensionSet.gitHubWeb,
    );

    final (:cover, :html) = parseHtml(htmlBody);
    
    // 处理封面图: 优先取 json['cover']，如果没有则尝试从 parseHtml 获取
    String? coverUrl;
    final coverData = json['cover'];
    if (coverData is Map<String, dynamic> && coverData['url'] != null) {
      coverUrl = coverData['url'] as String;
      if (!coverUrl.startsWith('http')) {
        coverUrl = 'https://ik.tiwat.cn$coverUrl';
      }
    }
    
    final commentsJson = json['comments'] as Map<String, dynamic>?;

    final authorData = json['author'];
    final author = authorData is Map<String, dynamic>
        ? AuthorModel.fromJson(authorData)
        : AuthorModel(
            login: 'unknown',
            avatar: 'https://ik.tiwat.cn/uploads/default_avatar.png',
            name: 'Unknown',
          );

    return DiscussionModel(
      title: json['title'] is String ? json['title'] as String : (json['title']?.toString() ?? ''),
      bodyHTML: html,
      cover: coverUrl ?? cover, // 优先使用 Strapi 字段，其次是内容里的图
      rawBodyText: rawBody,
      // number: ... Removed
      id: json['documentId'] as String? ?? json['id']?.toString() ?? '', // 优先 documentId
      createdAt: json['createdAt'] is String ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
      commentsCount: (json['commentsCount'] ?? json['commentscount']) is int
          ? (json['commentsCount'] ?? json['commentscount']) as int
          : int.tryParse(
                (json['commentsCount'] ?? json['commentscount']).toString(),
              ) ??
              0,
      lastEditedAt:
          (json['updatedAt'] is String ? json['updatedAt'] as String : null).use((v) => DateTime.parse(v)),
      author: author,
      comments: commentsJson != null
          ? [
              PaginationModel.fromJson(
                commentsJson,
                CommentModel.fromJson,
              ),
            ]
          : [],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DiscussionModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
