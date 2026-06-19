class BannerModel {
  final String id;
  final String imageUrl;
  final bool isActive;
  final String name;
  final int order;

  const BannerModel({
    required this.id,
    required this.imageUrl,
    required this.isActive,
    required this.name,
    required this.order,
  });

  factory BannerModel.fromFirestore(String docId, Map<String, dynamic>? data) {
    if (data == null) {
      return BannerModel(
        id: docId,
        imageUrl: '',
        isActive: false,
        name: '',
        order: 0,
      );
    }

    return BannerModel(
      id: docId,
      imageUrl: data['imageUrl'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? false,
      name: data['name'] as String? ?? '',
      order: data['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl,
      'isActive': isActive,
      'name': name,
      'order': order,
    };
  }
}
