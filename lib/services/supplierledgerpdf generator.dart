import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:printing/printing.dart';
import '../../models/supplier.dart';
import '../../providers/supplier_ledger_provider.dart';

class SupplierLedgerPdfGenerator {
  static final NumberFormat _currencyFormat = NumberFormat('#,##0.00');
  static final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('MMM dd, yyyy  hh:mm a');

  // Modern color palette (matching customer ledger)
  static const PdfColor _primaryPurple = PdfColor(0.486, 0.227, 0.929); // #7C3AED
  static const PdfColor _lightPurple = PdfColor(0.957, 0.949, 1.0); // #F5F3FF
  static const PdfColor _successGreen = PdfColor(0.067, 0.725, 0.506); // #10B981
  static const PdfColor _dangerRed = PdfColor(0.937, 0.267, 0.267); // #EF4444
  static const PdfColor _warningOrange = PdfColor(0.961, 0.62, 0.043); // #F59E0B
  static const PdfColor _textPrimary = PdfColor(0.11, 0.11, 0.118); // #1C1C1E
  static const PdfColor _textSecondary = PdfColor(0.557, 0.557, 0.576); // #8E8E93
  static const PdfColor _borderLight = PdfColor(0.898, 0.898, 0.918); // #E5E5EA
  static const PdfColor _backgroundLight = PdfColor(0.961, 0.961, 0.969); // #F5F5F7

