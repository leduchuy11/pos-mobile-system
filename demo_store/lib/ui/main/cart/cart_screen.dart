import 'package:demo_store/data/model/cart_item_model.dart';
import 'package:demo_store/data/model/order_model.dart';
import 'package:demo_store/viewmodel/cart_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:demo_store/ui/main/invoice/invoice_preview_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static final _numberFormat = NumberFormat('#,###', 'vi_VN');
  static const _paymentMethods = ['Tiền mặt', 'Chuyển khoản', 'Quẹt thẻ'];

  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final initialNote = context.read<CartViewModel>().orderNote;
    _noteController = TextEditingController(text: initialNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _formatMoney(double value) => '${_numberFormat.format(value.round())} vnđ';

  Future<void> _handleCheckout(CartViewModel vm) async {
    if (vm.selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng tích chọn ít nhất 1 sản phẩm để thanh toán'),
        ),
      );
      return;
    }

    vm.setOrderNote(_noteController.text.trim());
    final createdOrder = await vm.checkout();

    if (!mounted) return;

    if (createdOrder != null) {
      _noteController.clear();
      _showCheckoutSuccessDialog(createdOrder);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? 'Thanh toán thất bại'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  void _showCheckoutSuccessDialog(OrderModel order) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Colors.green,
          size: 52,
        ),
        title: const Text(
          'Thanh toán thành công',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mã đơn: ${order.orderCode}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Tổng tiền: ${_formatMoney(order.finalTotal)}',
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Thoát'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogCtx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoicePreviewScreen(order: order),
                ),
              );
            },
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('In hóa đơn'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Giỏ hàng',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        actions: [
          Consumer<CartViewModel>(
            builder: (_, vm, __) {
              if (vm.items.isEmpty) return const SizedBox.shrink();
              return Row(
                children: [
                  const Text('Tất cả', style: TextStyle(fontSize: 13)),
                  Checkbox(
                    value: vm.isAllSelected,
                    onChanged: vm.toggleSelectAll,
                  ),
                ],
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade300),
        ),
      ),
      body: Consumer<CartViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading && vm.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: vm.fetchCart,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Giỏ hàng đang trống',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // 1. Danh sách sản phẩm trong giỏ (kéo xuống để đồng bộ lại từ DB)
              Expanded(
                child: Container(
                  color: Colors.grey.shade200,
                  child: RefreshIndicator(
                    onRefresh: vm.fetchCart,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: vm.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = vm.items[index];
                        return _CartItemTile(
                          item: item,
                          formattedPrice: _formatMoney(item.product.price),
                          onCheckChanged: (val) =>
                              vm.toggleItemSelection(index, val),
                          onDecrease: () =>
                              vm.updateQuantity(index, item.quantity - 1),
                          onIncrease: () =>
                              vm.updateQuantity(index, item.quantity + 1),
                          onDelete: () => vm.removeAt(index),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // 2. Khối tính tiền đơn hàng
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade400, width: 1.2),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'Tạm tính (${vm.selectedItems.length} sản phẩm):',
                      value: _formatMoney(vm.selectedSubTotal),
                    ),
                    const SizedBox(height: 5),
                    _SummaryRow(
                      label: '% Chiết khấu:',
                      value: '${vm.orderDiscountPercent.toStringAsFixed(0)}%',
                      valueColor: Colors.blue.shade700,
                    ),
                    const SizedBox(height: 5),
                    _SummaryRow(
                      label: 'Tiền chiết khấu:',
                      value: '-${_formatMoney(vm.orderDiscountAmount)}',
                      valueColor: Colors.orange.shade800,
                    ),
                    const SizedBox(height: 5),
                    _SummaryRow(
                      label:
                      'Thuế VAT (${kFixedVatPercent.toStringAsFixed(0)}%):',
                      value: '+${_formatMoney(vm.orderVatAmount)}',
                    ),
                    const Divider(height: 14),
                    _SummaryRow(
                      label: 'Thành tiền:',
                      value: _formatMoney(vm.finalTotalAmount),
                      isBold: true,
                      valueColor: Colors.redAccent,
                    ),
                  ],
                ),
              ),

              // 3. Hình thức thanh toán + Ghi chú + Nút Thanh toán
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Chọn phương thức thanh toán
                        Row(
                          children: [
                            const Text(
                              'Hình thức:',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _paymentMethods.map((method) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(
                                          method,
                                          style: const TextStyle(fontSize: 12.5),
                                        ),
                                        selected: vm.paymentMethod == method,
                                        visualDensity: VisualDensity.compact,
                                        onSelected: (_) =>
                                            vm.setPaymentMethod(method),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _noteController,
                          onChanged: vm.setOrderNote,
                          decoration: const InputDecoration(
                            labelText: 'Ghi chú:',
                            hintText: 'Nhập ghi chú cho đơn hàng...',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: vm.isCheckingOut
                              ? null
                              : () => _handleCheckout(vm),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                          ),
                          child: vm.isCheckingOut
                              ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                              : const Text(
                            'Thanh toán',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Widget 1 dòng sản phẩm trong giỏ (không ảnh, có ô vuông tích chọn bên phải)
class _CartItemTile extends StatelessWidget {
  final CartItemModel item;
  final String formattedPrice;
  final ValueChanged<bool?> onCheckChanged;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onDelete;

  const _CartItemTile({
    required this.item,
    required this.formattedPrice,
    required this.onCheckChanged,
    required this.onDecrease,
    required this.onIncrease,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = item.product;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mã: ${p.code}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tên SP: ${p.name}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Số lượng: ',
                      style:
                      TextStyle(fontSize: 14, color: Colors.grey.shade800),
                    ),
                    _QtyMiniButton(icon: Icons.remove, onTap: onDecrease),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${item.quantity} ${p.unit}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _QtyMiniButton(icon: Icons.add, onTap: onIncrease),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Giá: $formattedPrice',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 1.15,
                child: Checkbox(
                  value: item.isSelected,
                  onChanged: onCheckChanged,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.grey.shade600,
                ),
                visualDensity: VisualDensity.compact,
                tooltip: 'Xóa sản phẩm',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyMiniButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyMiniButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 15),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 15 : 13.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}