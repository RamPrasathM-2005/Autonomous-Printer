import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/document.dart';
import '../models/order.dart';
import '../utils/download_helper.dart';

class InvoiceService {
  static Future<void> generateAndDownloadInvoice({
    required PrintOrder order,
    List<DocumentPrintConfig>? configs,
    List<UploadedDocument>? documents,
    String? paymentId,
  }) async {
    final pdf = pw.Document();

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final formattedDate = order.createdAt.isNotEmpty
        ? dateFormat.format(
            DateTime.tryParse(order.createdAt)?.toLocal() ?? DateTime.now(),
          )
        : dateFormat.format(DateTime.now());

    final primaryColor = PdfColor.fromHex('#1E40AF'); // Navy blue
    final secondaryColor = PdfColor.fromHex('#475569'); // Slate
    final lightBg = PdfColor.fromHex('#F8FAFC'); // Off-white
    final borderColor = PdfColor.fromHex('#E2E8F0');

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
          c.pageRangeDescription,
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
          'All',
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
          order.pageRange,
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
        order.pageRange,
        order.isColor ? 'Full Color' : 'Black & White',
        order.duplex ? 'Double-Sided' : 'Single-Sided',
        '${order.copies}',
        '${order.totalPages}',
        'Rs ${rate.toStringAsFixed(2)}',
        'Rs ${order.amount.toStringAsFixed(2)}',
      ]);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Banner
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ACHUPPORI',
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Smart Cloud & Kiosk Printing System',
                        style: pw.TextStyle(
                          color: secondaryColor,
                          fontSize: 10,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Station ID: ${order.printServerId}',
                        style: pw.TextStyle(
                          color: secondaryColor,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(4),
                          ),
                        ),
                        child: pw.Text(
                          'TAX INVOICE / RECEIPT',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Order ID: ${order.id}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Date: $formattedDate',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(color: borderColor, thickness: 1),
              pw.SizedBox(height: 12),

              // Payment & Transaction Info
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Payment Status',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: secondaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'PAID (Verified)',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#15803D'),
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Payment Method',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: secondaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Razorpay Online',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (paymentId != null && paymentId.isNotEmpty)
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Transaction ID',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: secondaryColor,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            paymentId,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Paper Size',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: secondaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          order.printSettings.paperSize,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Itemized Table Heading
              pw.Text(
                'Document Print Specifications',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 8),

              // Itemized Table
              pw.TableHelper.fromTextArray(
                context: context,
                headers: [
                  '#',
                  'Document',
                  'Pages',
                  'Color Mode',
                  'Sides',
                  'Copies',
                  'Qty',
                  'Rate',
                  'Subtotal',
                ],
                data: tableData,
                headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(color: primaryColor),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.center,
                  5: pw.Alignment.center,
                  6: pw.Alignment.center,
                  7: pw.Alignment.centerRight,
                  8: pw.Alignment.centerRight,
                },
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 6,
                ),
              ),
              pw.SizedBox(height: 16),

              // Summary Box & QR Verification Code
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // QR Code & Verification info
                  pw.Expanded(
                    flex: 3,
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.BarcodeWidget(
                          data: 'AUTOPRINT:${order.id}:${order.printServerId}',
                          barcode: pw.Barcode.qrCode(),
                          width: 65,
                          height: 65,
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Kiosk Pickup QR',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Scan or enter your 6-digit release OTP at the kiosk printer terminal to release print.',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  color: secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  // Totals Box
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: lightBg,
                        border: pw.Border.all(color: borderColor),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(6),
                        ),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Total Printed Pages:',
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                              pw.Text(
                                '${order.totalPages}',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Copies Multiplier:',
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                              pw.Text(
                                '${order.copies}',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 6),
                          pw.Divider(color: borderColor, thickness: 1),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
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
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryColor,
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

              pw.Spacer(),

              // Footer Note
              pw.Divider(color: borderColor, thickness: 0.8),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Thank you for using Achuppori.',
                    style: pw.TextStyle(fontSize: 8, color: secondaryColor),
                  ),
                  pw.Text(
                    'Computer Generated Receipt | Valid without physical signature',
                    style: pw.TextStyle(fontSize: 8, color: secondaryColor),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final filename = 'Invoice_${order.id.substring(0, order.id.length.clamp(0, 8))}.pdf';
    await downloadFile(bytes, filename);
  }
}
