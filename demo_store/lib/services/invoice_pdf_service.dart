import 'dart:typed_data';
import 'package:demo_store/data/model/order_model.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoicePdfService {
  // Thông tin cửa hàng
  static const String storeName = 'Cửa hàng LIFT';
  static const String storeAddress = '114 Chiến Thắng, Hà Nội';
  static const String storeHotline = '19003681';

  static final _moneyFormat = NumberFormat('#,###', 'vi_VN');
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _timeFormat = DateFormat('HH:mm:ss');

  static String _formatMoney(double value) =>
      '${_moneyFormat.format(value.round())} đ';

  /// Tạo dữ liệu nhị phân PDF cho hóa đơn theo đúng khổ giấy người dùng chọn
  static Future<Uint8List> generateInvoicePdf(
      OrderModel order,
      PdfPageFormat format,
      ) async {
    // 1. Nạp font tiếng Việt (tự tải & lưu cache bởi package printing)
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();

    // 2. Nạp logo cửa hàng từ assets
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/app_logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }

    final isCompact = format.width < 300; // Khổ bill nhiệt 80mm
    final titleSize = isCompact ? 13.0 : 17.0;
    final bodySize = isCompact ? 8.5 : 10.5;
    final smallSize = isCompact ? 7.5 : 9.5;

    final pdf = pw.Document(
      title: 'Hóa đơn ${order.orderCode}',
      author: storeName,
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
        italic: fontItalic,
      ),
    );

    final contentWidgets = <pw.Widget>[
      // ===== KHỐI 1: LOGO & THÔNG TIN CỬA HÀNG =====
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logoImage != null) ...[
            pw.Container(
              width: isCompact ? 38 : 54,
              height: isCompact ? 38 : 54,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 8),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  storeName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: isCompact ? 11 : 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Đ/c: $storeAddress',
                  style: pw.TextStyle(fontSize: smallSize),
                ),
                pw.Text(
                  'Hotline: $storeHotline',
                  style: pw.TextStyle(fontSize: smallSize),
                ),
              ],
            ),
          ),
        ],
      ),

      pw.SizedBox(height: 6),
      pw.Divider(
        thickness: 0.8,
        borderStyle: pw.BorderStyle.dashed,
        color: PdfColors.grey700,
      ),

      // Tiêu đề hóa đơn
      pw.Center(
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(
            'HÓA ĐƠN BÁN HÀNG',
            style: pw.TextStyle(
              fontSize: titleSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ),

      // ===== KHỐI 2: THÔNG TIN ĐƠN HÀNG =====
      pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey500, width: 0.6),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _metaRow('Mã đơn:', order.orderCode, bodySize, isBoldValue: true),
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Ngày: ${_dateFormat.format(order.createdAt)}',
                  style: pw.TextStyle(fontSize: bodySize),
                ),
                pw.Text(
                  'Giờ: ${_timeFormat.format(order.createdAt)}',
                  style: pw.TextStyle(fontSize: bodySize),
                ),
              ],
            ),
            pw.SizedBox(height: 2),
            _metaRow('Nhân viên:', order.staffName, bodySize),
          ],
        ),
      ),

      pw.SizedBox(height: 8),

      // ===== KHỐI 3: DANH SÁCH SẢN PHẨM MUA =====
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Sản phẩm (SL x Đơn giá)',
            style: pw.TextStyle(
              fontSize: smallSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'Thành tiền',
            style: pw.TextStyle(
              fontSize: smallSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
      pw.Divider(thickness: 0.8, color: PdfColors.black),

      ...order.items.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final item = entry.value;
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Dòng 1: STT + Mã SP + Tên SP
              pw.Text(
                '$index. [${item.productCode}] ${item.productName}',
                style: pw.TextStyle(
                  fontSize: bodySize,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 1.5),
              // Dòng 2: SL (ĐVT) x Đơn giá  <--->  Thành tiền
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '   ${item.quantity} ${item.unit} x ${_formatMoney(item.unitPrice)}',
                    style: pw.TextStyle(
                      fontSize: smallSize,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.Text(
                    _formatMoney(item.lineTotal),
                    style: pw.TextStyle(fontSize: bodySize),
                  ),
                ],
              ),
            ],
          ),
        );
      }),

      pw.Divider(
        thickness: 0.8,
        borderStyle: pw.BorderStyle.dashed,
        color: PdfColors.grey700,
      ),

      // ===== KHỐI 4: TỔNG GIÁ TRỊ, GIẢM GIÁ, VAT & THANH TOÁN =====
      _summaryRow('Tổng giá trị đơn:', _formatMoney(order.subTotal), bodySize),
      pw.SizedBox(height: 2.5),
      _summaryRow(
        'Giảm giá (${order.discountPercent.toStringAsFixed(0)}%):',
        '-${_formatMoney(order.discountAmount)}',
        bodySize,
      ),
      pw.SizedBox(height: 2.5),
      _summaryRow(
        'Thuế VAT (${order.vatPercent.toStringAsFixed(0)}%):',
        '+${_formatMoney(order.vatAmount)}',
        bodySize,
      ),
      pw.Divider(thickness: 0.8, color: PdfColors.black),
      _summaryRow(
        'TỔNG CẦN THANH TOÁN:',
        _formatMoney(order.finalTotal),
        isCompact ? 10.0 : 12.5,
        isBold: true,
      ),
      pw.SizedBox(height: 4),
      _summaryRow('Hình thức thanh toán:', order.paymentMethod, bodySize),

      // Ghi chú đơn hàng (chỉ hiển thị nếu có)
      if (order.note.trim().isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(5),
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Text(
            'Ghi chú: ${order.note.trim()}',
            style: pw.TextStyle(
              fontSize: smallSize,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ),
      ],

      pw.SizedBox(height: 12),
      pw.Center(
        child: pw.Text(
          'Cảm ơn quý khách & Hẹn gặp lại!',
          style: pw.TextStyle(
            fontSize: smallSize,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey700,
          ),
        ),
      ),
    ];

    // Khổ cuộn nhiệt 80mm có chiều cao vô hạn -> dùng pw.Page; khổ A5/A4 -> dùng pw.MultiPage
    if (format.height.isInfinite) {
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(10),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: contentWidgets,
          ),
        ),
      );
    } else {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => contentWidgets,
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _metaRow(
      String label,
      String value,
      double fontSize, {
        bool isBoldValue = false,
      }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: fontSize)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBoldValue ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  static pw.Widget _summaryRow(
      String label,
      String value,
      double fontSize, {
        bool isBold = false,
      }) {
    final style = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(value, style: style),
      ],
    );
  }
}