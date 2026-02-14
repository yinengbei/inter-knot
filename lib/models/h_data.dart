import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/helpers/use.dart';
import 'package:inter_knot/models/discussion.dart';

class HDataModel {
  static final _zeroDate = DateTime.fromMillisecondsSinceEpoch(0);
  static final api = Get.find<Api>();
  static final discussionsCache = <String, Future<DiscussionModel?>>{};
  static const int _maxCacheSize = 50;

  String id;
  DateTime updatedAt;
  bool isPinned;
  bool get isPin => isPinned;
  String get url => '';

  // 临时存储原始 documentId，以便 API 调用
  // String? documentId; // 不需要了，id 就是 documentId

  HDataModel({
    required this.id,
    required DateTime? updatedAt,
    required this.isPinned,
  }) : updatedAt = updatedAt ?? _zeroDate;

  Future<DiscussionModel?> get discussion {
    if (discussionsCache.containsKey(id)) {
      // LRU: Move to end
      final future = discussionsCache.remove(id)!;
      discussionsCache[id] = future;
      return future;
    }

    if (discussionsCache.length >= _maxCacheSize) {
      final keyToRemove = discussionsCache.keys.first;
      discussionsCache.remove(keyToRemove);
    }

    return discussionsCache[id] = api.getDiscussion(id);
  }

  factory HDataModel.fromJson(Map<String, dynamic> json) {
    // 优先取 documentId，其次是 id (转 String)，最后 fallback 到 number (转 String)
    final docId = json['documentId'] as String? ??
        json['id']?.toString() ??
        json['number']?.toString() ??
        '';

    final hData = HDataModel(
      id: docId,
      updatedAt: (json['updatedAt'] as String?).use((v) => DateTime.parse(v)),
      isPinned: false,
    );

    // Optimization: If json contains title, it might be a full object.
    // Try to parse it and seed the cache to avoid N+1 requests.
    if (json['title'] != null) {
      try {
        final discussion = DiscussionModel.fromJson(json);
        discussionsCache[docId] = Future.value(discussion);
      } catch (e) {
        // parsing failed, ignore
      }
    }

    return hData;
  }

  factory HDataModel.fromPinnedJson(Map<String, dynamic> json) {
    final docId = json['documentId'] as String? ??
        json['id']?.toString() ??
        json['number']?.toString() ??
        '';

    return HDataModel(
      id: docId,
      updatedAt: (json['updatedAt'] as String?).use((v) => DateTime.parse(v)),
      isPinned: true,
    );
  }

  factory HDataModel.fromStr(String str) {
    final s = str.split(',');
    return HDataModel(
      id: s[0],
      updatedAt: DateTime.parse(s[1]),
      isPinned: false,
    );
  }

  @override
  bool operator ==(Object other) => other is HDataModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
