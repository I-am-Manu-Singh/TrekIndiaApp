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
    String? phoneNumber,
    String? address,
    String? aadharNumber,
    int pax = 1,
    List<dynamic> travelers = const [],
    String? email,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/app_logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null) ...[
                        pw.Image(logoImage, width: 44, height: 44),
                        pw.SizedBox(width: 12),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('trekwithmussafirr', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                          pw.Text('Trek With Mussafirr Adventure LLP', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                          pw.Text('383 St. No. 11, Rajendra Nagar, Shiv Complex, Dehradun - 248001', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                          pw.Text('Email: mussafirr1@gmail.com • Web: trekwithmussafirr.com', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(color: PdfColors.red900, borderRadius: pw.BorderRadius.circular(4)),
                        child: pw.Text('TAX INVOICE', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('INVOICE #${bookingId.length > 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 10),
              
              // ── CLIENT & BOOKING IDENTITY ───────────────────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILLED TO (LEAD EXPLORER):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.grey700)),
                        pw.SizedBox(height: 3),
                        pw.Text(hikerName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        if (phoneNumber != null && phoneNumber.isNotEmpty)
                          pw.Text('Contact: $phoneNumber', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                        if (email != null && email.isNotEmpty)
                          pw.Text('Email: $email', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                        if (aadharNumber != null && aadharNumber.isNotEmpty)
                          pw.Text('Aadhar Number: $aadharNumber', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                        if (address != null && address.isNotEmpty)
                          pw.Text('Address: $address', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PAYMENT & STATUS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.grey700)),
                        pw.SizedBox(height: 3),
                        pw.Text('Status: Confirmed / Paid', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                        pw.Text('Mode: Online / Verified UPI', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        pw.Text('Total Travelers: $pax Person(s)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // ── GROUP MEMBERS TABLE (IF ANY) ─────────────────────────────────
              if (travelers.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('GROUP MEMBERS / CO-TRAVELERS DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.red900)),
                      pw.SizedBox(height: 4),
                      ...travelers.asMap().entries.map((e) {
                        final m = e.value is Map ? e.value : {'name': e.value.toString()};
                        final mName = m['name'] ?? 'Member #${e.key + 2}';
                        final mAge = m['age'] != null && m['age'].toString() != '0' ? 'Age: ${m['age']}' : '';
                        final mAadhar = m['aadhar'] != null && m['aadhar'].toString().isNotEmpty ? 'Aadhar: ${m['aadhar']}' : '';
                        final mPhone = m['phone'] != null && m['phone'].toString().isNotEmpty ? 'Phone: ${m['phone']}' : '';
                        final detailsStr = [mAge, mAadhar, mPhone].where((s) => s.isNotEmpty).join(' | ');

                        return pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('${e.key + 2}. $mName', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                              pw.Text(detailsStr, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
              ],

              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('BOOKING & LOGISTICS SPECIFICATIONS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.red900)),
                    pw.SizedBox(height: 6),
                    _pdfRow('Trek / Package:', tripName),
                    _pdfRow('Expedition Start Date:', DateFormat('dd MMM yyyy').format(date)),
                    _pdfRow('Boarding / Pickup Hub:', pickupLocation.isNotEmpty ? pickupLocation : 'Base Camp Dehradun'),
                    _pdfRow('Drop / Return Point:', pickupLocation.isNotEmpty ? pickupLocation : 'Dehradun ISBT / Airport'),
                    _pdfRow('Reporting Time:', '06:00 AM (Day 1)'),
                    _pdfRow('Transit & Permit Clearance:', 'Authorized by trekwithmussafirr'),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text('COMPREHENSIVE FEE BREAKDOWN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.grey700)),
              pw.Divider(thickness: 0.5),
              _pdfPriceRow('Base Expedition Package (Stay, Meals, Guide)', 'INR ${basePrice.toInt()}'),
              _pdfPriceRow('Pickup & Drop Logistics', 'INR ${pickupPrice.toInt()}'),
              _pdfPriceRow('Addons, Gear Rental & Forest Permits', 'INR ${(totalPrice - basePrice - pickupPrice).toInt()}'),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1.5, color: PdfColors.red900),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('NET PAYABLE AMOUNT (INCL. TAXES)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text('INR ${totalPrice.toInt()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.red900)),
                ],
              ),
              pw.Spacer(),
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('trekwithmussafirr • Explore the Unexplored', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                  pw.Text('Authorized Computer-Generated Invoice • No Signature Required', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                ],
              ),
            ],
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
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/app_logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null) ...[
                        pw.Image(logoImage, width: 44, height: 44),
                        pw.SizedBox(width: 12),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('trekwithmussafirr', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                          pw.Text('Trek With Mussafirr Adventure LLP', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                          pw.Text('383 St. No. 11, Rajendra Nagar, Shiv Complex, Dehradun - 248001', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                          pw.Text('Email: mussafirr1@gmail.com • Web: trekwithmussafirr.com', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(color: PdfColors.red900, borderRadius: pw.BorderRadius.circular(4)),
                        child: pw.Text('TRANSPORT INVOICE', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('INVOICE #${bookingId.length > 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 16),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILLED TO (PASSENGER):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text(hikerName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        if (email != null && email.isNotEmpty) pw.Text(email, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TRANSIT STATUS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text('Booking: Confirmed', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                        pw.Text('Service: Verified Fleet Partner', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('TRANSPORT & ROUTE DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.red900)),
                    pw.SizedBox(height: 6),
                    _pdfRow('Fleet / Service:', '$transportName (${type.toUpperCase()})'),
                    _pdfRow('Route / Pathway:', '$from TO $to'),
                    _pdfRow('Departure Date:', DateFormat('dd MMM yyyy').format(date)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('FARE BREAKDOWN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
              pw.Divider(thickness: 0.5),
              _pdfPriceRow('Transport Base Fare', 'INR ${price.toInt()}'),
              _pdfPriceRow('Convenience / Driver Allowance', 'INR 0'),
              pw.SizedBox(height: 14),
              pw.Divider(thickness: 1.5, color: PdfColors.red900),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL PAID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.Text('INR ${price.toInt()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.red900)),
                ],
              ),
              pw.Spacer(),
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('trekwithmussafirr • Reliable Himalayan Transit', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                  pw.Text('Authorized Computer-Generated Invoice • No Signature Required', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                ],
              ),
            ],
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
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/app_logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null) ...[
                        pw.Image(logoImage, width: 44, height: 44),
                        pw.SizedBox(width: 12),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('trekwithmussafirr', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                          pw.Text('Trek With Mussafirr Adventure LLP', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                          pw.Text('383 St. No. 11, Rajendra Nagar, Shiv Complex, Dehradun - 248001', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                          pw.Text('Email: mussafirr1@gmail.com • Web: trekwithmussafirr.com', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(color: PdfColors.red900, borderRadius: pw.BorderRadius.circular(4)),
                        child: pw.Text('REFUND ADVICE', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('REFUND #${bookingId.length > 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 16),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('REFUNDED TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text(hikerName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        if (email != null && email.isNotEmpty) pw.Text(email, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('REFUND STATUS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text('Status: Approved & Initiated', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                        pw.Text('Timeline: 15-30 Working Days', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ORIGINAL TRIP & CANCELLATION DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.red900)),
                    pw.SizedBox(height: 6),
                    _pdfRow('Trek Name:', tripName),
                    _pdfRow('Trip Scheduled Date:', DateFormat('dd MMM yyyy').format(date)),
                    _pdfRow('Approved Reason:', reason),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('CREDIT / REIMBURSEMENT SUMMARY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
              pw.Divider(thickness: 0.5),
              _pdfPriceRow('Approved Refundable Amount', 'INR ${refundAmount.toInt()}'),
              pw.SizedBox(height: 14),
              pw.Divider(thickness: 1.5, color: PdfColors.red900),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('NET REIMBURSED', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.Text('INR ${refundAmount.toInt()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.red900)),
                ],
              ),
              pw.Spacer(),
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('trekwithmussafirr • Explore the Unexplored', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                  pw.Text('Authorized Computer-Generated Advice • No Signature Required', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Refund_Advice_${bookingId.substring(0, 8)}.pdf',
      );
    } catch (e) {
      debugPrint('PDF Layout Error: $e');
    }
  }

  static Future<Uint8List> generateDeclarationPdfBytes({
    required String hikerName,
    required String tripTitle,
    required String emergencyContact,
    required String medicalInfo,
    required DateTime date,
    Uint8List? signatureImageBytes,
  }) async {
    final pdf = pw.Document();

    // Load App Logo if available
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/app_logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    // Multi-page Document matching Trek_With_Mussafirr_Declaration_Form.pdf
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            margin: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 1, color: PdfColors.red900),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  children: [
                    if (logoImage != null) ...[
                      pw.Image(logoImage, width: 36, height: 36),
                      pw.SizedBox(width: 10),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TREK WITH MUSSAFIRR',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red900,
                          ),
                        ),
                        pw.Text(
                          'Terms & Conditions, Participant Agreement & Medical Declaration',
                          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Text(
                  'Date: ${DateFormat('dd MMM yyyy').format(date)}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            margin: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(width: 0.5, color: PdfColors.grey400),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'trekwithmussafirr • Registered Office: 383 street no. 11 Rajendra Nagar, Shiv Complex, Dehradun-248001',
                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => [
          // ── Participant Details Box ───────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PARTICIPANT REGISTRATION & TRIP DETAILS',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.Expanded(child: _pdfRow('Participant Name:', hikerName)),
                    pw.Expanded(child: _pdfRow('Trek / Package:', tripTitle)),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Expanded(child: _pdfRow('Emergency Contact:', emergencyContact)),
                    pw.Expanded(child: _pdfRow('Medical Info / History:', medicalInfo.isEmpty ? 'None Stated / Fit' : medicalInfo)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          // ── Medical Risk Warning ──────────────────────────────────────────
          pw.Text(
            'MEDICAL & HIGH ALTITUDE RISK DECLARATION',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Trek With Mussafirr treks take place in some remote and less-developed regions, without means of rapid evacuation, or medical supplies and facilities. In the event of an accident, illness, or other hazardous terrain, common and uncommon signs and symptoms of altitude sickness should be expected. These include, but are not limited to: sleeplessness, coughing, loss of appetite, nausea, vomiting, and muscle cramps. Severe cases of altitude sickness can include pulmonary and/or cerebral oedema. In addition, exposure to microorganisms unknown to our digestive system may cause symptoms from a wide array of gastrointestinal disorders despite the best efforts to treat drinking water and prepare food properly. A poor state of health can greatly increase the dangers and risks that can be incurred on these trips. Therefore, Trek With Mussafirr requires that all climbers and/or trekkers are examined by a physician, are properly immunized for the destination(s), and provide information.',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800, lineSpacing: 1.2),
          ),
          pw.SizedBox(height: 10),

          // ── Terms & Conditions (Consolidated from PDF) ─────────────────────
          pw.Text(
            'TERMS AND CONDITIONS OF SERVICE AND TRIP PARTICIPATION AGREEMENT',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'This Agreement ("Agreement") is entered into by and between Trek With Mussafirr ("TWM"), having its registered office at 383 street no. 11 Rajendra Nagar, Shiv Complex cabin no. 4, 2nd floor, Dehradun-248001, Uttarakhand, and the Client (the "Participant"). The booking of any trekking, mountaineering, adventure activity ("Trip") with TWM constitutes acceptance of the terms and conditions set forth herein.',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800, lineSpacing: 1.2),
          ),
          pw.SizedBox(height: 8),

          _termParagraph('1. Acceptance of Risk and Participant Responsibility',
              'The Participant acknowledges that participation in any Trip involves inherent risks, including but not limited to injury, illness, loss, or death, due to unpredictable weather, terrain, or other environmental and non-environmental conditions.\nThe Participant voluntarily assumes all such risks and agrees to be solely responsible for their personal safety, fitness, and decision to participate.\nThe Participant agrees to disclose any relevant medical, psychological, or physical conditions prior to booking and undertakes that they are fit and well-prepared for the selected Trip.\nTWM undertakes reasonable measures to minimize risks but cannot guarantee a risk-free experience.'),
          _termParagraph('2. Booking and Payments',
              'Booking of a Trip constitutes unconditional acceptance of this Agreement by the Participant and all persons represented by the Participant.\nThe Participant is responsible for verifying the accuracy of all details, including Trip dates and personal documentation, at the time of booking.\nPayments must be made in accordance with the timelines and instructions provided by TWM. Late payments may result in cancellation of booking without refund.\nIn the event of a cash refund, only the portion of the payment made in cash shall be eligible for refund in cash. Any booking made using voucher, discounts, promotional codes, or through any non-cash mode of payment shall not be eligible for a cash refund under any circumstances.\nRefunds, if applicable, shall be processed within 15-30 working days of confirmation.\nVoucher Terms: Non-transferable; cannot be merged with other offers; valid for 1 year for trips booked directly in India using registered email/phone.'),
          _termParagraph('3. Minor Participation Policy',
              'Participants under 15 years of age must be accompanied by a parent or legal guardian and must submit a signed consent form. Participants between 15 to 18 years can come solo with the disclaimer form signed by parent/guardian.'),
          _termParagraph('4. Promotional Material',
              'Photographs and videos used on TWM\'s website, social media, or promotional content are illustrative and do not form part of the Trip package or service guarantee.'),
          _termParagraph('5. Documentation and Permits',
              'All required documentation must be submitted by the Participant prior to the Trip. TWM is not liable for failure to provide services due to incomplete, incorrect, or missing documentation.'),
          _termParagraph('6. Communication',
              'All official communication shall be made via the email ID submitted during registration. Participants must notify TWM at mussafirr1@gmail.com of any changes. You consent to receive communications via email, phone calls, and SMS.'),
          _termParagraph('7. Insurance Advisory',
              'TWM strongly encourages all Participants to obtain comprehensive travel insurance covering high-altitude trekking, illness, hospitalisation, evacuation, and trip cancellations. If not obtained, one is provided by default for Indian citizens as third-party insurance with zero liability on TWM.'),
          _termParagraph('8. Amenities and Conditions',
              'Participants acknowledge that these regions offer limited amenities. Environmental and logistical constraints may affect comfort. TWM is not liable for discomfort arising therefrom.'),
          _termParagraph('9. Expenses, Rental Equipments and Exclusions',
              'Excluded from Trip cost: Insurance, airfares, visa costs, evacuation expenses, personal expenses, gear rentals, and porter/mule fees. Shoes, poles, headlights, jackets, microspikes, gaiters, etc. are not included in packages. Any damage or loss to rented equipment must be fully paid and reimbursed by the Participant.'),
          _termParagraph('10. Luggage and Personal Belongings',
              'All baggage and personal belongings are the sole responsibility of the Participant. TWM shall not be liable for loss, damage, or theft.'),
          _termParagraph('11. Optional Activities',
              'Optional activities not included in the Trip package are undertaken at the Participant\'s own risk. TWM shall not be held liable for resulting loss, injury, or damage.'),
          _termParagraph('12. Force Majeure',
              'TWM shall not be held liable for cancellation, delay, or service modification caused by events beyond its control including earthquakes, landslides, strikes, curfews, war, pandemic, government restrictions, heavy rainfall or snowfall, windstorms, road blockages, trail disruption, or permit withdrawals. No refunds, liability, or compensation arise from Force Majeure.'),
          _termParagraph('13. Itinerary and Modifications',
              'TWM reserves the right to modify, shorten, or cancel any part of the Trip due to transport delays, weather, health emergencies, or Force Majeure. Additional expenses are borne by the Participant.'),
          _termParagraph('14. Cancellations and Refunds',
              'No refunds or vouchers provided for voluntary withdrawal or removal. If TWM cancels before pick-up point arrival due to Force Majeure: alternate date, 1-year credit voucher, or trip transfer. Discontinuation due to health, AMS, or weather is strictly 100% non-refundable. En-route exits between Point A to Point B require participant to bear all transport, accommodation, meals, porter, and evacuation expenses entirely.'),
          _termParagraph('15. Conditions to Discontinue a Trip for a Participant',
              'Condition 1: AMS Unconscious / Conscious / Ill critical / Injured - unable to walk.\nCondition 2: High Blood pressure, SpO2 below 80%, irregular heart rate.\nCondition 3: Symptoms like headache, nausea, dizziness, fatigue, fast breathing, confusion.\nCondition 4: Unable to meet group average speed.\nCondition 5: Use of alcohol, drugs, smoking on trails/camps, offensive language or disturbance.'),
          _termParagraph('16. Medical Emergencies and Evacuation',
              'All medical, hospitalisation, doctor fees, evacuation, or repatriation expenses are borne solely by the Participant.'),
          _termParagraph('17. Third Party Services and Manpower',
              'Porters, guides, and mule operators are engaged via third-party vendors. TWM is not liable for non-performance, illness, or departure of support staff.'),
          _termParagraph('18. Photography, Media, Data Privacy & Usage',
              'Participant grants TWM a royalty-free license to use trip media for promotional purposes unless opted out in writing. Data is stored for operational and legal purposes only.'),
          _termParagraph('19. Blacklist Policy',
              'TWM reserves the right to permanently blacklist any individual for misconduct, safety violations, defamation, or harassment without refund.'),
          _termParagraph('20. Implied Acceptance and Waiver of Objection',
              'Concerns must be communicated immediately to trip leader. Continued utilization of services constitutes implied acceptance, waiving retrospective claims.'),
          _termParagraph('21. Complaints & Dispute Resolution',
              'Complaints must be submitted via email within 7 days. Arbitration conducted in Dehradun under Indian law.'),
          _termParagraph('22. Governing Law & Jurisdiction',
              'Governed by Indian law. All legal disputes fall under the exclusive jurisdiction of courts in Dehradun, Uttarakhand.'),
          _termParagraph('23. Miscellaneous',
              'Trek With Mussafirr holds rights to add/remove any Terms without prior notice.'),

          pw.SizedBox(height: 12),

          // ── Disclaimer & Final Signature Block ────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.red900, width: 1),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('DISCLAIMER AND VOLUNTARY DECLARATION',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                pw.SizedBox(height: 4),
                pw.Text(
                  'The Trek/Expedition route in The Himalayas has its share of risks and dangers, especially in respect to terrain, weather, high altitude, and desolate nature. Accidents on this trek can cause injury, illness, and death cannot be ruled out. I hereby declare that my participation is completely voluntary and I will not hold Trekwithmussafirr wholly or partly responsible.',
                  style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Participant: $hikerName', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Status: Digitally Signed & Verified', style: pw.TextStyle(fontSize: 7.5, color: PdfColors.green800, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(date)}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 140,
                          height: 50,
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide(width: 1, color: PdfColors.black)),
                          ),
                          child: signatureImageBytes != null
                              ? pw.Image(pw.MemoryImage(signatureImageBytes), fit: pw.BoxFit.contain)
                              : pw.Center(
                                  child: pw.Text(hikerName,
                                      style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold)),
                                ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text('Touchscreen Certified Signature', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _termParagraph(String title, String content) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
          pw.SizedBox(height: 1),
          pw.Text(content, style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey800, lineSpacing: 1.1)),
        ],
      ),
    );
  }

  static Future<void> downloadDeclarationPdf({
    required String hikerName,
    required String tripTitle,
    required String emergencyContact,
    required String medicalInfo,
    required DateTime date,
    Uint8List? signatureImageBytes,
  }) async {
    try {
      final bytes = await generateDeclarationPdfBytes(
        hikerName: hikerName,
        tripTitle: tripTitle,
        emergencyContact: emergencyContact,
        medicalInfo: medicalInfo,
        date: date,
        signatureImageBytes: signatureImageBytes,
      );
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'Declaration_${hikerName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      debugPrint('Declaration PDF Download Error: $e');
    }
  }

  static Future<void> shareDeclarationPdf({
    required String hikerName,
    required String tripTitle,
    required String emergencyContact,
    required String medicalInfo,
    required DateTime date,
    Uint8List? signatureImageBytes,
  }) async {
    try {
      final bytes = await generateDeclarationPdfBytes(
        hikerName: hikerName,
        tripTitle: tripTitle,
        emergencyContact: emergencyContact,
        medicalInfo: medicalInfo,
        date: date,
        signatureImageBytes: signatureImageBytes,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Declaration_${hikerName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      debugPrint('Declaration PDF Share Error: $e');
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
