import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/customer.dart';

class SalePdfGenerator {
  static const PdfColor primaryColor  = PdfColor.fromInt(0xFF7C3AED);
  static const PdfColor accentColor   = PdfColor.fromInt(0xFF10B981);
  static const PdfColor dangerColor   = PdfColor.fromInt(0xFFEF4444);
  static const PdfColor textDark      = PdfColor.fromInt(0xFF1E1E2D);
  static const PdfColor textMedium    = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor textLight     = PdfColor.fromInt(0xFF9CA3AF);
  static const PdfColor borderColor   = PdfColor.fromInt(0xFFEEEEF5);
  static const PdfColor white         = PdfColors.white;
  static const PdfColor bgLight       = PdfColor.fromInt(0xFFF9FAFB);
  static const PdfColor primaryLight  = PdfColor.fromInt(0xFFF3F0FD);
  static const PdfColor accentLight   = PdfColor.fromInt(0xFFECFDF5);
  static const PdfColor primaryBorder = PdfColor.fromInt(0xFFD8B4FE);
  static const PdfColor discountColor = PdfColor.fromInt(0xFFF59E0B);

  static final DateFormat _dateFormat =
  DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat =
  DateFormat('hh:mm a');
  static final NumberFormat _currencyFormat =
  NumberFormat.currency(symbol: 'Rs ');

  // ─────────────────────────────────────────────────────────────────────────
  //  PUBLIC ENTRY POINT
  // ─────────────────────────────────────────────────────────────────────────

  static Future<Uint8List> generateSalePdf({
    required Map<String, dynamic> saleData,
    required Customer? customer,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discountValue,
    required double grandTotal,
    required bool isPosMode,
    required String paymentMethod,
    required double amountPaid,
    DateTime? dueDate,
    String? notes,
  }) async {
    if (isPosMode) {
      return _generatePosReceipt(
        saleData: saleData,
        customer: customer,
        items: items,
        subtotal: subtotal,
        discountValue: discountValue,
        grandTotal: grandTotal,
        paymentMethod: paymentMethod,
        amountPaid: amountPaid,
        dueDate: dueDate,
        notes: notes,
      );
    } else {
      return _generateInvoicePdf(
        saleData: saleData,
        customer: customer,
        items: items,
        subtotal: subtotal,
        discountValue: discountValue,
        grandTotal: grandTotal,
        paymentMethod: paymentMethod,
        amountPaid: amountPaid,
        dueDate: dueDate,
        notes: notes,
      );
    }
  }

  static Future<void> generateAndPrintSalePdf({
    required Map<String, dynamic> saleData,
    required Customer? customer,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discountValue,
    required double grandTotal,
    required bool isPosMode,
    required String paymentMethod,
    required double amountPaid,
    DateTime? dueDate,
    String? notes,
  }) async {
    try {
      final pdfData = await generateSalePdf(
        saleData: saleData,
        customer: customer,
        items: items,
        subtotal: subtotal,
        discountValue: discountValue,
        grandTotal: grandTotal,
        isPosMode: isPosMode,
        paymentMethod: paymentMethod,
        amountPaid: amountPaid,
        dueDate: dueDate,
        notes: notes,
      );
      await printPdf(pdfData);
    } catch (e) {
      print('Error generating PDF for printing: $e');
      rethrow;
    }
  }

