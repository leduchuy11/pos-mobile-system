import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:demo_store/data/model/product_model.dart';
import 'package:demo_store/viewmodel/home_viewmodel.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  static final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // PHẦN TRÊN: Ảnh hoặc Video (Luồng 3)
            Expanded(
              flex: 6,
              child: Selector<HomeViewModel, ProductMedia?>(
                selector: (_, vm) => vm.getMedia(product.id),
                builder: (_, media, __) {
                  // Đang chờ Luồng 3 trả về link
                  if (media == null) {
                    return Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  // Luồng 3 đã trả về link -> tải ảnh hoặc phát video từ URL
                  return media.mediaType == 'video'
                      ? _VideoMediaBox(url: media.mediaUrl)
                      : _ImageMediaBox(url: media.mediaUrl);
                },
              ),
            ),

            const Divider(height: 1, thickness: 1),

            // PHẦN DƯỚI: Tên SP + Tồn kho (phải) + Giá
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Hàng 1: Tên SP & Tồn kho (Luồng 2 - chỉ rebuild đúng chỗ này)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Selector<HomeViewModel, int?>(
                          selector: (_, vm) => vm.getStock(product.id),
                          builder: (_, stock, __) {
                            if (stock == null) {
                              return const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              );
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Tồn: $stock',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    // Hàng 2: Giá + Đơn vị tính
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_currencyFormat.format(product.price)} / ${product.unit}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget tải ảnh bất đồng bộ có cache RAM + Disk
class _ImageMediaBox extends StatelessWidget {
  final String url;
  const _ImageMediaBox({required this.url});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 400, // Tối ưu RAM khi cuộn nhiều trang
      placeholder: (_, __) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }
}

/// Widget Video an toàn: chỉ khởi tạo VideoPlayerController khi bấm Play và dispose ngay khi hủy
class _VideoMediaBox extends StatefulWidget {
  final String url;
  const _VideoMediaBox({required this.url});

  @override
  State<_VideoMediaBox> createState() => _VideoMediaBoxState();
}

class _VideoMediaBoxState extends State<_VideoMediaBox> {
  VideoPlayerController? _controller;
  bool _isLoading = false;

  Future<void> _togglePlay() async {
    if (_controller == null) {
      setState(() => _isLoading = true);
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _controller = ctrl;
        _isLoading = false;
      });
    } else {
      if (_controller!.value.isPlaying) {
        await _controller!.pause();
      } else {
        await _controller!.play();
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null && _controller!.value.isInitialized) {
      return GestureDetector(
        onTap: _togglePlay,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
            if (!_controller!.value.isPlaying)
              const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.play_arrow, color: Colors.white),
              ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _isLoading ? null : _togglePlay,
      child: Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: _isLoading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.play_arrow, color: Colors.white),
            ),
            SizedBox(height: 4),
            Text(
              'Video <5MB',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}