import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/constants/api_config.dart';
import 'package:inter_knot/helpers/normalize_markdown.dart';
import 'package:inter_knot/helpers/parse_html.dart';
import 'package:inter_knot/helpers/use.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/pagination.dart';
import 'package:markdown/markdown.dart' as md;

class CoverImage {
  final String url;
  final int? width;
  final int? height;

  CoverImage({
    required this.url,
    this.width,
    this.height,
  });
}

DiscussionModel parseDiscussionData(Map<String, dynamic> json) {
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
  final htmlBody = md.markdownToHtml(
    normalized,
    extensionSet: md.ExtensionSet.gitHubWeb,
  );

  final (:cover, :html) = parseHtml(htmlBody);
  final List<CoverImage> parsedCovers = [];

  CoverImage? normalizeCover(String? url, int? width, int? height) {
    if (url == null || url.isEmpty) return null;
    String finalUrl = url;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      finalUrl = url;
    } else if (url.startsWith('/')) {
      finalUrl = '${ApiConfig.baseUrl}$url';
    } else {
      finalUrl = '${ApiConfig.baseUrl}/$url';
    }
    return CoverImage(url: finalUrl, width: width, height: height);
  }

  final coverData = json['cover'];
  if (coverData is List) {
    for (final item in coverData) {
      if (item is Map<String, dynamic> && item['url'] != null) {
        final width = item['width'] as int?;
        final height = item['height'] as int?;
        final cover = normalizeCover(item['url'] as String?, width, height);
        if (cover != null) parsedCovers.add(cover);
      }
    }
  } else if (coverData is Map<String, dynamic> && coverData['url'] != null) {
    final width = coverData['width'] as int?;
    final height = coverData['height'] as int?;
    final cover = normalizeCover(coverData['url'] as String?, width, height);
    if (cover != null) parsedCovers.add(cover);
  }

  final List<CoverImage> covers = [];

  if (parsedCovers.isNotEmpty) {
    covers.addAll(parsedCovers);
  } else {
    final fragment = parseFragment(htmlBody);
    final firstImg = fragment.querySelector('img');
    final src = firstImg?.attributes['src'];
    // Try to parse width/height from img attributes if available (often not reliable in HTML strings but worth a try)
    final width = int.tryParse(firstImg?.attributes['width'] ?? '');
    final height = int.tryParse(firstImg?.attributes['height'] ?? '');

    final firstCover = normalizeCover(src ?? cover, width, height);
    if (firstCover != null) covers.add(firstCover);
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
    coverImages: covers,
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
    isRead: json['isRead'] == true,
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

class DiscussionModel {
  String title;
  bool isRead;
  String bodyHTML;
  String rawBodyText;
  List<CoverImage> coverImages;
  List<String> get covers => coverImages.map((e) => e.url).toList();
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
        // Filter out duplicates based on id
        final existingIds = comments.last.nodes.map((e) => e.id).toSet();
        final newNodes =
            pagination.nodes.where((e) => !existingIds.contains(e.id)).toList();

        comments.last.nodes.addAll(newNodes);
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
    required this.coverImages,
    // required this.number, // Removed
    required this.id,
    required this.createdAt,
    required this.commentsCount,
    required this.lastEditedAt,
    required this.author,
    this.isRead = false,
    required this.comments,
  });

  factory DiscussionModel.fromJson(Map<String, dynamic> json) =>
      parseDiscussionData(json);

  @override
  bool operator ==(Object other) => other is DiscussionModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
