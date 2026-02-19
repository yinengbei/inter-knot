import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';

class CategoryModel {
  final String documentId;  // String ID for display/reference
  final int? numericId;     // Numeric ID for relations
  final String name;
  final String? slug;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CategoryModel({
    required this.documentId,
    this.numericId,
    required this.name,
    this.slug,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final documentId = json['documentId'] as String? ?? json['id']?.toString() ?? '';
    final numericId = json['id'] is int ? json['id'] as int : null;
    final attributes = json['attributes'] as Map<String, dynamic>?;

    if (attributes != null) {
      return CategoryModel(
        documentId: documentId,
        numericId: numericId,
        name: attributes['name'] as String? ?? '',
        slug: attributes['slug'] as String?,
        description: attributes['description'] as String?,
        createdAt: attributes['createdAt'] is String
            ? DateTime.parse(attributes['createdAt'] as String)
            : null,
        updatedAt: attributes['updatedAt'] is String
            ? DateTime.parse(attributes['updatedAt'] as String)
            : null,
      );
    }

    return CategoryModel(
      documentId: documentId,
      numericId: numericId,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String?,
      description: json['description'] as String?,
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] is String
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'documentId': documentId,
      'name': name,
      if (slug != null) 'slug': slug,
      if (description != null) 'description': description,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) => other is CategoryModel && other.documentId == documentId;

  @override
  int get hashCode => documentId.hashCode;

  @override
  String toString() => 'CategoryModel(documentId: $documentId, name: $name, slug: $slug)';
}

class CategoryController extends GetxController {
  final categories = <CategoryModel>[].obs;
  final isLoading = false.obs;
  final selectedCategories = <CategoryModel>[].obs;

  Api get api => Get.find<Api>();

  Future<void> fetchCategories() async {
    isLoading.value = true;
    try {
      final result = await api.getCategories();
      categories.assignAll(result);
    } finally {
      isLoading.value = false;
    }
  }

  void toggleCategory(CategoryModel category) {
    if (selectedCategories.contains(category)) {
      selectedCategories.remove(category);
    } else {
      selectedCategories.add(category);
    }
  }

  void clearSelection() {
    selectedCategories.clear();
  }

  List<String> get selectedCategoryDocumentIds =>
      selectedCategories.map((c) => c.documentId).toList();
}
