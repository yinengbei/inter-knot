import 'package:flutter/foundation.dart';
import 'package:inter_knot/helpers/parse_html.dart';
import 'package:inter_knot/helpers/normalize_markdown.dart';
import 'package:inter_knot/helpers/use.dart';
import 'package:inter_knot/models/author.dart';

String _shortenForLog(String input, [int max = 400]) {
  if (input.length <= max) return input;
  return '${input.substring(0, max)}...<${input.length} chars>';
}

class CommentModel {
  final AuthorModel author;
  final String bodyHTML;
  final DateTime createdAt;
  final DateTime? lastEditedAt;
  final replies = <CommentModel>{};
  final String id;
  final String url;

  CommentModel({
    required this.author,
    required this.bodyHTML,
    required this.createdAt,
    required this.lastEditedAt,
    required Iterable<CommentModel> replies,
    required this.id,
    required this.url,
  }) {
    this.replies.addAll(replies);
  }

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    // 处理 content 字段（可能是 Markdown 或 HTML）
    final content = json['content'] as String? ?? json['bodyHTML'] as String? ?? '';
    final normalized = normalizeMarkdown(content);
    if (kDebugMode) {
      debugPrint('Comment raw text: ${_shortenForLog(content)}');
      debugPrint('Comment normalized: ${_shortenForLog(normalized)}');
    }
    final (:cover, :html) = parseHtml(normalized, true);
    if (kDebugMode) {
      debugPrint('Comment HTML: ${_shortenForLog(html)}');
    }
    
    return CommentModel(
      author: AuthorModel.fromJson(json['author'] as Map<String, dynamic>),
      bodyHTML: html,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastEditedAt:
          (json['updatedAt'] as String?).use((v) => DateTime.parse(v)),
      replies: [], // Replies not supported in backend yet
      id: (json['documentId'] as String?) ?? json['id']?.toString() ?? '',
      url: '', // URL not supported yet
    );
  }

  @override
  bool operator ==(Object other) => other is CommentModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
