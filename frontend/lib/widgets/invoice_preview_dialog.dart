import 'package:flutter/material.dart';

import '../models/document.dart';
import '../models/order.dart';
import '../services/customer_auth_service.dart';
import '../services/invoice_service.dart';
import '../utils/download_helper.dart';

class InvoicePreviewDialog extends StatefulWidget {
  final PrintOrder order;
  final List<DocumentPrintConfig>? configs;
  final List<UploadedDocument>? documents;
  final String? paymentId;
  final String? otp;
  final String? userName;
  final String? userRoll;
  final String? userEmail;
  final String? userDept;
  final String? location;

  const InvoicePreviewDialog({
    super.key,
    required this.order,
    this.configs,
    this.documents,
    this.paymentId,
    this.otp,
    this.userName,
    this.userRoll,
    this.userEmail,
    this.userDept,
    this.location,
  });

  static Future<void> show(
    BuildContext context, {
    required PrintOrder order,
    List<DocumentPrintConfig>? configs,
    List<UploadedDocument>? documents,
    String? paymentId,
    String? otp,
    String? userName,
    String? userRoll,
    String? userEmail,
    String? userDept,
    String? location,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => InvoicePreviewDialog(
        order: order,
        configs: configs,
        documents: documents,
        paymentId: paymentId,
        otp: otp,
        userName: userName,
        userRoll: userRoll,
        userEmail: userEmail,
        userDept: userDept,
        location: location,
      ),
    );
  }

  @override
  State<InvoicePreviewDialog> createState() => _InvoicePreviewDialogState();
}

class _InvoicePreviewDialogState extends State<InvoicePreviewDialog> {
  bool _isDownloading = false;

