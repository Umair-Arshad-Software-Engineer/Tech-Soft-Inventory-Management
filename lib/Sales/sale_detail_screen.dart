import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:tech_soft/Sales/salereturn.dart' show SaleReturnDialog;
import '../../providers/sale_provider.dart';
import '../../models/sale_model.dart';
import '../components/loading_indicator.dart';
import '../components/error_widget.dart';
import '../Banks/banknames.dart';
import '../models/customer.dart';
import '../services/sale_pdf_generator.dart';

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

      // Debug: Check if returns were loaded
      debugPrint('Sale loaded - returns count: ${sale?.returns?.length}');
      debugPrint('Sale loaded - returnStatus: ${sale?.returnStatus}');
      debugPrint('Sale loaded - returnAmount: ${sale?.returnAmount}');

      // If returns are still null, try fetching them separately
      if (sale != null && (sale.returns == null || sale.returns!.isEmpty)) {
        debugPrint('Returns not loaded with sale, fetching separately...');
        final returns = await provider.getSaleReturns(widget.saleId);
        if (returns.isNotEmpty) {
          // Since properties are no longer final, we can assign directly
          sale.returns = returns;

          // Calculate total return amount
          double totalReturnAmount = 0;
          for (var ret in returns) {
            totalReturnAmount += double.tryParse(ret['refund_amount']?.toString() ?? '0') ?? 0;
          }
          sale.returnAmount = totalReturnAmount;

          // Determine return status
          if (totalReturnAmount >= sale.grandTotal) {
            sale.returnStatus = 'fully_returned';
          } else if (totalReturnAmount > 0) {
            sale.returnStatus = 'partial_return';
          }

          debugPrint('Manually set returns: ${sale.returns?.length} items, amount: ${sale.returnAmount}, status: ${sale.returnStatus}');
        }
      }

      setState(() {
        _sale = sale;
        _isLoading = false;
      });

      debugPrint('Final returns count: ${_sale?.returns?.length}');
      debugPrint('Final returns data: ${_sale?.returns}');
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
        content: Text(
            'Are you sure you want to void ${_sale!.invoiceNumber}? This will restore stock and reverse ledger entries.'),
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
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message'] ?? 'Failed to void sale'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _recordPayment() async {
    if (_sale == null) return;

    final amountController = TextEditingController(
        text: _sale!.outstandingBalance.toStringAsFixed(2));
    String selectedMethod = 'cash';

    Bank? selectedFromBank;
    Bank? selectedToBank;
    final bankDescriptionCtrl = TextEditingController();

    final chequeNumberCtrl = TextEditingController();
    DateTime? chequeDate;
    Bank? selectedChequeBank;

    final slipNumberCtrl = TextEditingController();
    DateTime? slipDate;
    Bank? selectedSlipBank;

    DateTime? paymentDate = DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Record Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Payment Amount',
                    prefixText: 'Rs ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: paymentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.light(
                              primary: Color(0xFF7C3AED)),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setState(() => paymentDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 18, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 12),
                        Text(
                            'Payment Date: ${DateFormat('MMM dd, yyyy').format(paymentDate!)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Payment Method',
                    style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMethodChip(
                          label: 'Cash',
                          icon: Icons.payments_outlined,
                          color: const Color(0xFF10B981),
                          isSelected: selectedMethod == 'cash',
                          onTap: () =>
                              setState(() => selectedMethod = 'cash')),
                      const SizedBox(width: 8),
                      _buildMethodChip(
                          label: 'Bank',
                          icon: Icons.account_balance_outlined,
                          color: const Color(0xFF3B82F6),
                          isSelected: selectedMethod == 'bank',
                          onTap: () =>
                              setState(() => selectedMethod = 'bank')),
                      const SizedBox(width: 8),
                      _buildMethodChip(
                          label: 'Cheque',
                          icon: Icons.receipt_long_outlined,
                          color: const Color(0xFFF59E0B),
                          isSelected: selectedMethod == 'cheque',
                          onTap: () =>
                              setState(() => selectedMethod = 'cheque')),
                      const SizedBox(width: 8),
                      _buildMethodChip(
                          label: 'Slip',
                          icon: Icons.receipt_outlined,
                          color: const Color(0xFF8B5CF6),
                          isSelected: selectedMethod == 'slip',
                          onTap: () =>
                              setState(() => selectedMethod = 'slip')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (selectedMethod == 'bank') ...[
                  _buildBankSelector(
                    label: 'From Bank *',
                    selectedBank: selectedFromBank,
                    onTap: () => _openBankPicker(
                      context: context,
                      title: 'Select Source Bank',
                      onSelected: (bank) =>
                          setState(() => selectedFromBank = bank),
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
                      onSelected: (bank) =>
                          setState(() => selectedToBank = bank),
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ] else if (selectedMethod == 'cheque') ...[
                  _buildBankSelector(
                    label: 'Bank *',
                    selectedBank: selectedChequeBank,
                    onTap: () => _openBankPicker(
                      context: context,
                      title: 'Select Bank',
                      onSelected: (bank) =>
                          setState(() => selectedChequeBank = bank),
                      currentSelection: selectedChequeBank,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: chequeNumberCtrl,
                    decoration: InputDecoration(
                      labelText: 'Cheque Number *',
                      hintText: 'e.g. 001234',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: chequeDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate:
                        DateTime.now().add(const Duration(days: 180)),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: const ColorScheme.light(
                                primary: Color(0xFFF59E0B)),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setState(() => chequeDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event,
                              size: 18, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 12),
                          Text(chequeDate != null
                              ? 'Cheque Date: ${DateFormat('MMM dd, yyyy').format(chequeDate!)}'
                              : 'Select Cheque Date *'),
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
                      onSelected: (bank) =>
                          setState(() => selectedSlipBank = bank),
                      currentSelection: selectedSlipBank,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: slipNumberCtrl,
                    decoration: InputDecoration(
                      labelText: 'Slip Number *',
                      hintText: 'e.g. SLIP-001',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: slipDate ?? DateTime.now(),
                        firstDate:
                        DateTime.now().subtract(const Duration(days: 30)),
                        lastDate:
                        DateTime.now().add(const Duration(days: 30)),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: const ColorScheme.light(
                                primary: Color(0xFF8B5CF6)),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setState(() => slipDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event,
                              size: 18, color: Color(0xFF8B5CF6)),
                          const SizedBox(width: 12),
                          Text(slipDate != null
                              ? 'Slip Date: ${DateFormat('MMM dd, yyyy').format(slipDate!)}'
                              : 'Select Slip Date *'),
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Enter valid amount'),
                      backgroundColor: Colors.red));
                  return;
                }
                if (amount > _sale!.outstandingBalance) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                      Text('Amount cannot exceed outstanding balance'),
                      backgroundColor: Colors.red));
                  return;
                }
                if (selectedMethod == 'bank') {
                  if (selectedFromBank == null || selectedToBank == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Please select both source and destination banks'),
                        backgroundColor: Colors.red));
                    return;
                  }
                } else if (selectedMethod == 'cheque') {
                  if (selectedChequeBank == null ||
                      chequeNumberCtrl.text.isEmpty ||
                      chequeDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Please fill all cheque details'),
                        backgroundColor: Colors.red));
                    return;
                  }
                } else if (selectedMethod == 'slip') {
                  if (selectedSlipBank == null ||
                      slipNumberCtrl.text.isEmpty ||
                      slipDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Please fill all slip details'),
                        backgroundColor: Colors.red));
                    return;
                  }
                }

                Map<String, dynamic> paymentDetails = {
                  'amount': amount,
                  'method': selectedMethod,
                  'payment_date': paymentDate!.toIso8601String(),
                };
                if (selectedMethod == 'bank') {
                  paymentDetails['from_bank'] = selectedFromBank?.name;
                  paymentDetails['to_bank'] = selectedToBank?.name;
                  paymentDetails['description'] =
                      bankDescriptionCtrl.text.trim();
                } else if (selectedMethod == 'cheque') {
                  paymentDetails['bank'] = selectedChequeBank?.name;
                  paymentDetails['cheque_number'] =
                      chequeNumberCtrl.text.trim();
                  paymentDetails['cheque_date'] =
                      chequeDate!.toIso8601String();
                } else if (selectedMethod == 'slip') {
                  paymentDetails['bank'] = selectedSlipBank?.name;
                  paymentDetails['slip_number'] = slipNumberCtrl.text.trim();
                  paymentDetails['slip_date'] = slipDate!.toIso8601String();
                }
                Navigator.pop(context, paymentDetails);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final provider = Provider.of<SaleProvider>(context, listen: false);
      final amount = result['amount'];
      final method = result['method'];
      final paymentDate = DateTime.parse(result['payment_date']);

      String? chequeNumber;
      String? bankName;
      DateTime? chequeDate;

      if (method == 'cheque') {
        chequeNumber = result['cheque_number'];
        bankName = result['bank'];
        chequeDate = result['cheque_date'] != null
            ? DateTime.parse(result['cheque_date'])
            : null;
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Payment recorded successfully'),
            backgroundColor: Colors.green));
        _loadSale();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
            Text(response['message'] ?? 'Failed to record payment'),
            backgroundColor: Colors.red));
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
            Icon(icon,
                size: 16, color: isSelected ? color : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey.shade700,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBankSelector(
      {required String label,
        required Bank? selectedBank,
        required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E8E93))),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selectedBank != null
                  ? Colors.blue.withOpacity(0.05)
                  : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selectedBank != null
                    ? Colors.blue.withOpacity(0.4)
                    : const Color(0xFFE5E5EA),
              ),
            ),
            child: Row(
              children: [
                if (selectedBank != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(selectedBank.iconPath,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.account_balance,
                            size: 28,
                            color: Colors.blue)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(selectedBank.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500))),
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.blue, size: 18),
                ] else ...[
                  Icon(Icons.account_balance_outlined,
                      size: 20, color: Colors.grey[400]),
                  const SizedBox(width: 10),
                  const Expanded(
                      child: Text('Select bank',
                          style: TextStyle(
                              fontSize: 14, color: Color(0xFFC7C7CC)))),
                  Icon(Icons.keyboard_arrow_down,
                      size: 20, color: Colors.grey[400]),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PaymentBankSheet(
          title: title,
          selected: currentSelection,
          accentColor: const Color(0xFF7C3AED)),
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

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: LoadingIndicator());
    if (_error != null) {
      return Scaffold(
          body: CustomErrorWidget(message: _error!, onRetry: _loadSale));
    }
    if (_sale == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Sale Details')),
          body: const Center(child: Text('Sale not found')));
    }

    final bool isCredit = _sale!.paymentMethod == 'credit';
    final bool isOverdue = _sale!.isOverdue;
    final bool hasReturns =
        _sale!.returns != null && _sale!.returns!.isNotEmpty;

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
                Text(_sale!.invoiceNumber,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142))),
                const SizedBox(width: 8),
                if (isCredit)
                  _appBarBadge('CREDIT', const Color(0xFF7C3AED)),
                if (hasReturns)
                  _appBarBadge(
                    _sale!.returnStatus == 'fully_returned'
                        ? 'RETURNED'
                        : 'PARTIAL RTN',
                    Colors.orange,
                    icon: Icons.assignment_return,
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
          IconButton(
            icon: const Icon(Icons.print, color: Color(0xFF7C3AED)),
            onPressed: () async {
              if (_sale != null) {
                final items = _sale!.items
                    ?.map((item) => {
                  'product_name': item.productName,
                  'quantity': item.quantity,
                  'unit_price': item.unitPrice,
                })
                    .toList() ??
                    [];
                try {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
                  );
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
                  if (mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Print dialog opened'),
                      backgroundColor: Color(0xFF7C3AED)));
                } catch (e) {
                  if (mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Failed to print: $e'),
                      backgroundColor: Colors.red));
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
          IconButton(
            icon: const Icon(Icons.assignment_return, color: Colors.orange),
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (_) => SaleReturnDialog(sale: _sale!),
              );
              if (result == true) _loadSale();
            },
            tooltip: 'Process Return',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status / Return Banner ──────────────────────────
            _buildStatusBanner(isCredit, isOverdue, hasReturns),
            const SizedBox(height: 24),

            // ── Transaction Details ─────────────────────────────
            _buildTransactionDetails(),
            const SizedBox(height: 24),

            // ── Items Table ─────────────────────────────────────
            _buildItemsTable(),
            const SizedBox(height: 24),

            // ── Payment Summary + Info ──────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildPaymentSummary(isCredit)),
                const SizedBox(width: 24),
                Expanded(child: _buildPaymentInfo(isCredit, isOverdue)),
              ],
            ),

            // ── Return History ──────────────────────────────────
            // Always shown when returns exist, regardless of payment status
            if (hasReturns) ...[
              const SizedBox(height: 24),
              _buildReturnHistorySection(),
            ],
          ],
        ),
      ),
      bottomNavigationBar:
      _sale!.paymentStatus != 'paid' && _sale!.saleType == 'invoice'
          ? Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5))
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
                  backgroundColor: isCredit
                      ? const Color(0xFF7C3AED)
                      : Colors.green,
                  padding:
                  const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      )
          : null,
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  STATUS BANNER — now also shows return summary inline
  // ─────────────────────────────────────────────────────────────
  Widget _buildStatusBanner(
      bool isCredit, bool isOverdue, bool hasReturns) {
    // When fully returned, show an orange return banner instead of/alongside payment banner
    if (hasReturns && _sale!.returnStatus == 'fully_returned') {
      return Column(
        children: [
          // Return banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.assignment_return,
                      color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FULLY RETURNED',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                      Text(
                        'Total refunded: ${_currencyFormat.format(_sale!.returnAmount ?? 0)}  •  ${_sale!.returns!.length} return${_sale!.returns!.length > 1 ? 's' : ''}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Payment status banner still shown below
          _buildPaymentBanner(isCredit, isOverdue),
        ],
      );
    }

    // Partial return — show a slim orange strip above the payment banner
    if (hasReturns && _sale!.returnStatus == 'partial_return') {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_return,
                    color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Partial return processed — ${_currencyFormat.format(_sale!.returnAmount ?? 0)} refunded',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildPaymentBanner(isCredit, isOverdue),
        ],
      );
    }

    return _buildPaymentBanner(isCredit, isOverdue);
  }

  Widget _buildPaymentBanner(bool isCredit, bool isOverdue) {
    return Container(
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
            isCredit && _sale!.paymentStatus != 'paid'
                ? Icons.credit_card
                : _sale!.paymentStatus == 'paid'
                ? Icons.check_circle
                : _sale!.paymentStatus == 'partial'
                ? Icons.pending
                : Icons.error,
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
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('OVERDUE',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  TRANSACTION DETAILS
  // ─────────────────────────────────────────────────────────────
  Widget _buildTransactionDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Transaction Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildInfoRow(
                      icon: Icons.person,
                      label: 'Customer',
                      value:
                      _sale!.customer?.name ?? 'Walk-in Customer')),
              Expanded(
                  child: _buildInfoRow(
                      icon: Icons.phone,
                      label: 'Contact',
                      value: _sale!.customer?.contact ?? 'N/A')),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                  child: _buildInfoRow(
                      icon: Icons.calendar_today,
                      label: 'Sale Date',
                      value:
                      '${_dateFormat.format(_sale!.saleDate)} ${_timeFormat.format(_sale!.saleDate)}')),
              if (_sale!.dueDate != null)
                Expanded(
                    child: _buildInfoRow(
                        icon: Icons.event,
                        label: 'Due Date',
                        value: _dateFormat.format(_sale!.dueDate!))),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  ITEMS TABLE
  // ─────────────────────────────────────────────────────────────
  Widget _buildItemsTable() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Items',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFF0F0F5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9FAFB),
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text('Product',
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(
                          child: Text('Qty',
                              textAlign: TextAlign.center,
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(
                          child: Text('Price',
                              textAlign: TextAlign.right,
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(
                          child: Text('Total',
                              textAlign: TextAlign.right,
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                ...?_sale!.items?.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: const Border(
                          top: BorderSide(color: Color(0xFFF0F0F5))),
                      color: index.isEven ? null : const Color(0xFFF9FAFB),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.productName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              if (item.barcode != null)
                                Text(item.barcode!,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        Expanded(
                            child: Text(item.quantity.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500))),
                        Expanded(
                            child: Text(
                                _currencyFormat.format(item.unitPrice),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500))),
                        Expanded(
                            child: Text(
                                _currencyFormat.format(item.totalPrice),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7C3AED)))),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  PAYMENT SUMMARY
  // ─────────────────────────────────────────────────────────────
  Widget _buildPaymentSummary(bool isCredit) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildSummaryRow('Subtotal',
              _currencyFormat.format(_sale!.subtotal)),
          if (_sale!.discountAmount > 0)
            _buildSummaryRow(
              'Discount (${_sale!.discountType == 'percent' ? '${_sale!.discountValue}%' : 'Fixed'})',
              '-${_currencyFormat.format(_sale!.discountAmount)}',
              color: Colors.green,
            ),
          _buildSummaryRow(
              'Grand Total', _currencyFormat.format(_sale!.grandTotal),
              isBold: true),
          const Divider(height: 24),
          _buildSummaryRow('Amount Paid',
              _currencyFormat.format(_sale!.amountPaid)),
          _buildSummaryRow(
              'Change', _currencyFormat.format(_sale!.changeAmount),
              color: Colors.green),
          if (_sale!.paymentStatus != 'paid')
            _buildSummaryRow(
              'Outstanding',
              _currencyFormat.format(_sale!.outstandingBalance),
              color: isCredit ? const Color(0xFF7C3AED) : Colors.red,
              isBold: true,
            ),
          // Show return amount if any
          if ((_sale!.returnAmount ?? 0) > 0) ...[
            const Divider(height: 24),
            _buildSummaryRow(
              'Total Returned',
              _currencyFormat.format(_sale!.returnAmount ?? 0),
              color: Colors.orange,
              isBold: true,
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  PAYMENT INFO
  // ─────────────────────────────────────────────────────────────
  Widget _buildPaymentInfo(bool isCredit, bool isOverdue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Info',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildInfoChip(
              label: 'Method',
              value: _sale!.paymentMethod.toUpperCase(),
              color: isCredit ? const Color(0xFF7C3AED) : Colors.blue),
          const SizedBox(height: 12),
          _buildInfoChip(
              label: 'Status',
              value: _sale!.paymentStatus.toUpperCase(),
              color: _sale!.statusColor),
          if (_sale!.returnStatus != null) ...[
            const SizedBox(height: 12),
            _buildInfoChip(
              label: 'Returns',
              value: _sale!.returnStatus!
                  .replaceAll('_', ' ')
                  .toUpperCase(),
              color: Colors.orange,
            ),
          ],
          if (isCredit) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Credit Details',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildInfoRow(
                icon: Icons.event,
                label: 'Due Date',
                value: _sale!.dueDate != null
                    ? _dateFormat.format(_sale!.dueDate!)
                    : 'Not specified'),
            if (_sale!.outstandingBalance > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? Colors.red.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(isOverdue ? Icons.warning : Icons.info,
                          size: 16,
                          color: isOverdue ? Colors.red : Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              isOverdue
                                  ? 'Payment is overdue!'
                                  : 'Payment pending',
                              style: TextStyle(
                                  color: isOverdue
                                      ? Colors.red
                                      : Colors.orange,
                                  fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              ),
          ],
          if (_sale!.notes != null && _sale!.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Notes',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(_sale!.notes!,
                style: TextStyle(color: Colors.grey[600])),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  RETURN HISTORY SECTION
  // ─────────────────────────────────────────────────────────────
  Widget _buildReturnHistorySection() {
    final returns = _sale!.returns!;
    final totalRefunded = returns.fold<double>(
      0,
          (sum, r) =>
      sum +
          (double.tryParse(r['refund_amount']?.toString() ?? '0') ?? 0),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.assignment_return,
                    color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Return History',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${returns.length} return${returns.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                    child: _buildReturnSummaryChip(
                        label: 'Total Refunded',
                        value: _currencyFormat.format(totalRefunded),
                        icon: Icons.currency_exchange)),
                Container(
                    width: 1,
                    height: 36,
                    color: Colors.orange.withOpacity(0.2)),
                Expanded(
                    child: _buildReturnSummaryChip(
                        label: 'Return Status',
                        value: (_sale!.returnStatus ?? 'N/A')
                            .replaceAll('_', ' ')
                            .toUpperCase(),
                        icon: Icons.info_outline)),
              ],
            ),
          ),

          const SizedBox(height: 16),
          ...returns.asMap().entries.map(
                  (entry) => _buildReturnCard(entry.value, entry.key + 1)),
        ],
      ),
    );
  }

  Widget _buildReturnSummaryChip(
      {required String label,
        required String value,
        required IconData icon}) {
    return Column(
      children: [
        Icon(icon, size: 14, color: Colors.orange.withOpacity(0.7)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: Colors.orange.withOpacity(0.7))),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.orange)),
      ],
    );
  }

  Widget _buildReturnCard(dynamic r, int index) {
    final refundAmount =
        double.tryParse(r['refund_amount']?.toString() ?? '0') ?? 0;
    final returnDate = r['return_date'] != null
        ? _dateFormat.format(DateTime.parse(r['return_date']))
        : '—';
    final returnType = (r['return_type'] ?? '').toString();
    final refundMethod = (r['refund_method'] ?? '').toString();
    final adjustmentType = (r['adjustment_type'] ?? '').toString();
    final status = (r['status'] ?? 'completed').toString();
    final reason = r['reason']?.toString();
    final notes = r['notes']?.toString();
    final returnNumber =
        r['return_number']?.toString() ?? 'RET-#$index';

    // Parse items safely
    final List items = (r['items'] as List?)
        ?.map((e) => e is Map ? Map<String, dynamic>.from(e) : e)
        .toList() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.orange.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(returnNumber,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: returnType == 'full'
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              returnType == 'full' ? 'FULL' : 'PARTIAL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: returnType == 'full' ? Colors.red : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 11, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(returnDate,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Text('REFUND',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600)),
                      Text(
                        _currencyFormat.format(refundAmount),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Badges
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _returnBadge(
                    returnType == 'full'
                        ? 'Full return'
                        : 'Partial return',
                    returnType == 'full' ? Colors.red : Colors.orange),
                _returnBadge(_methodLabel(refundMethod), Colors.blue),
                _returnBadge(
                    adjustmentType == 'refund'
                        ? 'Cash refund'
                        : 'Balance reduced',
                    Colors.purple),
                _returnBadge(status, Colors.green),
              ],
            ),
          ),

          // Items Section - IMPROVED DETAILS
          if (items.isNotEmpty) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F0),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Items header
                  Row(
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Returned Items (${items.length})',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Items list with detailed info
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = Map<String, dynamic>.from(entry.value);
                    final qty = (item['quantity_returned'] ?? 0).toInt();
                    final name = item['product_name']?.toString() ?? '—';
                    final unitPrice = double.tryParse(
                        item['refund_unit_price']?.toString() ?? '0') ?? 0;
                    final originalPrice = double.tryParse(
                        item['original_unit_price']?.toString() ?? '0') ?? 0;
                    final total = double.tryParse(
                        item['total_refund']?.toString() ?? '0') ?? 0;
                    final condition = item['condition']?.toString() ?? 'sellable';
                    final itemReason = item['reason']?.toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product name and condition
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              _conditionBadge(condition),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Quantity and price row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Quantity',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600])),
                                    const SizedBox(height: 2),
                                    Text('× $qty',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Unit Price',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600])),
                                    const SizedBox(height: 2),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_currencyFormat.format(unitPrice),
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500)),
                                        if (originalPrice != unitPrice)
                                          Text(
                                            'Original: ${_currencyFormat.format(originalPrice)}',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[500],
                                                decoration: TextDecoration.lineThrough),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Total Refund',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600])),
                                    const SizedBox(height: 2),
                                    Text(_currencyFormat.format(total),
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange)),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Item reason if provided
                          if (itemReason != null && itemReason.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.comment_outlined,
                                      size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      itemReason,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[700]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // Reason / notes
          if ((reason != null && reason.isNotEmpty) ||
              (notes != null && notes.isNotEmpty)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (reason != null && reason.isNotEmpty)
                    _infoLine(Icons.comment_outlined, 'Return Reason', reason),
                  if (notes != null && notes.isNotEmpty)
                    _infoLine(Icons.note_outlined, 'Additional Notes', notes),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  SMALL HELPERS
  // ─────────────────────────────────────────────────────────────
  Widget _appBarBadge(String label, Color color, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
        ],
      ),
    );
  }

  Widget _returnBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }

  Widget _conditionBadge(String condition) {
    final Map<String, Map<String, dynamic>> conditionStyles = {
      'sellable': {
        'label': 'Sellable',
        'color': Colors.green,
        'icon': Icons.check_circle_outline,
      },
      'damaged': {
        'label': 'Damaged',
        'color': Colors.red,
        'icon': Icons.warning_amber_outlined,
      },
      'defective': {
        'label': 'Defective',
        'color': Colors.orange,
        'icon': Icons.error_outline,
      },
    };

    final style = conditionStyles[condition.toLowerCase()] ?? {
      'label': condition,
      'color': Colors.grey,
      'icon': Icons.help_outline,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (style['color'] as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: (style['color'] as Color).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style['icon'] as IconData,
              size: 12, color: style['color'] as Color),
          const SizedBox(width: 4),
          Text(style['label'] as String,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: style['color'] as Color)),
        ],
      ),
    );
  }

  Widget _infoLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: Colors.grey[400]),
          const SizedBox(width: 6),
          Text('$label: ',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600)),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[700]))),
        ],
      ),
    );
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

  Widget _buildInfoRow(
      {required IconData icon,
        required String label,
        required String value}) {
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
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[600])),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: isBold ? 14 : 13,
                fontWeight:
                isBold ? FontWeight.bold : FontWeight.normal,
                color: color ??
                    (isBold
                        ? const Color(0xFF2D3142)
                        : Colors.grey[600]),
              )),
          Text(value,
              style: TextStyle(
                fontSize: isBold ? 16 : 13,
                fontWeight:
                isBold ? FontWeight.bold : FontWeight.w600,
                color: color ??
                    (isBold
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF2D3142)),
              )),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
      {required String label,
        required String value,
        required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text('$label: ',
              style: TextStyle(
                  color: color.withOpacity(0.7), fontSize: 13)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  BANK SHEET
// ═══════════════════════════════════════════════════════════════
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
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
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
                  borderSide: BorderSide.none),
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
                    child: Image.asset(bank.iconPath,
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: widget.accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.account_balance,
                                color: widget.accentColor, size: 20))),
                  ),
                  title: Text(bank.name,
                      style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? widget.accentColor : null)),
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