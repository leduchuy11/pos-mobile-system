import 'package:demo_store/data/datasources/product_remote_datasource.dart';
import 'package:demo_store/data/model/product_model.dart';
import 'package:flutter/foundation.dart';

class HomeViewModel extends ChangeNotifier {
  final ProductRemoteDataSource _dataSource;

  HomeViewModel(this._dataSource);

  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;

  bool _isLoadingPage = false;
  bool get isLoadingPage => _isLoadingPage;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _currentPage = 1;
  int get currentPage => _currentPage;

  int _totalPages = 1;
  int get totalPages => _totalPages;

  List<ProductModel> _products = [];
  List<ProductModel> get products => _products;

  // Cache riêng cho Luồng 2 (Tồn kho) & Luồng 3 (Link Ảnh / Video)
  final Map<int, int> _stockCache = {};
  final Set<int> _loadingStockIds = {};

  final Map<int, ProductMedia> _mediaCache = {};
  final Set<int> _loadingMediaIds = {};

  int _pageRequestToken = 0;
  bool _isDisposed = false;

  int? getStock(int productId) => _stockCache[productId];
  ProductMedia? getMedia(int productId) => _mediaCache[productId];

  Future<void> initialize() async {
    _isInitializing = true;
    _errorMessage = null;
    _safeNotify();

    await loadPage(1);

    _isInitializing = false;
    _safeNotify();
  }

  /// Kích hoạt 3 luồng song song cho 10 sản phẩm của trang
  Future<void> loadPage(int page) async {
    if (page < 1 || (_products.isNotEmpty && page > _totalPages)) return;

    final requestToken = ++_pageRequestToken;
    _isLoadingPage = true;
    _errorMessage = null;
    _safeNotify();

    try {
      // 1. LUỒNG 1: Gọi API lấy 10 sản phẩm cơ bản -> hiển thị lên UI ngay
      final result = await _dataSource.fetchProductsByPage(page);

      // Nếu người dùng đã bấm sang trang khác trong lúc chờ mạng thì bỏ qua kết quả cũ
      if (requestToken != _pageRequestToken) return;

      _currentPage = page;
      _totalPages = result.totalPages > 0 ? result.totalPages : 1;
      _products = result.items;
      _isLoadingPage = false;
      _safeNotify();

      // 2. LUỒNG 2 & LUỒNG 3: Chạy song song cho từng sản phẩm (KHÔNG await chặn vòng lặp)
      for (final product in _products) {
        _loadStockStream(product.id); // Luồng 2: Tồn kho (sleep ở Node.js)
        _loadMediaStream(product.id); // Luồng 3: Link ảnh/video từ MySQL
      }
    } catch (e) {
      if (requestToken != _pageRequestToken) return;
      debugPrint('=== LOAD PAGE ERROR: $e ===');
      _errorMessage = 'Không thể tải danh sách sản phẩm. Vui lòng thử lại.';
      _isLoadingPage = false;
      _safeNotify();
    }
  }

  /// Xử lý Luồng 2 độc lập
  Future<void> _loadStockStream(int productId) async {
    if (_stockCache.containsKey(productId) ||
        _loadingStockIds.contains(productId)) {
      return;
    }

    _loadingStockIds.add(productId);
    try {
      final stock = await _dataSource.fetchStockForProduct(productId);
      _stockCache[productId] = stock;
      _safeNotify();
    } catch (e) {
      debugPrint('=== LOAD STOCK #$productId ERROR: $e ===');
    } finally {
      _loadingStockIds.remove(productId);
    }
  }

  /// Xử lý Luồng 3 độc lập
  Future<void> _loadMediaStream(int productId) async {
    if (_mediaCache.containsKey(productId) ||
        _loadingMediaIds.contains(productId)) {
      return;
    }

    _loadingMediaIds.add(productId);
    try {
      final media = await _dataSource.fetchMediaForProduct(productId);
      if (media != null) {
        _mediaCache[productId] = media;
        _safeNotify();
      }
    } catch (e) {
      debugPrint('=== LOAD MEDIA #$productId ERROR: $e ===');
    } finally {
      _loadingMediaIds.remove(productId);
    }
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}