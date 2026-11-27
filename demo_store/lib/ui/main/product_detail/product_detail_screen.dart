import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:demo_store/data/model/product_model.dart';
import 'package:demo_store/viewmodel/cart_viewmodel.dart';
import 'package:demo_store/viewmodel/home_viewmodel.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static final _numberFormat = NumberFormat('#,###', 'vi_VN');

  int _quantity = 1;
  bool _isAdding = false;

  void _decreaseQty() {
    if (_quantity > 0) {
      setState(() => _quantity--);
    }
  }

  void _increaseQty(int? stock) {
    if (stock != null && _quantity >= stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tồn kho hiện tại chỉ còn $stock ${widget.product.unit}'),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }
    setState(() => _quantity++);
  }

  Future<void> _handleAddToCart(int? stock) async {
    if (_isAdding) return;

    if (_quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn số lượng lớn hơn 0'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    if (stock != null && _quantity > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Số lượng vượt quá tồn kho ($stock)')),
      );
      return;
    }

    setState(() => _isAdding = true);

    final cartVm = context.read<CartViewModel>();
    final success = await cartVm.addToCart(
      product: widget.product,
      quantity: _quantity,
    );

    if (!mounted) return;
    setState(() => _isAdding = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm $_quantity ${widget.product.unit} vào giỏ hàng'),
          duration: const Duration(seconds: 1),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cartVm.errorMessage ?? 'Không thể thêm vào giỏ hàng'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return Scaffold(
      backgroundColor: Colors.white,
      // 1. AppBar: Nút back + Tên SP + gạch chân
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          p.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade300),
        ),
      ),

      // 2. Nội dung giữa: Ảnh/Video + Thông tin SP
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Khung Ảnh / Video (Luồng 3)
            SizedBox(
              height: 280,
              width: double.infinity,
              child: Selector<HomeViewModel, ProductMedia?>(
                selector: (_, vm) => vm.getMedia(p.id),
                builder: (_, media, __) {
                  if (media == null) {
                    return Container(
                      color: Colors.grey.shade100,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    );
                  }
                  if (media.mediaType == 'video') {
                    return _DetailVideoPlayer(url: media.mediaUrl);
                  }
                  return CachedNetworkImage(
                    imageUrl: media.mediaUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Colors.grey.shade100,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey.shade100,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),

            Divider(height: 1, thickness: 1, color: Colors.grey.shade300),

            // Thông tin sản phẩm: Mã SP, Tên SP, Tồn kho, Giá
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(label: 'Mã SP:', value: p.code),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Tên SP:', value: p.name, isBold: true),
                  const SizedBox(height: 12),

                  // Tồn kho (tự động cập nhật từ Luồng 2)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Tồn kho: ',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      Selector<HomeViewModel, int?>(
                        selector: (_, vm) => vm.getStock(p.id),
                        builder: (_, stock, __) {
                          if (stock == null) {
                            return const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Đang tải...',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            );
                          }
                          return Text(
                            '$stock ${p.unit}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Giá: 100.000 vnđ
                  Row(
                    children: [
                      const Text(
                        'Giá: ',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      Text(
                        '${_numberFormat.format(p.price)} vnđ / ${p.unit}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // 3. Đáy màn hình: Số lượng < 1 > + Nút "Thêm vào giỏ hàng"
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Selector<HomeViewModel, int?>(
              selector: (_, vm) => vm.getStock(p.id),
              builder: (_, stock, __) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hàng chọn số lượng: Số lượng      < 1 >
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Số lượng',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _quantity > 0 ? _decreaseQty : null,
                              icon: const Icon(Icons.chevron_left, size: 28),
                              visualDensity: VisualDensity.compact,
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 32),
                              alignment: Alignment.center,
                              child: Text(
                                '$_quantity',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _increaseQty(stock),
                              icon: const Icon(Icons.chevron_right, size: 28),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    FilledButton(
                      onPressed: _isAdding ? null : () => _handleAddToCart(stock),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      child: _isAdding
                          ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        'Thêm vào giỏ hàng',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ',
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailVideoPlayer extends StatefulWidget {
  final String url;
  const _DetailVideoPlayer({required this.url});

  @override
  State<_DetailVideoPlayer> createState() => _DetailVideoPlayerState();
}

class _DetailVideoPlayerState extends State<_DetailVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        _controller.setLooping(true);
        _controller.play();
        setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Colors.white),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying ? _controller.pause() : _controller.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(color: Colors.black),
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          if (!_controller.value.isPlaying)
            const CircleAvatar(
              radius: 26,
              backgroundColor: Colors.black54,
              child: Icon(Icons.play_arrow, color: Colors.white, size: 32),
            ),
        ],
      ),
    );
  }
}