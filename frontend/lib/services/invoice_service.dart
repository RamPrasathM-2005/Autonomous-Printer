import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/document.dart';
import '../models/order.dart';
import '../services/customer_auth_service.dart';
import '../utils/download_helper.dart';

class InvoiceService {
  static String formatInvoiceDateTime(String? raw) {
    final now = DateTime.now();
    if (raw == null || raw.trim().isEmpty) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(now);
    }
    final s = raw.trim();
    DateTime? dt;
    try {
      final iso = s.replaceAll(' ', 'T');
      if (iso.endsWith('Z') ||
          iso.contains('+') ||
          (iso.contains('-') && iso.lastIndexOf('-') > 10)) {
        dt = DateTime.tryParse(iso)?.toLocal();
      } else {
        dt = DateTime.tryParse('${iso}Z')?.toLocal() ??
            DateTime.tryParse(iso)?.toLocal();
      }
    } catch (_) {}
    dt ??= now;
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  static Future<Uint8List> generateInvoicePdfBytes({
    required PrintOrder order,
    List<DocumentPrintConfig>? configs,
    List<UploadedDocument>? documents,
    String? paymentId,
    String? otp,
    String? userName,
    String? userRoll,
    String? userPhone,
    String? userDept,
    String? location,
  }) async {
    final pdf = pw.Document();

    final formattedDate = formatInvoiceDateTime(order.createdAt);

    final primaryColor = PdfColor.fromHex('#0B3C95');
    final secondaryColor = PdfColor.fromHex('#64748B');
    final lightBg = PdfColor.fromHex('#F8FAFC');
    final borderColor = PdfColor.fromHex('#E2E8F0');
    final coralColor = PdfColor.fromHex('#E05A47');
    final darkText = PdfColor.fromHex('#0F172A');
    final tableBorderColor = PdfColor.fromHex('#0F172A');

    // Load logo assets if available
    pw.MemoryImage? logoImage;
    pw.MemoryImage? wordmarkImage;
    try {
      final logoBytes =
          await rootBundle.load('assets/images/achuppori-logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    try {
      final wordmarkBytes =
          await rootBundle.load('assets/images/achuppori-wordmark.png');
      wordmarkImage = pw.MemoryImage(wordmarkBytes.buffer.asUint8List());
    } catch (_) {}

    // Resolve user details
    final authUser = CustomerAuthService().currentUser;
    final finalName = (userName != null && userName.isNotEmpty)
        ? userName
        : (authUser?.fullName ?? '');
    final finalRoll = (userRoll != null && userRoll.isNotEmpty)
        ? userRoll
        : (order.rollNumber ?? authUser?.rollNumber ?? '');
    final finalPhone = (userPhone != null && userPhone.isNotEmpty)
        ? userPhone
        : (authUser?.phone ?? '');
    final finalDept = (userDept != null && userDept.isNotEmpty)
        ? userDept
        : (order.department ?? authUser?.department ?? 'CSE');
    final finalLocation = (location != null && location.isNotEmpty)
        ? location
        : (order.department ?? 'CSE');
    final finalOtp = otp ?? '';

    // Build line items
    final List<List<String>> tableData = [];
    if (configs != null && configs.isNotEmpty) {
      for (int i = 0; i < configs.length; i++) {
        final c = configs[i];
        final rate = c.isColor ? 10.0 : 2.0;
        final subtotal = c.estimatedCost;
        tableData.add([
          '${i + 1}',
          c.document.filename,
          c.pageRangeDescription.toLowerCase() == 'all' ? 'all' : c.pageRangeDescription,
          c.colorDescription,
          c.sidesDescription,
          '${c.copies}',
          '${c.calculatedPages * c.copies}',
          'Rs ${rate.toStringAsFixed(2)}',
          'Rs ${subtotal.toStringAsFixed(2)}',
        ]);
      }
    } else if (order.printSettings.items.isNotEmpty) {
      for (int i = 0; i < order.printSettings.items.length; i++) {
        final item = order.printSettings.items[i];
        tableData.add([
          '${i + 1}',
          item.filename,
          order.printSettings.pageRange.toLowerCase() == 'all' ? 'all' : order.printSettings.pageRange,
          item.colour ? 'Full Color' : 'Black & White',
          order.printSettings.sides == 'one-sided'
              ? 'Single-Sided'
              : 'Double-Sided',
          '${item.copies}',
          '${item.pages * item.copies}',
          item.colour ? 'Rs 10.00' : 'Rs 2.00',
          item.amount.isNotEmpty
              ? 'Rs ${item.amount}'
              : 'Rs ${(item.pages * item.copies * (item.colour ? 10.0 : 2.0)).toStringAsFixed(2)}',
        ]);
      }
    } else if (documents != null && documents.isNotEmpty) {
      for (int i = 0; i < documents.length; i++) {
        final d = documents[i];
        final rate = order.isColor ? 10.0 : 2.0;
        final subtotal = d.pages * order.copies * rate;
        tableData.add([
          '${i + 1}',
          d.filename,
          order.pageRange.toLowerCase() == 'all' ? 'all' : order.pageRange,
          order.isColor ? 'Full Color' : 'Black & White',
          order.duplex ? 'Double-Sided' : 'Single-Sided',
          '${order.copies}',
          '${d.pages * order.copies}',
          'Rs ${rate.toStringAsFixed(2)}',
          'Rs ${subtotal.toStringAsFixed(2)}',
        ]);
      }
    } else {
      final rate = order.isColor ? 10.0 : 2.0;
      tableData.add([
        '1',
        'Print Document Order',
        order.pageRange.toLowerCase() == 'all' ? 'all' : order.pageRange,
        order.isColor ? 'Full Color' : 'Black & White',
        order.duplex ? 'Double-Sided' : 'Single-Sided',
        '${order.copies}',
        '${order.totalPages}',
        'Rs ${rate.toStringAsFixed(2)}',
        'Rs ${order.amount.toStringAsFixed(2)}',
      ]);
    }

    final List<pw.TableRow> tableRows = [];
    // Header row
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: primaryColor),
        children: [
          _buildHeaderCell('#', pw.Alignment.center),
          _buildHeaderCell('Document', pw.Alignment.center),
          _buildHeaderCell('Pages', pw.Alignment.center),
          _buildHeaderCell('Color Mode', pw.Alignment.center),
          _buildHeaderCell('Sides', pw.Alignment.center),
          _buildHeaderCell('Copies', pw.Alignment.center),
          _buildHeaderCell('Qty', pw.Alignment.center),
          _buildHeaderCell('Rate', pw.Alignment.center),
          _buildHeaderCell('Subtotal', pw.Alignment.center),
        ],
      ),
    );

    // Data rows
    for (final row in tableData) {
      tableRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.white),
          children: [
            _buildDataCell(row[0], pw.Alignment.center),
            _buildDataCell(row[1], pw.Alignment.centerLeft),
            _buildDataCell(row[2], pw.Alignment.center),
            _buildDataCell(row[3], pw.Alignment.center),
            _buildDataCell(row[4], pw.Alignment.center),
            _buildDataCell(row[5], pw.Alignment.center),
            _buildDataCell(row[6], pw.Alignment.center),
            _buildDataCell(row[7], pw.Alignment.center),
            _buildDataCell(row[8], pw.Alignment.centerRight),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Top Header Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: Logo & College branding
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          if (logoImage != null)
                            pw.Container(
                              width: 38,
                              height: 38,
                              margin: const pw.EdgeInsets.only(right: 8),
                              child: pw.Image(logoImage),
                            ),
                          if (wordmarkImage != null)
                            pw.Container(
                              height: 26,
                              child: pw.Image(wordmarkImage),
                            )
                          else
                            pw.Text(
                              'Achuppori',
                              style: pw.TextStyle(
                                color: primaryColor,
                                fontSize: 22,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.RichText(
                        text: pw.TextSpan(
                          style: pw.TextStyle(
                            font: pw.Font.timesBold(),
                            fontSize: 16,
                            lineSpacing: 2,
                          ),
                          children: [
                            pw.TextSpan(
                              text: 'N',
                              style: pw.TextStyle(color: coralColor),
                            ),
                            pw.TextSpan(
                              text: 'ational ',
                              style: pw.TextStyle(color: PdfColor.fromHex('#1E293B')),
                            ),
                            pw.TextSpan(
                              text: 'E',
                              style: pw.TextStyle(color: coralColor),
                            ),
                            pw.TextSpan(
                              text: 'ngineering\n',
                              style: pw.TextStyle(color: PdfColor.fromHex('#1E293B')),
                            ),
                            pw.TextSpan(
                              text: 'C',
                              style: pw.TextStyle(color: coralColor),
                            ),
                            pw.TextSpan(
                              text: 'ollege,',
                              style: pw.TextStyle(color: PdfColor.fromHex('#1E293B')),
                            ),
                            pw.TextSpan(
                              text: 'K',
                              style: pw.TextStyle(color: coralColor),
                            ),
                            pw.TextSpan(
                              text: 'ovilpatti',
                              style: pw.TextStyle(color: PdfColor.fromHex('#1E293B')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Right: Tax Invoice badge, Order ID, Date
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(6),
                          ),
                        ),
                        child: pw.Text(
                          'TAX INVOICE / RECEIPT',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: 'Order ID: ',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9.5,
                                color: darkText,
                              ),
                            ),
                            pw.TextSpan(
                              text: order.id,
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9.5,
                                color: darkText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Date: $formattedDate',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 16),
              pw.Divider(color: borderColor, thickness: 0.8),
              pw.SizedBox(height: 14),

              // Payment Status / Method / Location Bar
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderColor, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Payment Status
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Payment Status',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            color: secondaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'PAID (Verified)',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#16A34A'),
                          ),
                        ),
                      ],
                    ),

                    // Payment Method
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Payment Method',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            color: secondaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Razorpay Online',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: darkText,
                          ),
                        ),
                      ],
                    ),

                    // Location
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Location',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            color: secondaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          finalLocation,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: darkText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              // Specifications Header and Summary Box
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text(
                      'Document Print Specifications:',
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Container(
                    width: 190,
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F0F7FF'),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Total Printed Pages:',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                color: PdfColor.fromHex('#334155'),
                              ),
                            ),
                            pw.Text(
                              '${order.totalPages}',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                                color: darkText,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 3),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Copies Multiplier:',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                color: PdfColor.fromHex('#334155'),
                              ),
                            ),
                            pw.Text(
                              '${order.copies}',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                                color: darkText,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Total Paid:',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            pw.Text(
                              'Rs ${order.amount.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),

              // Itemized Table
              pw.Table(
                border: pw.TableBorder.all(
                  color: tableBorderColor,
                  width: 0.8,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(22),
                  1: const pw.FlexColumnWidth(3.0),
                  2: const pw.FlexColumnWidth(1.1),
                  3: const pw.FlexColumnWidth(1.8),
                  4: const pw.FlexColumnWidth(1.8),
                  5: const pw.FlexColumnWidth(1.0),
                  6: const pw.FlexColumnWidth(1.0),
                  7: const pw.FlexColumnWidth(1.3),
                  8: const pw.FlexColumnWidth(1.4),
                },
                children: tableRows,
              ),

              pw.SizedBox(height: 24),

              // Your Details Section
              pw.Text(
                'Your Details:',
                style: pw.TextStyle(
                  color: primaryColor,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 32),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildDetailLine('Your Name:', finalName),
                    pw.SizedBox(height: 7),
                    _buildDetailLine('Your ID:', finalRoll),
                    pw.SizedBox(height: 7),
                    _buildDetailLine('Your Phone:', finalPhone),
                    pw.SizedBox(height: 7),
                    _buildDetailLine('Your Dept:', finalDept),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              // Your OTP box
              if (finalOtp.isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(
                      color: PdfColor.fromHex('#0284C7'),
                      width: 1,
                    ),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                  child: pw.Text(
                    'Your OTP: $finalOtp',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                ),

              pw.Spacer(),

              // Thank you footer box
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 6,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: coralColor,
                      width: 1.2,
                    ),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(2),
                    ),
                  ),
                  child: pw.Text(
                    'THANK YOU',
                    style: pw.TextStyle(
                      color: primaryColor,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeaderCell(String text, pw.Alignment alignment) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildDataCell(String text, pw.Alignment alignment) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 8.5),
      ),
    );
  }

  static pw.Widget _buildDetailLine(String label, String value) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 80,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#0F172A'),
            ),
          ),
        ),
        pw.Text(
          value.isNotEmpty ? ' $value' : '',
          style: pw.TextStyle(
            fontSize: 9.5,
            color: PdfColor.fromHex('#0F172A'),
          ),
        ),
      ],
    );
  }

  static Future<void> generateAndDownloadInvoice({
    required PrintOrder order,
    List<DocumentPrintConfig>? configs,
    List<UploadedDocument>? documents,
    String? paymentId,
    String? otp,
    String? userName,
    String? userRoll,
    String? userPhone,
    String? userDept,
    String? location,
  }) async {
    final bytes = await generateInvoicePdfBytes(
      order: order,
      configs: configs,
      documents: documents,
      paymentId: paymentId,
      otp: otp,
      userName: userName,
      userRoll: userRoll,
      userPhone: userPhone,
      userDept: userDept,
      location: location,
    );

    final filename =
        'Invoice_${order.id.substring(0, order.id.length.clamp(0, 8))}.pdf';
    await downloadFile(bytes, filename);
  }
}
