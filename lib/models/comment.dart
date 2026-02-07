import 'package:inter_knot/helpers/parse_html.dart';
import 'package:inter_knot/helpers/use.dart';
import 'package:inter_knot/models/author.dart';

String _normalizeMarkdown(String input) {
  var out = input;
  out = out.replaceAll(
    RegExp(r'<div class="web-selectable-region-context-menu"[^>]*></div>'),
    '',
  );
  out = out.replaceAllMapped(
    RegExp(r'\\([\\`*_{}\[\]()#+\-.!])'),
    (m) => m[1]!,
  );
  out = out.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\(\[([^\]]+)\]\(([^)\s]+)\)\)\)+(?=\s|$)'),
    (m) => '![${m[1]}](${m[3]})',
  );
  out = out.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\(([^)\s]+)\)\)(?=\s|$)'),
    (m) => '![${m[1]}](${m[2]})',
  );
  return out;
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
    final normalized = _normalizeMarkdown(content);
    final (:cover, :html) = parseHtml(normalized, true);
    
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
