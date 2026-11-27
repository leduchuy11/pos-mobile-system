import 'package:demo_store/data/datasources/cart_remote_datasource.dart';
import 'package:demo_store/data/model/cart_item_model.dart';
import 'package:demo_store/data/model/order_model.dart';
import 'package:demo_store/data/model/product_model.dart';
import 'package:flutter/foundation.dart';

class CartViewModel extends ChangeNotifier {
  final CartRemoteDataSource _dataSource = CartRemoteDataSource();

  final List<CartItemModel> _items = [];
  String? _token;
  String _orderNote = '';
  String _staffName = 'Nhân viên';
  String _paymentMethod = 'Tiền mặt';

  bool _isLoading = false;
  bool _isCheckingOut = false;
  String? _errorMessage;

  List<CartItemModel> get items => List.unmodifiable(_items);
  List<CartItemModel> get selectedItems =>
      _items.where((e) => e.isSelected).toList();

  String get orderNote => _orderNote;
  String get staffName => _staffName;
  String get paymentMethod => _paymentMethod;
  bool get isLoading => _isLoading;
  bool get isCheckingOut => _isCheckingOut;
  String? get errorMessage => _errorMessage;

  bool get isAllSelected =>
      _items.isNotEmpty && _items.every((e) => e.isSelected);

  int get totalQuantity =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  double get selectedSubTotal =>
      selectedItems.fold(0.0, (sum, item) => sum + item.subTotal);

  double get orderDiscountPercent {
    final total = selectedSubTotal;
    if (total <= 0) return 0;
    if (total > 5000000) return 15;
    if (total > 1000000) return 10;
    return 5;
  }

  double get orderDiscountAmount =>
      selectedSubTotal * (orderDiscountPercent / 100);

  double get afterDiscountAmount => selectedSubTotal - orderDiscountAmount;

  double get orderVatAmount => afterDiscountAmount * (kFixedVatPercent / 100);

  double get finalTotalAmount => afterDiscountAmount + orderVatAmount;

  /// Đồng bộ với AuthViewModel (tự gọi khi đăng nhập / đăng xuất)
  void syncAuth({required String? token, String? staffName}) {
    if (staffName != null && staffName.trim().isNotEmpty) {
      _staffName = staffName.trim();
    }

    if (_token == token) return;
    _token = token;

    if (_token == null) {
      _items.clear();
      _orderNote = '';
      _errorMessage = null;
      Future.microtask(notifyListeners);
    } else {
      Future.microtask(fetchCart);
    }
  }

  /// Tải lại toàn bộ giỏ hàng từ MySQL
  Future<void> fetchCart() async {
    final token = _token;
    if (token == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final serverItems = await _dataSource.getCart(token);
      _items
        ..clear()
        ..addAll(serverItems);
    } catch (e) {
      debugPrint('=== FETCH CART ERROR: $e ===');
      _errorMessage = _cleanError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Thêm sản phẩm vào giỏ và lưu xuống MySQL
  Future<bool> addToCart({
    required ProductModel product,
    required int quantity,
  }) async {
    final token = _token;
    if (token == null) {
      _errorMessage = 'Vui lòng đăng nhập lại';
      return false;
    }

    _errorMessage = null;
    try {
      final updatedItems = await _dataSource.addToCart(
        token: token,
        productId: product.id,
        quantity: quantity,
      );
      _items
        ..clear()
        ..addAll(updatedItems);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('=== ADD TO CART ERROR: $e ===');
      _errorMessage = _cleanError(e);
      notifyListeners();
      return false;
    }
  }

  /// Bật / tắt ô vuông tích chọn (Optimistic UI)
  Future<void> toggleItemSelection(int index, bool? value) async {
    final token = _token;
    if (token == null || index < 0 || index >= _items.length) return;

    final item = _items[index];
    final prevValue = item.isSelected;
    final nextValue = value ?? false;

    item.isSelected = nextValue;
    notifyListeners();

    try {
      await _dataSource.updateCartItem(
        token: token,
        productId: item.product.id,
        isSelected: nextValue,
      );
    } catch (e) {
      item.isSelected = prevValue;
      _errorMessage = _cleanError(e);
      notifyListeners();
    }
  }

  /// Chọn tất cả / bỏ chọn tất cả (Optimistic UI)
  Future<void> toggleSelectAll(bool? value) async {
    final token = _token;
    if (token == null || _items.isEmpty) return;

    final checked = value ?? false;
    final prevStates = _items.map((e) => e.isSelected).toList();

    for (final item in _items) {
      item.isSelected = checked;
    }
    notifyListeners();

    try {
      await _dataSource.toggleSelectAll(token: token, isSelected: checked);
    } catch (e) {
      for (int i = 0; i < _items.length; i++) {
        _items[i].isSelected = prevStates[i];
      }
      _errorMessage = _cleanError(e);
      notifyListeners();
    }
  }

  /// Tăng / giảm số lượng (Optimistic UI)
  Future<void> updateQuantity(int index, int newQty) async {
    final token = _token;
    if (token == null || index < 0 || index >= _items.length) return;

    final item = _items[index];
    final prevQty = item.quantity;

    if (newQty <= 0) {
      _items.removeAt(index);
    } else {
      item.quantity = newQty;
    }
    notifyListeners();

    try {
      await _dataSource.updateCartItem(
        token: token,
        productId: item.product.id,
        quantity: newQty,
      );
    } catch (e) {
      if (newQty <= 0) {
        _items.insert(index, item);
      } else {
        item.quantity = prevQty;
      }
      _errorMessage = _cleanError(e);
      notifyListeners();
    }
  }

  /// Xóa 1 sản phẩm khỏi giỏ (Optimistic UI)
  Future<void> removeAt(int index) async {
    final token = _token;
    if (token == null || index < 0 || index >= _items.length) return;

    final removedItem = _items.removeAt(index);
    notifyListeners();

    try {
      await _dataSource.removeCartItem(
        token: token,
        productId: removedItem.product.id,
      );
    } catch (e) {
      _items.insert(index, removedItem);
      _errorMessage = _cleanError(e);
      notifyListeners();
    }
  }

  void setOrderNote(String note) {
    _orderNote = note;
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  /// Thanh toán: gửi lên server lưu hóa đơn & tự xóa các món đã tích khỏi giỏ
  Future<OrderModel?> checkout() async {
    final token = _token;
    if (token == null || selectedItems.isEmpty || _isCheckingOut) return null;

    _isCheckingOut = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final order = await _dataSource.createOrder(
        token: token,
        paymentMethod: _paymentMethod,
        note: _orderNote.trim(),
        staffName: _staffName,
      );

      // Xóa các món đã thanh toán trên UI (khớp với DB đã xóa trong Transaction)
      _items.removeWhere((e) => e.isSelected);
      _orderNote = '';
      _isCheckingOut = false;
      notifyListeners();
      return order;
    } catch (e) {
      debugPrint('=== CHECKOUT ERROR: $e ===');
      _errorMessage = _cleanError(e);
      _isCheckingOut = false;
      notifyListeners();
      return null;
    }
  }

  String _cleanError(Object e) {
    final msg = e.toString();
    if (msg.startsWith('Exception: ')) {
      return msg.replaceFirst('Exception: ', '');
    }
    return 'Không thể kết nối tới máy chủ';
  }
}