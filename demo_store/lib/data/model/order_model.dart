double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

class OrderItemModel {
  final int productId;
  final String productCode;
  final String productName;
  final String unit;
  final double unitPrice;
  final int quantity;
  final double lineTotal;

  const OrderItemModel({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      productId: (json['product_id'] as num).toInt(),
      productCode: json['product_code'] as String,
      productName: json['product_name'] as String,
      unit: json['unit'] as String,
      unitPrice: _toDouble(json['unit_price']),
      quantity: (json['quantity'] as num).toInt(),
      lineTotal: _toDouble(json['line_total']),
    );
  }
}

class OrderModel {
  final int id;
  final String orderCode;
  final String staffName;
  final String paymentMethod;
  final double subTotal;
  final double discountPercent;
  final double discountAmount;
  final double vatPercent;
  final double vatAmount;
  final double finalTotal;
  final String note;
  final DateTime createdAt;
  final List<OrderItemModel> items;

  const OrderModel({
    required this.id,
    required this.orderCode,
    required this.staffName,
    required this.paymentMethod,
    required this.subTotal,
    required this.discountPercent,
    required this.discountAmount,
    required this.vatPercent,
    required this.vatAmount,
    required this.finalTotal,
    required this.note,
    required this.createdAt,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? []);
    return OrderModel(
      id: (json['id'] as num).toInt(),
      orderCode: json['order_code'] as String,
      staffName: (json['staff_name'] as String?) ?? '',
      paymentMethod: (json['payment_method'] as String?) ?? 'Tiền mặt',
      subTotal: _toDouble(json['sub_total']),
      discountPercent: _toDouble(json['discount_percent']),
      discountAmount: _toDouble(json['discount_amount']),
      vatPercent: _toDouble(json['vat_percent']),
      vatAmount: _toDouble(json['vat_amount']),
      finalTotal: _toDouble(json['final_total']),
      note: (json['note'] as String?) ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
      items: rawItems
          .map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}