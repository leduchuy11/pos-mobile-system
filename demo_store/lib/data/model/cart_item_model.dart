import 'product_model.dart';

const double kFixedVatPercent = 8.0;

class CartItemModel {
  final ProductModel product;
  int quantity;
  bool isSelected;

  CartItemModel({
    required this.product,
    this.quantity = 1,
    this.isSelected = true,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      product: ProductModel.fromJson(json['product'] as Map<String, dynamic>),
      quantity: (json['quantity'] as num).toInt(),
      isSelected: json['is_selected'] == true || json['is_selected'] == 1,
    );
  }

  /// Thành tiền chưa chiết khấu & chưa VAT của riêng dòng hàng
  double get subTotal => product.price * quantity;
}