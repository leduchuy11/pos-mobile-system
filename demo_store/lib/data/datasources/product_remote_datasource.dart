import 'dart:convert';
import 'package:demo_store/data/datasources/api_config.dart';
import 'package:demo_store/data/model/product_model.dart';
import 'package:http/http.dart' as http;

const int kPageSize = 10;

class ProductPageResult {
  final List<ProductModel> items;
  final int totalPages;
  final int totalProducts;

  const ProductPageResult({
    required this.items,
    required this.totalPages,
    required this.totalProducts,
  });
}

class ProductRemoteDataSource {
  static String get _baseUrl => '${ApiConfig.baseUrl}/products';

  /// LUỒNG 1: Load 10 sản phẩm cơ bản theo trang từ MySQL
  Future<ProductPageResult> fetchProductsByPage(
      int page, {
        int limit = kPageSize,
      }) async {
    final uri = Uri.parse('$_baseUrl?page=$page&limit=$limit');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && body['success'] == true) {
      final data = body['data'] as Map<String, dynamic>;
      final rawItems = data['items'] as List<dynamic>;

      final items = rawItems
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();

      return ProductPageResult(
        items: items,
        totalPages: (data['totalPages'] as num).toInt(),
        totalProducts: (data['totalProducts'] as num).toInt(),
      );
    }

    throw Exception(body['message'] ?? 'Không tải được danh sách sản phẩm');
  }

  /// LUỒNG 2: Load tồn kho cho 1 sản phẩm
  Future<int> fetchStockForProduct(int productId) async {
    final uri = Uri.parse('$_baseUrl/$productId/stock');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && body['success'] == true) {
      final data = body['data'] as Map<String, dynamic>;
      return (data['stock'] as num).toInt();
    }

    throw Exception(body['message'] ?? 'Không tải được tồn kho');
  }

  /// LUỒNG 3: Load link ảnh / video độc lập cho 1 sản phẩm
  Future<ProductMedia?> fetchMediaForProduct(int productId) async {
    final uri = Uri.parse('$_baseUrl/$productId/media');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && body['success'] == true) {
      return ProductMedia.fromJson(body['data'] as Map<String, dynamic>);
    }

    return null;
  }
}