import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class InvoiceService {
  static Future<void> generateAndDownloadInvoice({
    required String bookingId,
    required String tripName,
    required DateTime date,
    required String hikerName,
    required double totalPrice,
    required double basePrice,
    required double pickupPrice,
    required String pickupLocation,
    String? email,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TREKWITHMUSSAFIRR', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                        pw.Text('Official Trip Invoice', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('INVOICE #$bookingId', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 40),
                pw.Text('BILL TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
                pw.Text(hikerName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                if (email != null) pw.Text(email, style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 30),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TRIP DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.red900)),
                      pw.SizedBox(height: 8),
                      _pdfRow('Trip/Package:', tripName),
                      _pdfRow('Trip Date:', DateFormat('dd MMM yyyy').format(date)),
                      _pdfRow('Pickup Point:', pickupLocation),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Text('COST BREAKDOWN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
                pw.Divider(),
                _pdfPriceRow('Base Package Price', 'INR ${basePrice.toInt()}'),
                _pdfPriceRow('Pickup Surcharge', 'INR ${pickupPrice.toInt()}'),
                _pdfPriceRow('Addons & Rentals', 'INR ${(totalPrice - basePrice - pickupPrice).toInt()}'),
                pw.SizedBox(height: 20),
                pw.Divider(thickness: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('GRAND TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.Text('INR ${totalPrice.toInt()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.red900)),
                  ],
                ),
                pw.Spacer(),
                pw.Center(
                  child: pw.Text('This is a computer-generated document. No signature required.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ),
                pw.Center(
                  child: pw.Text('TREKWITHMUSSAFIRR - Explore the Unexplored', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      if (kIsWeb) {
        await Printing.layoutPdf(onLayout: (format) => pdf.save(), name: 'Invoice_${bookingId.substring(0, 8)}.pdf');
      } else {
        await Printing.sharePdf(bytes: await pdf.save(), filename: 'Invoice_${bookingId.substring(0, 8)}.pdf');
      }
    } catch (e) {
      debugPrint('PDF Layout Error: $e');
    }
  }

  static Future<void> generateTransportInvoice({
    required String bookingId,
    required String transportName,
    required String type,
    required String from,
    required String to,
    required DateTime date,
    required String hikerName,
    required double price,
    String? email,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TREKWITHMUSSAFIRR', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                        pw.Text('Transport Booking Invoice', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('INVOICE #$bookingId', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 40),
                pw.Text('BILL TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
                pw.Text(hikerName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                if (email != null) pw.Text(email, style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 30),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TRANSPORT DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.red900)),
                      pw.SizedBox(height: 8),
                      _pdfRow('Service:', '$transportName (${type.toUpperCase()})'),
                      _pdfRow('Route:', '$from TO $to'),
                      _pdfRow('Travel Date:', DateFormat('dd MMM yyyy').format(date)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Text('COST BREAKDOWN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
                pw.Divider(),
                _pdfPriceRow('Booking Fare', 'INR ${price.toInt()}'),
                _pdfPriceRow('Convenience Fee', 'INR 0'),
                pw.SizedBox(height: 20),
                pw.Divider(thickness: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('GRAND TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.Text('INR ${price.toInt()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.red900)),
                  ],
                ),
                pw.Spacer(),
                pw.Center(
                  child: pw.Text('This is a computer-generated document. No signature required.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ),
                pw.Center(
                  child: pw.Text('TREKWITHMUSSAFIRR - Reliable Travel Solutions', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Transport_Invoice_${bookingId.substring(0, 8)}.pdf',
      );
    } catch (e) {
      debugPrint('PDF Layout Error: $e');
    }
  }

  static Future<void> generateRefundInvoice({
    required String bookingId,
    required String tripName,
    required DateTime date,
    required String hikerName,
    required double refundAmount,
    required String reason,
    String? email,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TREKWITHMUSSAFIRR', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                        pw.Text('Refund Confirmation Advice', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('REFUND #$bookingId', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 40),
                pw.Text('REFUND TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
                pw.Text(hikerName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                if (email != null) pw.Text(email, style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 30),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CANCELLATION DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.red900)),
                      pw.SizedBox(height: 8),
                      _pdfRow('Original Trip:', tripName),
                      _pdfRow('Trip Date:', DateFormat('dd MMM yyyy').format(date)),
                      _pdfRow('Reason:', reason),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Text('FINANCIAL SUMMARY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
                pw.Divider(),
                _pdfPriceRow('Refundable Amount', 'INR ${refundAmount.toInt()}'),
                _pdfPriceRow('Cancellation Fee', 'INR 0'),
                pw.SizedBox(height: 20),
                pw.Divider(thickness: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL REFUNDED', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.Text('INR ${refundAmount.toInt()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.green900)),
                  ],
                ),
                pw.Spacer(),
                pw.Center(
                  child: pw.Text('Refunds are usually processed within 5-7 working days to the original payment source.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ),
                pw.Center(
                  child: pw.Text('TREKWITHMUSSAFIRR - We hope to see you again soon!', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Refund_${bookingId.substring(0, 8)}.pdf',
      );
    } catch (e) {
      debugPrint('PDF Layout Error: $e');
    }
  }

  static Future<void> shareInvoice(pw.Document pdf, String filename) async {
    await Printing.sharePdf(bytes: await pdf.save(), filename: filename);
  }

  static pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(width: 8),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _pdfPriceRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
