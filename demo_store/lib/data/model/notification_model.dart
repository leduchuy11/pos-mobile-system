class NotificationModel {
  final int id;
  final int? orderId;
  final String title;
  final String body;
  bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.orderId,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['id'] as num).toInt(),
      orderId: json['order_id'] != null ? (json['order_id'] as num).toInt() : null,
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }
}