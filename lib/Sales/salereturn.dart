import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../models/sale_model.dart';

class SaleReturnDialog extends StatefulWidget {
  final SaleModel sale;

  const SaleReturnDialog({
    super.key,
    required this.sale,
  });

  @override
  State<SaleReturnDialog> createState() => _SaleReturnDialogState();
}

class _SaleReturnDialogState extends State<SaleReturnDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _reasonController = TextEditingController();

  String _refundMethod = 'cash';
  String _adjustmentType = 'refund';
  DateTime _returnDate = DateTime.now();

  Map<int, ReturnItem> _returnItems = {};
  bool _isLoading = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Rs ');

  @override
  void initState() {
    super.initState();
    _initializeReturnItems();
  }

  void _initializeReturnItems() {
    for (var item in widget.sale.items ?? []) {
      _returnItems[item.id] = ReturnItem(
        saleItemId: item.id,
        productName: item.productName,
        originalQuantity: item.quantity,
        returnedQuantity: 0,
        originalUnitPrice: item.unitPrice,
        refundUnitPrice: item.unitPrice,
        condition: 'sellable',
      );
    }
  }

  double get _totalRefundAmount {
    double total = 0;
    for (var item in _returnItems.values) {
      total += item.refundAmount;
    }
    return total;
  }

  bool get _hasValidReturns {
    return _returnItems.values.any((item) => item.returnedQuantity > 0);
  }

  Future<void> _submitReturn() async {
    if (!_hasValidReturns) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item to return')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final items = _returnItems.values
        .where((item) => item.returnedQuantity > 0)
        .map((item) => {
      'sale_item_id': item.saleItemId,
      'quantity_returned': item.returnedQuantity,
      'refund_unit_price': item.refundUnitPrice,
      'reason': item.reason ?? _reasonController.text,
      'condition': item.condition,
    })
        .toList();

    final body = {
      'sale_id': widget.sale.id,
      'return_date': _returnDate.toIso8601String().split('T').first,
      'items': items,
      'refund_method': _refundMethod,
      'adjustment_type': _adjustmentType,
      'reason': _reasonController.text.isNotEmpty ? _reasonController.text : null,
      'notes': _notesController.text.isNotEmpty ? _notesController.text : null,
    };

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.saleReturnsUrl),  // was: '${ApiConfig.baseUrl}/api/sales/returns'
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 201 && result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Return processed successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to refresh
        }
      } else {
        throw Exception(result['message'] ?? 'Failed to process return');
      }
    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF7C3AED),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_return, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Process Sale Return',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.sale.invoiceNumber,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Return Date
                      _buildDatePicker(),
                      const SizedBox(height: 16),

                      // Items List
                      const Text(
                        'Items to Return',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.sale.items?.length ?? 0,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = widget.sale.items![index];
                            final returnItem = _returnItems[item.id]!;
                            return _buildReturnItemCard(item, returnItem);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Refund Method
                      const Text('Refund Method', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildMethodChip('cash', 'Cash', Icons.payments),
                          _buildMethodChip('bank_transfer', 'Bank Transfer', Icons.account_balance),
                          _buildMethodChip('cheque', 'Cheque', Icons.receipt),
                          _buildMethodChip('credit_note', 'Credit Note', Icons.credit_card),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Adjustment Type
                      const Text('Adjustment Type', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAdjustmentCard(
                              'refund',
                              'Cash Refund',
                              'Return money to customer',
                              Icons.payments_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildAdjustmentCard(
                              'reduce_balance',
                              'Reduce Balance',
                              'Adjust customer outstanding',
                              Icons.account_balance_wallet,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Reason
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Reason for Return (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.comment),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Notes
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Additional Notes (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.note),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Summary
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Refund Amount:',
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  _currencyFormat.format(_totalRefundAmount),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
                            ),
                            if (_adjustmentType == 'reduce_balance')
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info, size: 14, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'This will reduce customer\'s outstanding balance',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading || !_hasValidReturns ? null : _submitReturn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Text('Process Return', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _returnDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() => _returnDate = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFF7C3AED)),
            const SizedBox(width: 12),
            Text(
              'Return Date: ${DateFormat('dd/MM/yyyy').format(_returnDate)}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnItemCard(dynamic item, ReturnItem returnItem) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _currencyFormat.format(item.unitPrice),
                style: const TextStyle(color: Color(0xFF7C3AED)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Quantity selector
              Container(
                width: 100,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<int>(
                  value: returnItem.returnedQuantity,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('None')),
                    for (int i = 1; i <= item.quantity; i++)
                      DropdownMenuItem(value: i, child: Text('$i item${i > 1 ? 's' : ''}')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      returnItem.returnedQuantity = value ?? 0;
                      _returnItems[item.id] = returnItem;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Refund price (optional - for partial refunds)
              Expanded(
                child: TextFormField(
                  initialValue: returnItem.refundUnitPrice.toStringAsFixed(2),
                  decoration: const InputDecoration(
                    labelText: 'Refund Price',
                    prefixText: 'Rs ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final price = double.tryParse(value);
                    if (price != null) {
                      setState(() {
                        returnItem.refundUnitPrice = price;
                        _returnItems[item.id] = returnItem;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          if (returnItem.returnedQuantity > 0) ...[
            const SizedBox(height: 8),
            // Condition dropdown
            Row(
              children: [
                const Text('Condition: ', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                _buildConditionChip('sellable', 'Sellable', returnItem),
                const SizedBox(width: 6),
                _buildConditionChip('damaged', 'Damaged', returnItem),
                const SizedBox(width: 6),
                _buildConditionChip('defective', 'Defective', returnItem),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Refund: ${_currencyFormat.format(returnItem.refundAmount)}',
              style: const TextStyle(fontSize: 12, color: Colors.green),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConditionChip(String value, String label, ReturnItem item) {
    return GestureDetector(
      onTap: () {
        setState(() {
          item.condition = value;
          _returnItems[item.saleItemId] = item;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: item.condition == value ? Colors.purple.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.condition == value ? const Color(0xFF7C3AED) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: item.condition == value ? const Color(0xFF7C3AED) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildMethodChip(String value, String label, IconData icon) {
    return GestureDetector(
      onTap: () => setState(() => _refundMethod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _refundMethod == value ? Colors.purple.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _refundMethod == value ? const Color(0xFF7C3AED) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _refundMethod == value ? const Color(0xFF7C3AED) : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: _refundMethod == value ? const Color(0xFF7C3AED) : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildAdjustmentCard(String value, String title, String subtitle, IconData icon) {
    final isSelected = _adjustmentType == value;
    return GestureDetector(
      onTap: () => setState(() => _adjustmentType = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF7C3AED) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF7C3AED) : Colors.grey.shade600),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class ReturnItem {
  final int saleItemId;
  final String productName;
  final int originalQuantity;
  int returnedQuantity;
  double originalUnitPrice;
  double refundUnitPrice;
  String condition;
  String? reason;

  ReturnItem({
    required this.saleItemId,
    required this.productName,
    required this.originalQuantity,
    required this.returnedQuantity,
    required this.originalUnitPrice,
    required this.refundUnitPrice,
    required this.condition,
    this.reason,
  });

  double get refundAmount => refundUnitPrice * returnedQuantity;
}
