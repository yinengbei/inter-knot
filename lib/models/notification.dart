import 'package:inter_knot/models/author.dart';

enum NotificationType {
  comment('comment'),
  reply('reply'),
  like('like'),
  favorite('favorite'),
  mention('mention'),
  system('system');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.system,
    );
  }
}

class NotificationModel {
  final int id;
  final String? documentId;
  final NotificationType type;
  final bool isRead;
  final AuthorModel? sender;
  final String? articleDocumentId;
  final String? articleTitle;
  final int? commentId;
  final String? commentContent;
  final String? targetType;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationModel({
    required this.id,
    this.documentId,
    required this.type,
    required this.isRead,
    this.sender,
    this.articleDocumentId,
    this.articleTitle,
    this.commentId,
    this.commentContent,
    this.targetType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'system';
    final type = NotificationType.fromString(typeStr);

    AuthorModel? sender;
    final senderData = json['sender'];
    if (senderData is Map<String, dynamic>) {
      try {
        final authorData = senderData['author'];
        if (authorData is Map<String, dynamic>) {
          sender = AuthorModel.fromJson({
            'id': senderData['id'],
            'username': senderData['username'],
            'name': authorData['name'],
            'avatar': authorData['avatar'],
            'level': senderData['level'],
          });
        } else {
          sender = AuthorModel.fromJson({
            'id': senderData['id'],
            'username': senderData['username'],
            'name': senderData['username'],
          });
        }
      } catch (e) {
        sender = null;
      }
    }

    String? articleDocumentId;
    String? articleTitle;
    final articleData = json['article'] ?? json['Article'];
    if (articleData is Map<String, dynamic>) {
      articleDocumentId = articleData['documentId'] as String?;
      articleTitle = articleData['title'] as String?;
    }

    int? commentId;
    String? commentContent;
    final commentData = json['comment'] ?? json['Comment'];
    if (commentData is Map<String, dynamic>) {
      commentId = commentData['id'] as int?;
      commentContent = commentData['content'] as String?;
    } else if (commentData is int) {
      commentId = commentData;
    }

    final documentId = json['documentId'] as String?;
    final id = json['id'] as int? ?? (documentId?.hashCode ?? 0);

    final targetType = json['targetType'] as String?;

    return NotificationModel(
      id: id,
      documentId: documentId,
      type: type,
      isRead: json['isRead'] as bool? ?? false,
      sender: sender,
      articleDocumentId: articleDocumentId,
      articleTitle: articleTitle,
      commentId: commentId,
      commentContent: commentContent,
      targetType: targetType,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String? ?? json['createdAt'] as String),
    );
  }

  String getTitle() {
    switch (type) {
      case NotificationType.comment:
        return '${sender?.name ?? '有人'}评论了你的帖子';
      case NotificationType.reply:
        return '${sender?.name ?? '有人'}回复了你的评论';
      case NotificationType.like:
        return (targetType == 'comment' || commentId != null)
            ? '${sender?.name ?? '有人'}点赞了你的评论'
            : '${sender?.name ?? '有人'}点赞了你的帖子';
      case NotificationType.favorite:
        return '${sender?.name ?? '有人'}收藏了你的帖子';
      case NotificationType.mention:
        return '${sender?.name ?? '有人'}提到了你';
      case NotificationType.system:
        return '系统通知';
    }
  }

  String getDescription() {
    if (commentContent != null && commentContent!.isNotEmpty) {
      final content = commentContent!.replaceAll(RegExp(r'<[^>]*>'), '');
      return content.length > 50 ? '${content.substring(0, 50)}...' : content;
    }
    if (articleTitle != null && articleTitle!.isNotEmpty) {
      return articleTitle!;
    }
    return '';
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
