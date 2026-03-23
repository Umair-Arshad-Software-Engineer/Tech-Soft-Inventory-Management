// lib/screens/sales/sale_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/sale_provider.dart';
import '../../models/sale_model.dart';
import '../components/loading_indicator.dart';
import '../components/error_widget.dart';
import '../Banks/banknames.dart';
import '../models/customer.dart';
import '../services/sale_pdf_generator.dart';
import 'sale_screen.dart';

class SaleDetailScreen extends StatefulWidget {
  final int saleId;
  const SaleDetailScreen({super.key, required this.saleId});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  SaleModel? _sale;
  bool _isLoading = true;
  String? _error;

  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final DateFormat _timeFormat = DateFormat('hh:mm a');
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Rs ');

  @override
  void initState() {
    super.initState();
    _loadSale();
  }

  Future<void> _loadSale() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = Provider.of<SaleProvider>(context, listen: false);
      final sale = await provider.getSaleById(widget.saleId);

      setState(() {
        _sale = sale;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load sale details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _voidSale() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Void Sale'),
        content: Text('Are you sure you want to void ${_sale!.invoiceNumber}? This will restore stock and reverse ledger entries.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Void Sale'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final provider = Provider.of<SaleProvider>(context, listen: false);
      final result = await provider.deleteSale(widget.saleId);

      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale voided successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return with refresh flag
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to void sale'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _recordPayment() async {
    if (_sale == null) return;

    final amountController = TextEditingController(text: _sale!.outstandingBalance.toStringAsFixed(2));
    String selectedMethod = 'cash';

    // Bank transfer fields
    Bank? selectedFromBank;
    Bank? selectedToBank;
    final bankDescriptionCtrl = TextEditingController();

    // Cheque fields
    final chequeNumberCtrl = TextEditingController();
    DateTime? chequeDate;
    Bank? selectedChequeBank;

    // Slip fields
    final slipNumberCtrl = TextEditingController();
    DateTime? slipDate;
    Bank? selectedSlipBank;

    DateTime? paymentDate = DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Record Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Outstanding amount info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Outstanding: ${_currencyFormat.format(_sale!.outstandingBalance)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Amount
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Payment Amount',
                    prefixText: 'Rs ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Date
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: paymentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED)),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setState(() => paymentDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 12),
                        Text('Payment Date: ${DateFormat('MMM dd, yyyy').format(paymentDate!)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Method Selector
                const Text(
                  'Payment Method',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                // Method chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMethodChip(
                        label: 'Cash',
                        icon: Icons.payments_outlined,
                        color: const Color(0xFF10B981),
                        isSelected: selectedMethod == 'cash',
                        onTap: () => setState(() => selectedMethod = 'cash'),
                      ),
                      const SizedBox(width: 8),
                      _buildMethodChip(
                        label: 'Bank',
                        icon: Icons.account_balance_outlined,
                        color: const Color(0xFF3B82F6),
                        isSelected: selectedMethod == 'bank',
                        onTap: () => setState(() => selectedMethod = 'bank'),
                      ),
                      const SizedBox(width: 8),
                      _buildMethodChip(
                        label: 'Cheque',
                        icon: Icons.receipt_long_outlined,
                        color: const Color(0xFFF59E0B),
                        isSelected: selectedMethod == 'cheque',
                        onTap: () => setState(() => selectedMethod = 'cheque'),
                      ),
                      const SizedBox(width: 8),
                      _buildMethodChip(
                        label: 'Slip',
                        icon: Icons.receipt_outlined,
                        color: const Color(0xFF8B5CF6),
                        isSelected: selectedMethod == 'slip',
                        onTap: () => setState(() => selectedMethod = 'slip'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Method-specific fields
                if (selectedMethod == 'bank') ...[
                  _buildBankSelector(
                    label: 'From Bank *',
                    selectedBank: selectedFromBank,
                    onTap: () => _openBankPicker(
                      context: context,
                      title: 'Select Source Bank',
                      onSelected: (bank) => setState(() => selectedFromBank = bank),
                      currentSelection: selectedFromBank,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBankSelector(
                    label: 'To Bank *',
                    selectedBank: selectedToBank,
                    onTap: () => _openBankPicker(
                      context: context,
                      title: 'Select Destination Bank',
                      onSelected: (bank) => setState(() => selectedToBank = bank),
                      currentSelection: selectedToBank,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bankDescriptionCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'e.g. Transfer for payment',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ] else if (selectedMethod == 'cheque') ...[
                  _buildBankSelector(
                    label: 'Bank *',
                    selectedBank: selectedChequeBank,
                    onTap: () => _openBankPicker(
                      context: context,
                      title: 'Select Bank',
                      onSelected: (bank) => setState(() => selectedChequeBank = bank),
                      currentSelection: selectedChequeBank,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: chequeNumberCtrl,
                    decoration: InputDecoration(
                      labelText: 'Cheque Number *',
                      hintText: 'e.g. 001234',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: chequeDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 180)),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: const ColorScheme.light(primary: Color(0xFFF59E0B)),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => chequeDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event, size: 18, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 12),
                          Text(
                            chequeDate != null
                                ? 'Cheque Date: ${DateFormat('MMM dd, yyyy').format(chequeDate!)}'
                                : 'Select Cheque Date *',
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (selectedMethod == 'slip') ...[
                  _buildBankSelector(
                    label: 'Bank *',
                    selectedBank: selectedSlipBank,
                    onTap: () => _openBankPicker(
                      context: context,
                      title: 'Select Bank',
                      onSelected: (bank) => setState(() => selectedSlipBank = bank),
                      currentSelection: selectedSlipBank,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: slipNumberCtrl,
                    decoration: InputDecoration(
                      labelText: 'Slip Number *',
                      hintText: 'e.g. SLIP-001',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: slipDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: const ColorScheme.light(primary: Color(0xFF8B5CF6)),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => slipDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event, size: 18, color: Color(0xFF8B5CF6)),
                          const SizedBox(width: 12),
                          Text(
                            slipDate != null
                                ? 'Slip Date: ${DateFormat('MMM dd, yyyy').format(slipDate!)}'
                                : 'Select Slip Date *',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter valid amount'), backgroundColor: Colors.red),
                  );
                  return;
                }
                if (amount > _sale!.outstandingBalance) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Amount cannot exceed outstanding balance'), backgroundColor: Colors.red),
                  );
                  return;
                }

                // Validate method-specific fields
                if (selectedMethod == 'bank') {
                  if (selectedFromBank == null || selectedToBank == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select both source and destination banks'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                } else if (selectedMethod == 'cheque') {
                  if (selectedChequeBank == null || chequeNumberCtrl.text.isEmpty || chequeDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all cheque details'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                } else if (selectedMethod == 'slip') {
                  if (selectedSlipBank == null || slipNumberCtrl.text.isEmpty || slipDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all slip details'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                }

                // Build payment details
                Map<String, dynamic> paymentDetails = {
                  'amount': amount,
                  'method': selectedMethod,
                  'payment_date': paymentDate!.toIso8601String(),
                };

                // Add method-specific details
                if (selectedMethod == 'bank') {
                  paymentDetails['from_bank'] = selectedFromBank?.name;
                  paymentDetails['to_bank'] = selectedToBank?.name;
                  paymentDetails['description'] = bankDescriptionCtrl.text.trim();
                } else if (selectedMethod == 'cheque') {
                  paymentDetails['bank'] = selectedChequeBank?.name;
                  paymentDetails['cheque_number'] = chequeNumberCtrl.text.trim();
                  paymentDetails['cheque_date'] = chequeDate!.toIso8601String();
                } else if (selectedMethod == 'slip') {
                  paymentDetails['bank'] = selectedSlipBank?.name;
                  paymentDetails['slip_number'] = slipNumberCtrl.text.trim();
                  paymentDetails['slip_date'] = slipDate!.toIso8601String();
                }

                Navigator.pop(context, paymentDetails);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final provider = Provider.of<SaleProvider>(context, listen: false);

      // Extract payment details
      final amount = result['amount'];
      final method = result['method'];
      final paymentDate = DateTime.parse(result['payment_date']);

      // Prepare additional parameters based on method
      String? chequeNumber;
      String? bankName;
      DateTime? chequeDate;

      if (method == 'cheque') {
        chequeNumber = result['cheque_number'];
        bankName = result['bank'];
        chequeDate = result['cheque_date'] != null ? DateTime.parse(result['cheque_date']) : null;
      } else if (method == 'slip') {
        bankName = result['bank'];
      }

      final response = await provider.recordPayment(
        widget.saleId,
        amount,
        method,
        paymentDate: paymentDate,
        chequeNumber: chequeNumber,
        bankName: bankName,
        chequeDate: chequeDate,
      );

      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded successfully'), backgroundColor: Colors.green),
        );
        _loadSale(); // Reload sale data
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Failed to record payment'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildMethodChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankSelector({
    required String label,
    required Bank? selectedBank,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93)),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selectedBank != null ? Colors.blue.withOpacity(0.05) : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selectedBank != null ? Colors.blue.withOpacity(0.4) : const Color(0xFFE5E5EA),
              ),
            ),
            child: Row(
              children: [
                if (selectedBank != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      selectedBank.iconPath,
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.account_balance,
                        size: 28,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedBank.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(Icons.check_circle_rounded, color: Colors.blue, size: 18),
                ] else ...[
                  Icon(Icons.account_balance_outlined, size: 20, color: Colors.grey[400]),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Select bank',
                      style: TextStyle(fontSize: 14, color: Color(0xFFC7C7CC)),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey[400]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openBankPicker({
    required BuildContext context,
    required String title,
    required Function(Bank) onSelected,
    Bank? currentSelection,
  }) async {
    final result = await showModalBottomSheet<Bank>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PaymentBankSheet(
        title: title,
        selected: currentSelection,
        accentColor: const Color(0xFF7C3AED),
      ),
    );
    if (result != null) onSelected(result);
  }

  Customer? _toCustomer(CustomerInfo? info) {
    if (info == null) return null;
    return Customer(
      id: info.id,
      name: info.name,
      contact: info.contact ?? '',
      address: info.address,
      email: info.email,
      customerType: info.customerType,
      balance: 0.0,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingIndicator(),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: CustomErrorWidget(
          message: _error!,
          onRetry: _loadSale,
        ),
      );
    }

    if (_sale == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sale Details')),
        body: const Center(child: Text('Sale not found')),
      );
    }

    final bool isCredit = _sale!.paymentMethod == 'credit';
    final bool isOverdue = _sale!.isOverdue;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _sale!.invoiceNumber,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                  ),
                ),
                const SizedBox(width: 8),
                if (isCredit)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'CREDIT',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              _sale!.saleType == 'pos' ? 'POS Counter Sale' : 'Invoice',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          if (_sale!.paymentStatus != 'paid')
            IconButton(
              icon: const Icon(Icons.payment, color: Colors.green),
              onPressed: _recordPayment,
              tooltip: 'Record Payment',
            ),
          // In the AppBar actions section, replace the print IconButton with:
          IconButton(
            icon: const Icon(Icons.print, color: Color(0xFF7C3AED)),
            onPressed: () async {
              if (_sale != null) {
                final items = _sale!.items?.map((item) => {
                  'product_name': item.productName,
                  'quantity': item.quantity,
                  'unit_price': item.unitPrice,
                }).toList() ?? [];

                try {
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );

                  // Generate and print PDF
                  await SalePdfGenerator.generateAndPrintSalePdf(
                    saleData: {'invoice_number': _sale!.invoiceNumber},
                    customer: _toCustomer(_sale!.customer),
                    items: items,
                    subtotal: _sale!.subtotal,
                    discountValue: _sale!.discountAmount,
                    grandTotal: _sale!.grandTotal,
                    isPosMode: _sale!.saleType == 'pos',
                    paymentMethod: _sale!.paymentMethod,
                    amountPaid: _sale!.amountPaid,
                    dueDate: _sale!.dueDate,
                    notes: _sale!.notes,
                  );

                  if (mounted) Navigator.pop(context); // Close loading dialog

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Print dialog opened'),
                      backgroundColor: Color(0xFF7C3AED),
                    ),
                  );
                } catch (e) {
                  if (mounted) Navigator.pop(context); // Close loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to print: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            tooltip: 'Print Receipt/Invoice',
          ),
          if (_sale!.paymentStatus != 'paid')
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _voidSale,
              tooltip: 'Void Sale',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCredit && _sale!.paymentStatus != 'paid'
                    ? const Color(0xFF7C3AED).withOpacity(0.1)
                    : _sale!.statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCredit && _sale!.paymentStatus != 'paid'
                      ? const Color(0xFF7C3AED).withOpacity(0.3)
                      : _sale!.statusColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCredit && _sale!.paymentStatus != 'paid' ? Icons.credit_card :
                    _sale!.paymentStatus == 'paid' ? Icons.check_circle :
                    _sale!.paymentStatus == 'partial' ? Icons.pending : Icons.error,
                    color: isCredit && _sale!.paymentStatus != 'paid'
                        ? const Color(0xFF7C3AED)
                        : _sale!.statusColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCredit && _sale!.paymentStatus != 'paid'
                              ? 'CREDIT SALE'
                              : 'Payment Status: ${_sale!.paymentStatus.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isCredit && _sale!.paymentStatus != 'paid'
                                ? const Color(0xFF7C3AED)
                                : _sale!.statusColor,
                          ),
                        ),
                        if (_sale!.paymentStatus != 'paid')
                          Text(
                            'Outstanding: ${_currencyFormat.format(_sale!.outstandingBalance)}',
                            style: TextStyle(
                              color: isCredit && _sale!.paymentStatus != 'paid'
                                  ? const Color(0xFF7C3AED)
                                  : _sale!.statusColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isOverdue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'OVERDUE',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Customer & Date Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF0F0F5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transaction Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoRow(
                          icon: Icons.person,
                          label: 'Customer',
                          value: _sale!.customer?.name ?? 'Walk-in Customer',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoRow(
                          icon: Icons.phone,
                          label: 'Contact',
                          value: _sale!.customer?.contact ?? 'N/A',
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoRow(
                          icon: Icons.calendar_today,
                          label: 'Sale Date',
                          value: '${_dateFormat.format(_sale!.saleDate)} ${_timeFormat.format(_sale!.saleDate)}',
                        ),
                      ),
                      if (_sale!.dueDate != null)
                        Expanded(
                          child: _buildInfoRow(
                            icon: Icons.event,
                            label: 'Due Date',
                            value: _dateFormat.format(_sale!.dueDate!),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Items Table
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF0F0F5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFF0F0F5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                          child: const Row(
                            children: [
                              Expanded(flex: 3, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(child: Text('Price', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                        // Items
                        ...?_sale!.items?.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: const Color(0xFFF0F0F5))),
                              color: index.isEven ? null : const Color(0xFFF9FAFB),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                      if (item.barcode != null)
                                        Text(item.barcode!, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item.quantity.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _currencyFormat.format(item.unitPrice),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _currencyFormat.format(item.totalPrice),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment Summary
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF0F0F5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Summary',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryRow('Subtotal', _currencyFormat.format(_sale!.subtotal)),
                        if (_sale!.discountAmount > 0)
                          _buildSummaryRow(
                            'Discount (${_sale!.discountType == 'percent' ? '${_sale!.discountValue}%' : 'Fixed'})',
                            '-${_currencyFormat.format(_sale!.discountAmount)}',
                            color: Colors.green,
                          ),
                        _buildSummaryRow('Grand Total', _currencyFormat.format(_sale!.grandTotal), isBold: true),
                        const Divider(height: 24),
                        _buildSummaryRow('Amount Paid', _currencyFormat.format(_sale!.amountPaid)),
                        _buildSummaryRow('Change', _currencyFormat.format(_sale!.changeAmount), color: Colors.green),
                        if (_sale!.paymentStatus != 'paid')
                          _buildSummaryRow(
                            'Outstanding',
                            _currencyFormat.format(_sale!.outstandingBalance),
                            color: isCredit ? const Color(0xFF7C3AED) : Colors.red,
                            isBold: true,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF0F0F5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Info',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoChip(
                          label: 'Method',
                          value: _sale!.paymentMethod.toUpperCase(),
                          color: isCredit ? const Color(0xFF7C3AED) : Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoChip(
                          label: 'Status',
                          value: _sale!.paymentStatus.toUpperCase(),
                          color: _sale!.statusColor,
                        ),
                        if (isCredit) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Credit Details',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            icon: Icons.event,
                            label: 'Due Date',
                            value: _sale!.dueDate != null
                                ? _dateFormat.format(_sale!.dueDate!)
                                : 'Not specified',
                          ),
                          if (_sale!.outstandingBalance > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isOverdue ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isOverdue ? Icons.warning : Icons.info,
                                      size: 16,
                                      color: isOverdue ? Colors.red : Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isOverdue
                                            ? 'Payment is overdue!'
                                            : 'Payment pending',
                                        style: TextStyle(
                                          color: isOverdue ? Colors.red : Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                        if (_sale!.notes != null && _sale!.notes!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(_sale!.notes!, style: TextStyle(color: Colors.grey[600])),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _sale!.paymentStatus != 'paid' && _sale!.saleType == 'invoice'
          ? Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _recordPayment,
                icon: const Icon(Icons.payment),
                label: const Text('Record Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCredit ? const Color(0xFF7C3AED) : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      )
          : null,
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? (isBold ? const Color(0xFF2D3142) : Colors.grey[600]),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 16 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? (isBold ? const Color(0xFF7C3AED) : const Color(0xFF2D3142)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(color: color.withOpacity(0.7), fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  BANK SHEET FOR PAYMENT DIALOG
// ═════════════════════════════════════════════════════════════════

class _PaymentBankSheet extends StatefulWidget {
  final String title;
  final Bank? selected;
  final Color accentColor;

  const _PaymentBankSheet({
    required this.title,
    required this.selected,
    required this.accentColor,
  });

  @override
  State<_PaymentBankSheet> createState() => _PaymentBankSheetState();
}

class _PaymentBankSheetState extends State<_PaymentBankSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Bank> _filteredBanks = pakistaniBanks;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filterBanks);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filterBanks() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredBanks = pakistaniBanks
          .where((bank) => bank.name.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              Text(
                widget.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search banks...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F5F7),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredBanks.length,
              itemBuilder: (context, index) {
                final bank = _filteredBanks[index];
                final isSelected = widget.selected?.name == bank.name;

                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      bank.iconPath,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: widget.accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.account_balance,
                          color: widget.accentColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    bank.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? widget.accentColor : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: widget.accentColor)
                      : null,
                  onTap: () => Navigator.pop(context, bank),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}