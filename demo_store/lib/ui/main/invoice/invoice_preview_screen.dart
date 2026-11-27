import 'package:demo_store/data/model/order_model.dart';
import 'package:demo_store/services/invoice_pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class InvoicePreviewScreen extends StatelessWidget {
  final OrderModel order;

  const InvoicePreviewScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Hóa đơn ${order.orderCode}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade300),
        ),
      ),
      body: PdfPreview(
        build: (format) => InvoicePdfService.generateInvoicePdf(order, format),
        pdfFileName: 'HoaDon_${order.orderCode}.pdf',
        initialPageFormat: PdfPageFormat.roll80,
        pageFormats: const {
          'Khổ Bill 80mm': PdfPageFormat.roll80,
          'Khổ A5': PdfPageFormat.a5,
          'Khổ A4': PdfPageFormat.a4,
        },
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canDebug: false,
        loadingWidget: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Đang tạo file PDF hóa đơn...'),
            ],
          ),
        ),
      ),
    );
  }
}