  static Future<Uint8List> generateLedgerPdf({
    required String supplierName,
    required String supplierPhone,
    required String supplierAddress,
    required Map<String, dynamic> summary,
    required List<Map<String, dynamic>> entries,
    required String filterType,
    DateTimeRange? dateRange,
    Map<int, List<Map<String, dynamic>>>? receiptItemsCache,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 12.0,
          marginRight: 12.0,
          marginTop: 16.0,
          marginBottom: 16.0,
        ),
        margin: const pw.EdgeInsets.all(12),
        build: (context) => [
          _buildHeader(supplierName, supplierPhone, supplierAddress, filterType, dateRange),
          pw.SizedBox(height: 16),
          _buildLedgerTable(entries, receiptItemsCache ?? {}, summary),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(
      String name,
      String phone,
      String address,
      String filterType,
      DateTimeRange? dateRange,
      ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _borderLight, width: 1),
        ),
      ),
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left side - Title and supplier info
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SUPPLIER LEDGER STATEMENT',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryPurple,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  name,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                if (phone.isNotEmpty)
                  pw.Text(
                    phone,
                    style: pw.TextStyle(fontSize: 10, color: _textSecondary),
                  ),
                if (address.isNotEmpty)
                  pw.Text(
                    address,
                    style: pw.TextStyle(fontSize: 10, color: _textSecondary),
                    maxLines: 2,
                  ),
              ],
            ),
          ),

          // Right side - Filters and date
          pw.Expanded(
            flex: 1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: _lightPurple,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    _getFilterLabel(filterType),
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: _primaryPurple,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                if (dateRange != null)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _borderLight),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      '${_dateFormat.format(dateRange.start)} - ${_dateFormat.format(dateRange.end)}',
                      style: pw.TextStyle(fontSize: 9, color: _textSecondary),
                    ),
                  ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Generated: ${_dateTimeFormat.format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 8, color: _textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildLedgerTable(
      List<Map<String, dynamic>> entries,
      Map<int, List<Map<String, dynamic>>> receiptItemsCache,
      Map<String, dynamic> summary,
      ) {

    // Calculate totals from entries for accuracy
    double totalDebit = 0; // Paid
    double totalCredit = 0; // Payable
    double currentBalance = 0;

    if (entries.isNotEmpty) {
      for (var entry in entries) {
        totalDebit += double.tryParse(entry['debit'].toString()) ?? 0;
        totalCredit += double.tryParse(entry['credit'].toString()) ?? 0;
      }
      currentBalance = double.tryParse(entries.last['balance'].toString()) ?? 0;
    } else {
      totalDebit = double.tryParse(summary['total_debit'].toString()) ?? 0;
      totalCredit = double.tryParse(summary['total_credit'].toString()) ?? 0;
      currentBalance = double.tryParse(summary['closing_balance'].toString()) ?? 0;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Transactions',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: _textPrimary,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.ClipRRect(
          horizontalRadius: 6,
          verticalRadius: 6,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _borderLight),
            ),
            child: pw.Column(
              children: [
                // Table Header
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: const pw.BoxDecoration(
                    color: _backgroundLight,
                  ),
                  child: pw.Row(
                    children: [
                      _buildHeaderCell('DATE', flex: 2),
                      _buildHeaderCell('REF', flex: 2),
                      _buildHeaderCell('TYPE', flex: 2),
                      _buildHeaderCell('DESCRIPTION', flex: 3),
                      _buildHeaderCell('DEBIT (PAID)', flex: 2, align: pw.TextAlign.right),
                      _buildHeaderCell('CREDIT (PAYABLE)', flex: 2, align: pw.TextAlign.right),
                      _buildHeaderCell('BALANCE', flex: 2, align: pw.TextAlign.right),
                    ],
                  ),
                ),

                // Table Rows
                ...entries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  return _buildTableRow(data, index, entries.length, receiptItemsCache);
                }).expand((widget) => widget),

                // Total Row
                _buildTotalRow(totalDebit, totalCredit, currentBalance),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTotalRow(double totalDebit, double totalCredit, double closingBalance) {
    final balColor = closingBalance > 0
        ? _dangerRed  // Positive balance means supplier is owed money (payable)
        : closingBalance < 0
        ? _successGreen // Negative balance means overpaid
        : _textPrimary;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const pw.BoxDecoration(
        color: _lightPurple,
        border: pw.Border(top: pw.BorderSide(color: _primaryPurple, width: 1.5)),
      ),
      child: pw.Row(
        children: [
          // Empty space for DATE column
          pw.Expanded(flex: 2, child: pw.SizedBox()),
          // Empty space for REF column
          pw.Expanded(flex: 2, child: pw.SizedBox()),
          // Empty space for TYPE column
          pw.Expanded(flex: 2, child: pw.SizedBox()),
          // TOTAL label in DESCRIPTION column
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'TOTAL',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _primaryPurple,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Total Debit (Paid)
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              'Rs ${_currencyFormat.format(totalDebit)}',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _successGreen,
              ),
            ),
          ),
          // Total Credit (Payable)
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              'Rs ${_currencyFormat.format(totalCredit)}',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _dangerRed,
              ),
            ),
          ),
          // Closing Balance
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              'Rs ${_currencyFormat.format(closingBalance)}',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: balColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHeaderCell(String text, {int flex = 1, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: _textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  static List<pw.Widget> _buildTableRow(
      Map<String, dynamic> entry,
      int index,
      int totalEntries,
      Map<int, List<Map<String, dynamic>>> receiptItemsCache,
      ) {
    final widgets = <pw.Widget>[];

    final debitValue = double.tryParse(entry['debit'].toString()) ?? 0.0; // Paid
    final creditValue = double.tryParse(entry['credit'].toString()) ?? 0.0; // Payable
    final balanceValue = double.tryParse(entry['balance'].toString()) ?? 0.0;
    final referenceType = entry['reference_type'].toString();

    final typeStyle = _getTypeStyle(referenceType);
    final balColor = balanceValue > 0
        ? _dangerRed  // Positive balance means supplier is owed money
        : balanceValue < 0
        ? _successGreen // Negative balance means overpaid
        : _textSecondary;

    // Main row
    widgets.add(
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: pw.BoxDecoration(
          color: index.isEven ? PdfColors.white : _backgroundLight,
          border: pw.Border(bottom: pw.BorderSide(color: _borderLight, width: 0.5)),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                _dateFormat.format(DateTime.parse(entry['transaction_date'])),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                entry['reference_number'] ?? '—',
                style: pw.TextStyle(
                  fontSize: 7,
                  color: _primaryPurple,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: typeStyle['bgColor'],
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    typeStyle['label']!,
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: typeStyle['color'] as PdfColor,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                entry['description'] ?? '',
                style: const pw.TextStyle(fontSize: 8),
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                debitValue > 0 ? 'Rs ${_currencyFormat.format(debitValue)}' : '',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 8,
                  color: debitValue > 0 ? _successGreen : _textSecondary,
                  fontWeight: debitValue > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                creditValue > 0 ? 'Rs ${_currencyFormat.format(creditValue)}' : '',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 8,
                  color: creditValue > 0 ? _dangerRed : _textSecondary,
                  fontWeight: creditValue > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                'Rs ${_currencyFormat.format(balanceValue)}',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: balColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Receipt items if available (for purchase receipts)
    if (entry['reference_type'] == 'purchase_receipt' && entry['reference_id'] != null) {
      final receiptId = entry['reference_id'] as int;
      final items = receiptItemsCache[receiptId];

      if (items != null && items.isNotEmpty) {
        widgets.add(
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(24, 8, 12, 8),
            color: _lightPurple,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Items Received:',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryPurple,
                  ),
                ),
                pw.SizedBox(height: 4),
                ...items
                    .map((item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(
                          '• ${item['product_name']}',
                          style: const pw.TextStyle(fontSize: 7),
                          maxLines: 1,
                          overflow: pw.TextOverflow.clip,
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          'x${item['quantity']}',
                          style: pw.TextStyle(
                            fontSize: 7,
                            color: _primaryPurple,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'Rs ${_currencyFormat.format(item['unit_cost'])}',
                          style: const pw.TextStyle(fontSize: 7),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'Rs ${_currencyFormat.format((item['quantity'] as num) * (item['unit_cost'] as num))}',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: _dangerRed,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ))
                    .toList(),
              ],
            ),
          ),
        );
      }
    }

    return widgets;
  }

  static Map<String, dynamic> _getTypeStyle(String type) {
    switch (type) {
      case 'purchase_receipt':
        return {
          'label': 'RECEIPT',
          'color': _dangerRed,
          'bgColor': PdfColor(0.996, 0.949, 0.949),
        };
      case 'payment':
        return {
          'label': 'PAYMENT',
          'color': _successGreen,
          'bgColor': PdfColor(0.925, 0.992, 0.961),
        };
      case 'reversal':
        return {
          'label': 'REVERSAL',
          'color': _warningOrange,
          'bgColor': PdfColor(1.0, 0.984, 0.922),
        };
      default:
        return {
          'label': 'MANUAL',
          'color': _primaryPurple,
          'bgColor': _lightPurple,
        };
    }
  }

  static String _getFilterLabel(String filter) {
    switch (filter) {
      case 'all':
        return 'ALL TRANSACTIONS';
      case 'purchase_receipt':
        return 'RECEIPTS ONLY';
      case 'payment':
        return 'PAYMENTS ONLY';
      case 'reversal':
        return 'REVERSALS ONLY';
      case 'manual':
        return 'MANUAL ENTRIES';
      default:
        return filter.toUpperCase();
    }
  }
}