  static Future<void> generateAndShareSalePdf({
    required Map<String, dynamic> saleData,
    required Customer? customer,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discountValue,
    required double grandTotal,
    required bool isPosMode,
    required String paymentMethod,
    required double amountPaid,
    DateTime? dueDate,
    String? notes,
    required String filename,
  }) async {
    try {
      final pdfData = await generateSalePdf(
        saleData: saleData,
        customer: customer,
        items: items,
        subtotal: subtotal,
        discountValue: discountValue,
        grandTotal: grandTotal,
        isPosMode: isPosMode,
        paymentMethod: paymentMethod,
        amountPaid: amountPaid,
        dueDate: dueDate,
        notes: notes,
      );
      await sharePdf(pdfData, filename);
    } catch (e) {
      print('Error generating PDF for sharing: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  POS RECEIPT  –  80 mm roll
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> _generatePosReceipt({
    required Map<String, dynamic> saleData,
    required Customer? customer,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discountValue,
    required double grandTotal,
    required String paymentMethod,
    required double amountPaid,
    DateTime? dueDate,
    String? notes,
  }) async {
    final pdf          = pw.Document();
    final invoiceNumber = saleData['invoice_number'] ?? 'N/A';
    final isCredit      = paymentMethod == 'credit';
    final changeAmount  = amountPaid - grandTotal;

    // ── Pre-compute item-level discount total ──────────────────────────
    final double itemDiscountsTotal = items.fold(0.0, (sum, item) {
      final qty      = (item['quantity'] as num).toInt();
      final discAmt  = (item['item_discount_amount'] as num? ?? 0).toDouble();
      return sum + (discAmt * qty);
    });

    final pageContent = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ── Store header ───────────────────────────────────────────────
        pw.Center(
          child: pw.Column(children: [
            pw.Text('Fn Solutions',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
          ]),
        ),
        pw.SizedBox(height: 6),
        _divider(),
        pw.SizedBox(height: 4),

        // ── Store info ─────────────────────────────────────────────────
        pw.Center(
          child: pw.Column(children: [
            pw.Text('Muneer Chowk, Gujranwala, Pakistan',
                style: pw.TextStyle(fontSize: 7, color: textMedium)),
            pw.Text('Phone: +92 334 4402504 | +92 312 6409506',
                style: pw.TextStyle(fontSize: 6, color: textMedium)),
          ]),
        ),
        pw.SizedBox(height: 6),

        // ── Invoice / date ─────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Invoice: $invoiceNumber',
                style: pw.TextStyle(
                    fontSize: 7, fontWeight: pw.FontWeight.bold)),
            pw.Text('Date: ${_dateFormat.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 7)),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Time: ${_timeFormat.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 7)),
            pw.Text('Cashier: Admin',
                style: const pw.TextStyle(fontSize: 7)),
          ],
        ),
        pw.SizedBox(height: 4),

        // ── Customer ───────────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            color: primaryLight,
            borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(children: [
            pw.Expanded(
              child: pw.Text(
                customer?.name ?? 'Walk-in Customer',
                style: pw.TextStyle(
                    fontSize: 7, fontWeight: pw.FontWeight.bold),
              ),
            ),
            if (customer?.contact != null &&
                customer!.contact.isNotEmpty)
              pw.Text(customer.contact,
                  style:
                  pw.TextStyle(fontSize: 6, color: textMedium)),
          ]),
        ),
        pw.SizedBox(height: 6),
        _divider(),
        pw.SizedBox(height: 4),

        // ── Items header (with discount column) ─────────────────────────
        pw.Row(children: [
          pw.Expanded(
              flex: 3,
              child: pw.Text('Item',
                  style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold))),
          pw.Expanded(
              flex: 1,
              child: pw.Text('Qty',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold))),
          pw.Expanded(
              flex: 1,
              child: pw.Text('Disc',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: discountColor))),
          pw.Expanded(
              flex: 2,
              child: pw.Text('Price',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold))),
          pw.Expanded(
              flex: 2,
              child: pw.Text('Total',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold))),
        ]),
        pw.SizedBox(height: 2),

        // ── Items ──────────────────────────────────────────────────────
        ...items.map((item) {
          final double unitPrice = (item['unit_price'] as num).toDouble();
          final double effectivePrice =
          (item['effective_unit_price'] as num? ?? unitPrice)
              .toDouble();
          final int qty = (item['quantity'] as num).toInt();
          final double itemDiscAmt =
          (item['item_discount_amount'] as num? ?? 0).toDouble();
          final double itemDiscValue =
          (item['item_discount_value'] as num? ?? 0).toDouble();
          final String itemDiscType =
          (item['item_discount_type'] as String? ?? 'fixed');
          final bool hasItemDiscount = itemDiscAmt > 0;

          // Format discount display
          String discountDisplay = '-';
          if (hasItemDiscount) {
            if (itemDiscType == 'percent') {
              discountDisplay = '${itemDiscValue.toStringAsFixed(0)}%';
            } else {
              discountDisplay = 'Rs${itemDiscAmt.toStringAsFixed(0)}';
            }
          }

          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Main item row
                pw.Row(children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      item['product_name'] ??
                          item['product']?['itemName'] ??
                          'Product',
                      style: pw.TextStyle(fontSize: 6),
                      maxLines: 2,
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(qty.toString(),
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 6)),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      discountDisplay,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 6,
                        fontWeight: pw.FontWeight.bold,
                        color: hasItemDiscount ? discountColor : textLight,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          _currencyFormat.format(effectivePrice),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 6),
                        ),
                        if (hasItemDiscount)
                          pw.Text(
                            _currencyFormat.format(unitPrice),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              fontSize: 5,
                              color: textLight,
                              decoration:
                              pw.TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      _currencyFormat
                          .format(effectivePrice * qty),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          fontSize: 6,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ]),

                // Per-item discount detail line (for POS, keep compact)
                if (hasItemDiscount && itemDiscType == 'percent')
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 2, top: 1),
                    child: pw.Row(children: [
                      pw.Expanded(
                        flex: 5,
                        child: pw.Text(
                          '  Save: ${_currencyFormat.format(itemDiscAmt * qty)}',
                          style: pw.TextStyle(
                              fontSize: 5, color: accentColor),
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
          );
        }),

        pw.SizedBox(height: 4),
        _divider(),
        pw.SizedBox(height: 4),

        // ── Totals ─────────────────────────────────────────────────────
        _summaryRow('Subtotal',
            _currencyFormat.format(subtotal),
            fontSize: 7),
        if (itemDiscountsTotal > 0)
          _summaryRow(
            'Item Discounts',
            '-${_currencyFormat.format(itemDiscountsTotal)}',
            color: accentColor,
            fontSize: 7,
          ),
        if (discountValue > 0)
          _summaryRow(
            'Order Discount',
            '-${_currencyFormat.format(discountValue)}',
            color: accentColor,
            fontSize: 7,
          ),
        _summaryRow(
          'Grand Total',
          _currencyFormat.format(grandTotal),
          isBold: true,
          fontSize: 8,
        ),
        pw.SizedBox(height: 4),

        // ── Payment box ────────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            color: isCredit ? primaryLight : accentLight,
            borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(children: [
            _summaryRow(
              'Payment Method',
              paymentMethod.toUpperCase(),
              color: isCredit ? primaryColor : accentColor,
              fontSize: 7,
            ),
            if (!isCredit) ...[
              _summaryRow(
                'Amount Paid',
                _currencyFormat.format(amountPaid),
                fontSize: 7,
              ),
              if (changeAmount > 0)
                _summaryRow(
                  'Change',
                  _currencyFormat.format(changeAmount),
                  color: accentColor,
                  fontSize: 7,
                ),
            ],
            if (isCredit && dueDate != null)
              _summaryRow(
                'Due Date',
                _dateFormat.format(dueDate),
                color: primaryColor,
                fontSize: 7,
              ),
          ]),
        ),

        // ── Credit notice ──────────────────────────────────────────────
        if (isCredit) ...[
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              color: primaryLight,
              borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              'This amount will be added to customer balance',
              style:
              pw.TextStyle(fontSize: 6, color: textMedium),
            ),
          ),
        ],

        // ── Notes ──────────────────────────────────────────────────────
        if (notes != null && notes.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              color: bgLight,
              border: pw.Border.all(color: borderColor),
              borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(notes,
                style: const pw.TextStyle(fontSize: 6)),
          ),
        ],

        pw.SizedBox(height: 8),
        _divider(thickness: 1.5),
        pw.SizedBox(height: 4),

        // ── Footer ─────────────────────────────────────────────────────
        pw.Center(
          child: pw.Column(children: [
            pw.Text('Thank you for your business!',
                style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor)),
            pw.SizedBox(height: 2),
            pw.Text('Developed By: Tech Soft',
                style:
                pw.TextStyle(fontSize: 5, color: textLight)),
            pw.Text('0341-6426617 / 03076455926',
                style:
                pw.TextStyle(fontSize: 5, color: textLight)),
          ]),
        ),
      ],
    );

    final PdfPageFormat roll80 = PdfPageFormat(
      80 * PdfPageFormat.mm,
      double.infinity,
      marginLeft: 4,
      marginRight: 4,
      marginTop: 4,
      marginBottom: 4,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: roll80,
        build: (pw.Context context) =>
            pw.Container(width: double.infinity, child: pageContent),
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  INVOICE  –  A4
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> _generateInvoicePdf({
    required Map<String, dynamic> saleData,
    required Customer? customer,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discountValue,
    required double grandTotal,
    required String paymentMethod,
    required double amountPaid,
    DateTime? dueDate,
    String? notes,
  }) async {
    final pdf           = pw.Document();
    final invoiceNumber  = saleData['invoice_number'] ?? 'N/A';
    final isCredit       = paymentMethod == 'credit';
    final changeAmount   = amountPaid - grandTotal;

    // ── Pre-compute item-level discount total ──────────────────────────
    final double itemDiscountsTotal = items.fold(0.0, (sum, item) {
      final qty     = (item['quantity'] as num).toInt();
      final discAmt = (item['item_discount_amount'] as num? ?? 0).toDouble();
      return sum + (discAmt * qty);
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context ctx) => pw.Column(
          children: [
            pw.Divider(color: borderColor),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('Developed By: Tech Soft',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: textMedium)),
                  pw.Text('0341-6426617 / 0307-6455926',
                      style: pw.TextStyle(
                          fontSize: 9, color: textMedium)),
                ],
              ),
            ),
          ],
        ),
        build: (pw.Context ctx) => [

          // ── Header ─────────────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('INVOICE',
                        style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor)),
                    pw.Text(invoiceNumber,
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: textDark)),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Fn Solutions',
                        style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                        'Muneer Chowk, Gujranwala, Pakistan',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                        'Phone: +92 312 6409506 | +92 334 4402504',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Bill To ────────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: bgLight,
              border: pw.Border.all(color: borderColor),
              borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Bill To:',
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor)),
                pw.SizedBox(height: 6),
                pw.Text(
                  customer?.name ?? 'Walk-in Customer',
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold),
                ),
                if (customer?.contact != null &&
                    customer!.contact.isNotEmpty)
                  pw.Text('Contact: ${customer.contact}',
                      style: const pw.TextStyle(fontSize: 10)),
                if (customer?.email != null)
                  pw.Text('Email: ${customer!.email}',
                      style: const pw.TextStyle(fontSize: 10)),
                if (customer?.address != null)
                  pw.Text('Address: ${customer!.address}',
                      style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── Invoice meta ───────────────────────────────────────────────
          pw.Row(children: [
            pw.Expanded(
                child: _infoRow('Invoice Date:',
                    _dateFormat.format(DateTime.now()))),
            pw.Expanded(
                child: _infoRow('Invoice Time:',
                    _timeFormat.format(DateTime.now()))),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Expanded(
                child: _infoRow('Payment Method:',
                    paymentMethod.toUpperCase())),
            pw.Expanded(
                child: _infoRow('Payment Status:',
                    isCredit ? 'UNPAID' : 'PAID')),
          ]),
          if (dueDate != null) ...[
            pw.SizedBox(height: 4),
            _infoRow('Due Date:', _dateFormat.format(dueDate)),
          ],
          pw.SizedBox(height: 20),

          // ── Items heading ──────────────────────────────────────────────
          pw.Text('Items',
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 10),

          // ── Items table (with discount column) ─────────────────────────
          pw.Container(
            decoration: pw.BoxDecoration(
              color: white,
              border: pw.Border.all(color: borderColor),
              borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(children: [

              // Table header - updated with discount column
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(
                  color: primaryLight,
                  borderRadius: pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(8),
                    topRight: pw.Radius.circular(8),
                  ),
                ),
                child: pw.Row(children: [
                  pw.Expanded(
                      flex: 1,
                      child: pw.Text('#',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              color: textDark))),
                  pw.Expanded(
                      flex: 4,
                      child: pw.Text('Product',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              color: textDark))),
                  pw.Expanded(
                      flex: 1,
                      child: pw.Text('Qty',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              color: textDark))),
                  pw.Expanded(
                      flex: 1,
                      child: pw.Text('Disc %',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              color: discountColor))),
                  pw.Expanded(
                      flex: 1,
                      child: pw.Text('Disc Amt',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              color: discountColor))),
                  pw.Expanded(
                      flex: 2,
                      child: pw.Text('Unit Price',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              color: textDark))),
                  pw.Expanded(
                      flex: 2,
                      child: pw.Text('Total',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              color: textDark))),
                ]),
              ),

              // Table data rows with discount details
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item  = entry.value;
                final double unitPrice =
                (item['unit_price'] as num).toDouble();
                final double effectivePrice =
                (item['effective_unit_price'] as num? ??
                    unitPrice)
                    .toDouble();
                final int qty =
                (item['quantity'] as num).toInt();
                final double itemDiscAmt =
                (item['item_discount_amount'] as num? ?? 0)
                    .toDouble();
                final double itemDiscValue =
                (item['item_discount_value'] as num? ?? 0)
                    .toDouble();
                final String itemDiscType =
                (item['item_discount_type'] as String? ?? 'fixed');
                final bool hasItemDiscount = itemDiscAmt > 0;

                // Calculate discount per unit for display
                double discPercent = 0;
                double discAmountPerUnit = 0;
                if (hasItemDiscount) {
                  if (itemDiscType == 'percent') {
                    discPercent = itemDiscValue;
                    discAmountPerUnit = unitPrice * (discPercent / 100);
                  } else {
                    discAmountPerUnit = itemDiscAmt;
                    discPercent = (discAmountPerUnit / unitPrice) * 100;
                  }
                }

                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: hasItemDiscount
                        ? const PdfColor.fromInt(0xFFFFF8F0)
                        : (index.isOdd ? bgLight : white),
                    border: pw.Border(
                        top: pw.BorderSide(color: borderColor)),
                  ),
                  child: pw.Row(children: [
                    pw.Expanded(
                        flex: 1,
                        child: pw.Text('${index + 1}',
                            style: pw.TextStyle(
                                fontSize: 10,
                                color: textMedium))),
                    pw.Expanded(
                      flex: 4,
                      child: pw.Column(
                        crossAxisAlignment:
                        pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            item['product_name'] ??
                                item['product']
                                ?['itemName'] ??
                                'Product',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                                color: textDark),
                          ),
                          if (hasItemDiscount)
                            pw.Text(
                              '${itemDiscType == 'percent' ? 'Percentage discount' : 'Fixed discount'}',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: discountColor),
                            ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                        flex: 1,
                        child: pw.Text(qty.toString(),
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                                fontSize: 10,
                                color: textDark))),
                    pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          hasItemDiscount && itemDiscType == 'percent'
                              ? '${discPercent.toStringAsFixed(1)}%'
                              : '-',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: hasItemDiscount
                                  ? pw.FontWeight.bold
                                  : pw.FontWeight.normal,
                              color: hasItemDiscount
                                  ? discountColor
                                  : textLight),
                        )),
                    pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          hasItemDiscount && itemDiscType == 'fixed'
                              ? _currencyFormat.format(discAmountPerUnit)
                              : '-',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: hasItemDiscount
                                  ? pw.FontWeight.bold
                                  : pw.FontWeight.normal,
                              color: hasItemDiscount
                                  ? discountColor
                                  : textLight),
                        )),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment:
                        pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            _currencyFormat
                                .format(effectivePrice),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: hasItemDiscount
                                    ? pw.FontWeight.bold
                                    : pw.FontWeight.normal,
                                color: textDark),
                          ),
                          if (hasItemDiscount)
                            pw.Text(
                              _currencyFormat.format(unitPrice),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                fontSize: 8,
                                color: textLight,
                                decoration:
                                pw.TextDecoration.lineThrough,
                              ),
                            ),
                          if (hasItemDiscount && discAmountPerUnit > 0)
                            pw.Text(
                              'Save: ${_currencyFormat.format(discAmountPerUnit)}/unit',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                fontSize: 7,
                                color: accentColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        _currencyFormat
                            .format(effectivePrice * qty),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                            color: primaryColor),
                      ),
                    ),
                  ]),
                );
              }),
            ]),
          ),
          pw.SizedBox(height: 20),

          // ── Summary box (right-aligned) ────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 260,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: bgLight,
                  border: pw.Border.all(color: borderColor),
                  borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8)),
                ),
                child: pw.Column(children: [
                  _summaryRow('Subtotal:',
                      _currencyFormat.format(subtotal)),
                  if (itemDiscountsTotal > 0)
                    _summaryRow(
                      'Item Discounts:',
                      '-${_currencyFormat.format(itemDiscountsTotal)}',
                      color: accentColor,
                    ),
                  if (discountValue > 0)
                    _summaryRow(
                      'Order Discount:',
                      '-${_currencyFormat.format(discountValue)}',
                      color: accentColor,
                    ),
                  pw.Divider(
                      height: 16,
                      thickness: 1,
                      color: borderColor),
                  _summaryRow(
                    'Grand Total:',
                    _currencyFormat.format(grandTotal),
                    isBold: true,
                    fontSize: 14,
                  ),
                  pw.SizedBox(height: 8),
                  _summaryRow('Amount Paid:',
                      _currencyFormat.format(amountPaid)),
                  if (changeAmount > 0)
                    _summaryRow(
                      'Change:',
                      _currencyFormat.format(changeAmount),
                      color: accentColor,
                    ),
                  if (isCredit)
                    _summaryRow(
                      'Outstanding:',
                      _currencyFormat.format(grandTotal),
                      color: dangerColor,
                      isBold: true,
                    ),
                ]),
              ),
            ],
          ),

          // ── Credit terms ───────────────────────────────────────────────
          if (isCredit) ...[
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: primaryLight,
                border: pw.Border.all(color: primaryBorder),
                borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Credit Terms',
                      style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor)),
                  if (dueDate != null) ...[
                    pw.SizedBox(height: 8),
                    pw.Row(children: [
                      pw.Text('Due Date: ',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10)),
                      pw.Text(_dateFormat.format(dueDate),
                          style:
                          const pw.TextStyle(fontSize: 10)),
                    ]),
                  ],
                  if (notes != null && notes.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text('Notes: $notes',
                        style:
                        const pw.TextStyle(fontSize: 10)),
                  ],
                ],
              ),
            ),
          ],

          // ── Notes (non-credit) ─────────────────────────────────────────
          if (notes != null && notes.isNotEmpty && !isCredit) ...[
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: bgLight,
                border: pw.Border.all(color: borderColor),
                borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8)),
              ),
              child: pw.Text('Notes: $notes',
                  style: const pw.TextStyle(fontSize: 10)),
            ),
          ],

          pw.SizedBox(height: 20),
          pw.Divider(thickness: 1, color: borderColor),
          pw.SizedBox(height: 8),

          // ── Signature row ──────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Authorized Signature',
                  style: pw.TextStyle(
                      color: textLight, fontSize: 10)),
              pw.Text('For Your Store Name',
                  style: pw.TextStyle(
                      color: textLight, fontSize: 10)),
            ],
          ),
          pw.SizedBox(height: 16),

          // ── Footer ─────────────────────────────────────────────────────
          pw.Center(
            child: pw.Column(children: [
              pw.Text(
                'This is a computer generated invoice - valid without signature',
                style: pw.TextStyle(
                  color: textLight,
                  fontSize: 9,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Thank you for your business!',
                style: pw.TextStyle(
                  color: primaryColor,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ]),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  static pw.Widget _summaryRow(
      String label,
      String value, {
        bool isBold = false,
        double fontSize = 10,
        PdfColor? color,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: isBold
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                color: color ?? textMedium,
              )),
          pw.Text(value,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: pw.FontWeight.bold,
                color: color ?? textDark,
              )),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: textMedium)),
        pw.SizedBox(width: 8),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 10, color: textDark)),
      ]),
    );
  }

  static pw.Widget _divider({double thickness = 1}) =>
      pw.Container(height: thickness, color: borderColor);

  // ─────────────────────────────────────────────────────────────────────────
  //  PRINT / SHARE
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> printPdf(Uint8List pdfData) async =>
      await Printing.layoutPdf(onLayout: (_) async => pdfData);

  static Future<void> sharePdf(
      Uint8List pdfData, String filename) async =>
      await Printing.sharePdf(bytes: pdfData, filename: filename);
}