  Future<void> _handleDownload() async {
    setState(() => _isDownloading = true);
    try {
      await InvoiceService.generateAndDownloadInvoice(
        order: widget.order,
        configs: widget.configs,
        documents: widget.documents,
        paymentId: widget.paymentId,
        otp: widget.otp,
        userName: widget.userName,
        userRoll: widget.userRoll,
        userEmail: widget.userEmail,
        userDept: widget.userDept,
        location: widget.location,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice downloaded.'),
            backgroundColor: Color(0xFF16A34A),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _handleOpenPdf() async {
    try {
      final bytes = await InvoiceService.generateInvoicePdfBytes(
        order: widget.order,
        configs: widget.configs,
        documents: widget.documents,
        paymentId: widget.paymentId,
        otp: widget.otp,
        userName: widget.userName,
        userRoll: widget.userRoll,
        userEmail: widget.userEmail,
        userDept: widget.userDept,
        location: widget.location,
      );
      openPdfInNewTab(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open PDF: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = InvoiceService.formatInvoiceDateTime(
      widget.order.createdAt,
    );

    final authUser = CustomerAuthService().currentUser;
    final finalName = (widget.userName != null && widget.userName!.isNotEmpty)
        ? widget.userName!
        : (authUser?.fullName ?? '');
    final finalRoll = (widget.userRoll != null && widget.userRoll!.isNotEmpty)
        ? widget.userRoll!
        : (widget.order.rollNumber ?? authUser?.rollNumber ?? '');
    final finalEmail =
        (widget.userEmail != null && widget.userEmail!.isNotEmpty)
        ? widget.userEmail!
        : (authUser?.email ?? '');
    final finalDept = (widget.userDept != null && widget.userDept!.isNotEmpty)
        ? widget.userDept!
        : (widget.order.department ?? authUser?.department ?? 'CSE');
    final finalLocation =
        (widget.location != null && widget.location!.isNotEmpty)
        ? widget.location!
        : (widget.order.department ?? 'CSE');
    final finalOtp = widget.otp ?? '';

    const primaryColor = Color(0xFF0B3C95);
    const coralColor = Color(0xFFE05A47);
    const borderColor = Color(0xFFE2E8F0);
    const darkText = Color(0xFF0F172A);
    const slateColor = Color(0xFF64748B);

    // Build line items
    final List<List<String>> tableData = [];
    if (widget.configs != null && widget.configs!.isNotEmpty) {
      for (int i = 0; i < widget.configs!.length; i++) {
        final c = widget.configs![i];
        final rate = c.isColor ? 10.0 : 2.0;
        final subtotal = c.estimatedCost;
        tableData.add([
          '${i + 1}',
          c.document.filename,
          c.pageRangeDescription.toLowerCase() == 'all'
              ? 'all'
              : c.pageRangeDescription,
          c.colorDescription,
          c.sidesDescription,
          '${c.copies}',
          '${c.calculatedPages * c.copies}',
          'Rs ${rate.toStringAsFixed(2)}',
          'Rs ${subtotal.toStringAsFixed(2)}',
        ]);
      }
    } else if (widget.order.printSettings.items.isNotEmpty) {
      for (int i = 0; i < widget.order.printSettings.items.length; i++) {
        final item = widget.order.printSettings.items[i];
        tableData.add([
          '${i + 1}',
          item.filename,
          widget.order.printSettings.pageRange.toLowerCase() == 'all'
              ? 'all'
              : widget.order.printSettings.pageRange,
          item.colour ? 'Full Color' : 'Black & White',
          widget.order.printSettings.sides == 'one-sided'
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
    } else if (widget.documents != null && widget.documents!.isNotEmpty) {
      for (int i = 0; i < widget.documents!.length; i++) {
        final d = widget.documents![i];
        final rate = widget.order.isColor ? 10.0 : 2.0;
        final subtotal = d.pages * widget.order.copies * rate;
        tableData.add([
          '${i + 1}',
          d.filename,
          widget.order.pageRange.toLowerCase() == 'all'
              ? 'all'
              : widget.order.pageRange,
          widget.order.isColor ? 'Full Color' : 'Black & White',
          widget.order.duplex ? 'Double-Sided' : 'Single-Sided',
          '${widget.order.copies}',
          '${d.pages * widget.order.copies}',
          'Rs ${rate.toStringAsFixed(2)}',
          'Rs ${subtotal.toStringAsFixed(2)}',
        ]);
      }
    } else {
      final rate = widget.order.isColor ? 10.0 : 2.0;
      tableData.add([
        '1',
        'Print Document Order',
        widget.order.pageRange.toLowerCase() == 'all'
            ? 'all'
            : widget.order.pageRange,
        widget.order.isColor ? 'Full Color' : 'Black & White',
        widget.order.duplex ? 'Double-Sided' : 'Single-Sided',
        '${widget.order.copies}',
        '${widget.order.totalPages}',
        'Rs ${rate.toStringAsFixed(2)}',
        'Rs ${widget.order.amount.toStringAsFixed(2)}',
      ]);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 880),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Action Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: primaryColor,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Tax Invoice / Receipt',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: darkText,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        side: const BorderSide(color: borderColor, width: 1.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _handleOpenPdf,
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text(
                        'Open PDF',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isDownloading ? null : _handleDownload,
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 15),
                      label: Text(
                        _isDownloading ? 'Downloading...' : 'Download PDF',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // Scrollable Invoice Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 630),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 36,
                        vertical: 32,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left: Logo & College branding
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/images/achuppori-logo.png',
                                        width: 38,
                                        height: 38,
                                        errorBuilder: (ctx, err, stack) =>
                                            const SizedBox.shrink(),
                                      ),
                                      const SizedBox(width: 8),
                                      Image.asset(
                                        'assets/images/achuppori-wordmark.png',
                                        height: 26,
                                        errorBuilder: (ctx, err, stack) =>
                                            const Text(
                                              'Achuppori',
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w800,
                                                color: primaryColor,
                                              ),
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  RichText(
                                    text: const TextSpan(
                                      style: TextStyle(
                                        fontFamily: 'serif',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'N',
                                          style: TextStyle(color: coralColor),
                                        ),
                                        TextSpan(
                                          text: 'ational ',
                                          style: TextStyle(
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        TextSpan(
                                          text: 'E',
                                          style: TextStyle(color: coralColor),
                                        ),
                                        TextSpan(
                                          text: 'ngineering\n',
                                          style: TextStyle(
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        TextSpan(
                                          text: 'C',
                                          style: TextStyle(color: coralColor),
                                        ),
                                        TextSpan(
                                          text: 'ollege,',
                                          style: TextStyle(
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        TextSpan(
                                          text: 'K',
                                          style: TextStyle(color: coralColor),
                                        ),
                                        TextSpan(
                                          text: 'ovilpatti',
                                          style: TextStyle(
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Right: Tax Invoice badge, Order ID, Date
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'TAX INVOICE / RECEIPT',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Order ID: ${widget.order.id}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5,
                                      color: darkText,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Date: $formattedDate',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: slateColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          const Divider(color: borderColor, thickness: 0.8),
                          const SizedBox(height: 14),

                          // Status / Payment Method / Location bar
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: borderColor,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Payment Status',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: slateColor,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'PAID (Verified)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Payment Method',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: slateColor,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Razorpay Online',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: darkText,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Location',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: slateColor,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      finalLocation,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: darkText,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Document Print Specifications & Summary
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'Document Print Specifications:',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                width: 200,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F7FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFD6E4FF),
                                    width: 0.8,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Total Printed Pages:',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                        Text(
                                          '${widget.order.totalPages}',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: darkText,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Copies Multiplier:',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                        Text(
                                          '${widget.order.copies}',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: darkText,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Total Paid:',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: primaryColor,
                                          ),
                                        ),
                                        Text(
                                          'Rs ${widget.order.amount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
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

                          const SizedBox(height: 8),

                          // Table
                          Table(
                            border: TableBorder.all(
                              color: const Color(0xFF0F172A),
                              width: 0.8,
                            ),
                            columnWidths: const {
                              0: FixedColumnWidth(24),
                              1: FlexColumnWidth(3.0),
                              2: FlexColumnWidth(1.1),
                              3: FlexColumnWidth(1.8),
                              4: FlexColumnWidth(1.8),
                              5: FlexColumnWidth(1.0),
                              6: FlexColumnWidth(1.0),
                              7: FlexColumnWidth(1.3),
                              8: FlexColumnWidth(1.4),
                            },
                            children: [
                              TableRow(
                                decoration: const BoxDecoration(
                                  color: primaryColor,
                                ),
                                children: [
                                  _tableHeaderCell('#'),
                                  _tableHeaderCell('Document'),
                                  _tableHeaderCell('Pages'),
                                  _tableHeaderCell('Color Mode'),
                                  _tableHeaderCell('Sides'),
                                  _tableHeaderCell('Copies'),
                                  _tableHeaderCell('Qty'),
                                  _tableHeaderCell('Rate'),
                                  _tableHeaderCell('Subtotal'),
                                ],
                              ),
                              for (final row in tableData)
                                TableRow(
                                  children: [
                                    _tableDataCell(row[0], Alignment.center),
                                    _tableDataCell(
                                      row[1],
                                      Alignment.centerLeft,
                                    ),
                                    _tableDataCell(row[2], Alignment.center),
                                    _tableDataCell(row[3], Alignment.center),
                                    _tableDataCell(row[4], Alignment.center),
                                    _tableDataCell(row[5], Alignment.center),
                                    _tableDataCell(row[6], Alignment.center),
                                    _tableDataCell(row[7], Alignment.center),
                                    _tableDataCell(
                                      row[8],
                                      Alignment.centerRight,
                                    ),
                                  ],
                                ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Your Details Section
                          const Text(
                            'Your Details:',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.only(left: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _detailLine('Your Name:', finalName),
                                const SizedBox(height: 7),
                                _detailLine('Your ID:', finalRoll),
                                const SizedBox(height: 7),
                                _detailLine(
                                  'Your Email:',
                                  finalEmail.isNotEmpty ? finalEmail : '—',
                                ),
                                const SizedBox(height: 7),
                                _detailLine('Your Dept:', finalDept),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Your OTP Box
                          if (finalOtp.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9FF),
                                border: Border.all(
                                  color: const Color(0xFF0284C7),
                                  width: 1.2,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Your OTP: $finalOtp',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0369A1),
                                ),
                              ),
                            ),

                          const SizedBox(height: 40),

                          // Footer "THANK YOU"
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: coralColor,
                                  width: 1.2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'THANK YOU',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableHeaderCell(String text) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _tableDataCell(String text, Alignment alignment) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(vertical: 7.5, horizontal: 5),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        Text(
          value.isNotEmpty ? ' $value' : '',
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF334155),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
