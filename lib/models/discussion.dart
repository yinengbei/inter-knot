import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/helpers/parse_html.dart';
import 'package:inter_knot/helpers/normalize_markdown.dart';
import 'package:inter_knot/helpers/use.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/pagination.dart';
import 'package:markdown/markdown.dart' as md;

String _shortenForLog(String input, [int max = 400]) {
  if (input.length <= max) return input;
  return '${input.substring(0, max)}...<${input.length} chars>';
}

class DiscussionModel {
  String title;
  String bodyHTML;
  String rawBodyText;
  List<String> covers;
  String? get cover => covers.isNotEmpty ? covers.first : null;
  String id;
  // int number; // Removed, merged into id
  DateTime createdAt;
  DateTime? lastEditedAt;
  int commentsCount;
  AuthorModel author;
  List<PaginationModel<CommentModel>> comments;
  String get bodyText {
    // 移除 Markdown 图片 ![alt](url)
    var text =
        rawBodyText.replaceAll(RegExp(r'!\[.*?\]\(.*?\)', dotAll: true), '');
    // 移除 HTML img 标签
    text = text.replaceAll(
        RegExp('<img[^>]*>', caseSensitive: false, dotAll: true), '');
    // 移除多余的空行，但保留段落结构 (最多保留两个换行符)
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

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
    required this.covers,
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
    
    final normalized = normalizeMarkdown(rawBody);

    // Convert Markdown to HTML
    if (kDebugMode) {
      debugPrint('Discussion raw text: ${_shortenForLog(rawBody)}');
      debugPrint('Discussion normalized: ${_shortenForLog(normalized)}');
    }

    final htmlBody = md.markdownToHtml(
      normalized,
      extensionSet: md.ExtensionSet.gitHubWeb,
    );

    final (:cover, :html) = parseHtml(htmlBody);
    if (kDebugMode) {
      debugPrint('Discussion HTML: ${_shortenForLog(html)}');
    }
    // 处理封面图: 优先取 json['cover']，如果没有则尝试从 parseHtml 获取
    final List<String> parsedCovers = [];
    final coverData = json['cover'];

    if (coverData is List) {
      for (final item in coverData) {
        if (item is Map<String, dynamic> && item['url'] != null) {
          String url = item['url'] as String;
          if (!url.startsWith('http')) {
            url = 'https://ik.tiwat.cn$url';
          }
          parsedCovers.add(url);
        }
      }
    } else if (coverData is Map<String, dynamic> && coverData['url'] != null) {
      String url = coverData['url'] as String;
      if (!url.startsWith('http')) {
        url = 'https://ik.tiwat.cn$url';
      }
      parsedCovers.add(url);
    }

    // Fallback to HTML parsed cover if no explicit covers found
    if (parsedCovers.isEmpty && cover != null) {
      parsedCovers.add(cover);
    }

    final commentsJson = json['comments'] as Map<String, dynamic>?;

    final authorData = json['author'];
    final author = authorData is Map<String, dynamic>
        ? AuthorModel.fromJson(authorData)
        : AuthorModel(
            login: 'unknown',
            avatar: '',
            name: 'Unknown',
          );

    return DiscussionModel(
      title: json['title'] is String
          ? json['title'] as String
          : (json['title']?.toString() ?? ''),
      bodyHTML: html,
      covers: parsedCovers,
      rawBodyText: normalized,
      // number: ... Removed
      id: json['documentId'] as String? ??
          json['id']?.toString() ??
          '', // 优先 documentId
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      commentsCount: (json['commentsCount'] ?? json['commentscount']) is int
          ? (json['commentsCount'] ?? json['commentscount']) as int
          : int.tryParse(
                (json['commentsCount'] ?? json['commentscount']).toString(),
              ) ??
              0,
      lastEditedAt:
          (json['updatedAt'] is String ? json['updatedAt'] as String : null)
              .use((v) => DateTime.parse(v)),
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
  bool operator ==(Object other) => other is DiscussionModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
