/// Dữ liệu của Luồng 1: Thông tin sản phẩm cơ bản
class ProductModel {
  final int id;
  final String code;
  final String name;
  final String unit;
  final double price;
  final double discountPercent;
  final double vatPercent;

  const ProductModel({
    required this.id,
    required this.code,
    required this.name,
    required this.unit,
    required this.price,
    required this.discountPercent,
    required this.vatPercent,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: (json['id'] as num).toInt(),
      code: json['code'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String,
      price: (json['price'] as num).toDouble(),
      discountPercent: (json['discount_percent'] as num).toDouble(),
      vatPercent: (json['vat_percent'] as num).toDouble(),
    );
  }
}

/// Dữ liệu của Luồng 3: Media
class ProductMedia {
  final int productId;
  final String mediaType; // 'image' hoặc 'video'
  final String mediaUrl;  // Link HTTPS

  const ProductMedia({
    required this.productId,
    required this.mediaType,
    required this.mediaUrl,
  });

  factory ProductMedia.fromJson(Map<String, dynamic> json) {
    return ProductMedia(
      productId: (json['product_id'] as num).toInt(),
      mediaType: json['media_type'] as String,
      mediaUrl: json['media_url'] as String,
    );
  }
}