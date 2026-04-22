// lib/screens/sales/all_returns_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/api_config.dart';

class AllReturnsScreen extends StatefulWidget {
  const AllReturnsScreen({super.key});

  @override
  State<AllReturnsScreen> createState() => _AllReturnsScreenState();
}

class _AllReturnsScreenState extends State<AllReturnsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<dynamic> _returns = [];
  bool _isLoading = true;
  String? _error;

  // Summary
  double _totalRefunded = 0;
  int _totalReturns = 0;

  // Filters
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _selectedReturnType; // 'full' | 'partial'
  String? _selectedRefundMethod; // 'cash' | 'bank_transfer' | 'cheque' | 'credit_note'
  bool _showFilters = false;

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  static const int _pageSize = 20;

  Timer? _debounce;

  final _dateFormat = DateFormat('MMM dd, yyyy');
  final _currencyFormat = NumberFormat.currency(symbol: 'Rs ');

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _fetchReturns();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetchReturns(reset: true));
  }

  Future<void> _fetchReturns({bool reset = false}) async {
    if (reset) setState(() => _currentPage = 1);

    setState(() { _isLoading = true; _error = null; });

    try {
      final params = {
        'page': _currentPage.toString(),
        'limit': _pageSize.toString(),
        if (_fromDate != null) 'from_date': _fromDate!.toIso8601String().split('T').first,
        if (_toDate != null) 'to_date': _toDate!.toIso8601String().split('T').first,
        if (_selectedReturnType != null) 'return_type': _selectedReturnType!,
        if (_selectedRefundMethod != null) 'refund_method': _selectedRefundMethod!,
      };

      final uri = Uri.parse(ApiConfig.saleReturnsUrl).replace(queryParameters: params);
      final res = await http.get(uri, headers: {'Content-Type': 'application/json'});
      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        setState(() {
          _returns = data['data'] as List;
          _totalPages = data['pagination']?['pages'] ?? 1;
          _totalRefunded = (data['summary']?['total_refunds'] ?? 0).toDouble();
          _totalReturns = (data['summary']?['total_returns'] ?? 0) as int;
          _isLoading = false;
        });
      } else {
        throw Exception(data['message'] ?? 'Failed to load returns');
      }
    } catch (e) {
      print(e);
      setState(() { _error = 'Failed to load returns: $e'; _isLoading = false; });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _fromDate = picked.start; _toDate = picked.end; });
      _fetchReturns(reset: true);
    }
  }

  void _clearFilters() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _selectedReturnType = null;
      _selectedRefundMethod = null;
      _searchCtrl.clear();
    });
    _fetchReturns(reset: true);
  }

  Color _returnTypeColor(String type) => type == 'full' ? Colors.red : Colors.orange;

  Color _methodColor(String method) {
    switch (method) {
      case 'cash': return const Color(0xFF10B981);
      case 'bank_transfer': return const Color(0xFF3B82F6);
      case 'cheque': return const Color(0xFFF59E0B);
      case 'credit_note': return const Color(0xFF8B5CF6);
      default: return Colors.grey;
    }
  }

  String _methodLabel(String method) {
    const labels = {
      'cash': 'Cash',
      'bank_transfer': 'Bank transfer',
      'cheque': 'Cheque',
      'credit_note': 'Credit note',
    };
    return labels[method] ?? method;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      body: Column(
        children: [
          _buildHeader(),
          _buildSummaryBar(),
          _buildSearchRow(),
          if (_showFilters) _buildFiltersPanel(),
          Expanded(child: _buildBody()),
          if (_totalPages > 1) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_return, color: Colors.orange, size: 22),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sale Returns', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
              Text('All returned items across sales', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchReturns(),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
      ),
      child: Row(
        children: [
          _buildStat(
            icon: Icons.assignment_return,
            label: 'Total returns',
            value: _totalReturns.toString(),
            color: Colors.orange,
          ),
          _buildDivider(),
          _buildStat(
            icon: Icons.currency_exchange,
            label: 'Total refunded',
            value: _currencyFormat.format(_totalRefunded),
            color: const Color(0xFF7C3AED),
          ),
          _buildDivider(),
          _buildStat(
            icon: Icons.inventory_2_outlined,
            label: 'This page',
            value: '${_returns.length} records',
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildStat({required IconData icon, required String label, required String value, required Color color}) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Container(width: 1, height: 40, color: const Color(0xFFF0F0F5), margin: const EdgeInsets.symmetric(horizontal: 12));

  Widget _buildSearchRow() {
    final hasFilters = _fromDate != null || _toDate != null || _selectedReturnType != null || _selectedRefundMethod != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by return number or invoice...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Stack(
            children: [
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _showFilters ? const Color(0xFF7C3AED) : const Color(0xFFF0F0F5),
                    width: 1.5,
                  ),
                ),
                child: IconButton(
                  onPressed: () => setState(() => _showFilters = !_showFilters),
                  icon: Icon(Icons.filter_list, color: _showFilters ? const Color(0xFF7C3AED) : Colors.grey[600]),
                ),
              ),
              if (hasFilters)
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
          if (hasFilters) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: _clearFilters, child: const Text('Clear', style: TextStyle(color: Colors.orange))),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltersPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filters', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDropdown<String?>(
                label: 'Return type',
                value: _selectedReturnType,
                items: const [
                  DropdownMenuItem(value: null, child: Text('All types')),
                  DropdownMenuItem(value: 'full', child: Text('Full return')),
                  DropdownMenuItem(value: 'partial', child: Text('Partial return')),
                ],
                onChanged: (v) { setState(() => _selectedReturnType = v); _fetchReturns(reset: true); },
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdown<String?>(
                label: 'Refund method',
                value: _selectedRefundMethod,
                items: const [
                  DropdownMenuItem(value: null, child: Text('All methods')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'bank_transfer', child: Text('Bank transfer')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  DropdownMenuItem(value: 'credit_note', child: Text('Credit note')),
                ],
                onChanged: (v) { setState(() => _selectedRefundMethod = v); _fetchReturns(reset: true); },
              )),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _selectDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFF0F0F5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.date_range, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _fromDate != null && _toDate != null
                                ? '${_dateFormat.format(_fromDate!)} – ${_dateFormat.format(_toDate!)}'
                                : 'Date range',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          hint: Text(label, style: const TextStyle(fontSize: 13)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchReturns, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_returns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_return_outlined, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No returns found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[500])),
            const SizedBox(height: 6),
            Text('Returns will appear here once processed', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchReturns(),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        itemCount: _returns.length,
        itemBuilder: (context, index) => _buildReturnCard(_returns[index]),
      ),
    );
  }

  Widget _buildReturnCard(dynamic r) {
    final returnNumber = r['return_number']?.toString() ?? '—';
    final invoiceNumber = r['originalSale']?['invoice_number']?.toString() ?? '—';
    final customerName = r['customer']?['name']?.toString() ?? 'Walk-in';
    final returnType = r['return_type']?.toString() ?? '';
    final refundMethod = r['refund_method']?.toString() ?? '';
    final adjustmentType = r['adjustment_type']?.toString() ?? '';
    final status = r['status']?.toString() ?? 'completed';
    final refundAmount = (r['refund_amount'] != null)
        ? double.tryParse(r['refund_amount'].toString()) ?? 0.0
        : 0.0;
    final returnDate = r['return_date'] != null
        ? _dateFormat.format(DateTime.parse(r['return_date']))
        : '—';
    final items = (r['items'] as List?) ?? [];
    final reason = r['reason']?.toString();

    final typeColor = _returnTypeColor(returnType);
    final methodColor = _methodColor(refundMethod);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: typeColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(returnNumber, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.receipt_long, size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(invoiceNumber, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          const SizedBox(width: 12),
                          Icon(Icons.person, size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(customerName, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
                // Amount chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _currencyFormat.format(refundAmount),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Date + badges
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(Icons.calendar_today, returnDate, Colors.grey),
                _chip(
                  returnType == 'full' ? Icons.undo : Icons.remove_circle_outline,
                  returnType == 'full' ? 'Full return' : 'Partial return',
                  typeColor,
                ),
                _chip(_methodIcon(refundMethod), _methodLabel(refundMethod), methodColor),
                _chip(
                  adjustmentType == 'refund' ? Icons.payments_outlined : Icons.account_balance_wallet,
                  adjustmentType == 'refund' ? 'Cash refund' : 'Reduce balance',
                  Colors.purple,
                ),
                _chip(Icons.check_circle_outline, status, Colors.green),
              ],
            ),

            // Items summary
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${items.length} item${items.length > 1 ? 's' : ''} returned',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade700),
                    ),
                    const SizedBox(height: 8),
                    ...items.map<Widget>((item) {
                      final name = item['product_name']?.toString() ?? '—';
                      final qty = item['quantity_returned'] ?? 0;
                      final unitPrice = double.tryParse(item['refund_unit_price']?.toString() ?? '0') ?? 0;
                      final total = double.tryParse(item['total_refund']?.toString() ?? '0') ?? 0;
                      final condition = item['condition']?.toString() ?? 'sellable';
                      final conditionColor = condition == 'sellable' ? Colors.green : condition == 'damaged' ? Colors.red : Colors.orange;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                            ),
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: conditionColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(condition, style: TextStyle(fontSize: 10, color: conditionColor, fontWeight: FontWeight.w600)),
                            ),
                            Text('×$qty', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            const SizedBox(width: 8),
                            Text('@${_currencyFormat.format(unitPrice)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            const Spacer(),
                            Text(
                              _currencyFormat.format(total),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.comment_outlined, size: 13, color: Colors.grey[400]),
                  const SizedBox(width: 6),
                  Text('Reason: ', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                  Expanded(child: Text(reason, style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  IconData _methodIcon(String method) {
    switch (method) {
      case 'cash': return Icons.payments_outlined;
      case 'bank_transfer': return Icons.account_balance_outlined;
      case 'cheque': return Icons.receipt_long_outlined;
      case 'credit_note': return Icons.credit_card_outlined;
      default: return Icons.monetization_on_outlined;
    }
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 1 ? () { setState(() => _currentPage--); _fetchReturns(); } : null,
            icon: const Icon(Icons.chevron_left),
            color: _currentPage > 1 ? const Color(0xFF7C3AED) : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text('Page $_currentPage of $_totalPages', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _currentPage < _totalPages ? () { setState(() => _currentPage++); _fetchReturns(); } : null,
            icon: const Icon(Icons.chevron_right),
            color: _currentPage < _totalPages ? const Color(0xFF7C3AED) : Colors.grey,
          ),
        ],
      ),
    );
  }
}