// lib/screens/customers/customer_payment_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../config/api_config.dart';
import '../../models/customer.dart';
import '../../providers/auth_provider.dart';
import '../Banks/banknames.dart';

class CustomerPaymentDialog extends StatefulWidget {
  final Customer customer;

  const CustomerPaymentDialog({super.key, required this.customer});

  @override
  State<CustomerPaymentDialog> createState() => _CustomerPaymentDialogState();
}

class _CustomerPaymentDialogState extends State<CustomerPaymentDialog> {
  final _amountController = TextEditingController();
  String _selectedMethod = 'cash';
  DateTime _paymentDate = DateTime.now();

  // Bank transfer fields
  Bank? _selectedFromBank;
  Bank? _selectedToBank;
  final _bankDescriptionCtrl = TextEditingController();

  // Cheque fields
  final _chequeNumberCtrl = TextEditingController();
  DateTime? _chequeDate;
  Bank? _selectedChequeBank;

  // Slip fields
  final _slipNumberCtrl = TextEditingController();
  DateTime? _slipDate;
  Bank? _selectedSlipBank;

  bool _isLoading = false;

  final _currencyFormat = NumberFormat('#,##0.00');
  final _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  void dispose() {
    _amountController.dispose();
    _bankDescriptionCtrl.dispose();
    _chequeNumberCtrl.dispose();
    _slipNumberCtrl.dispose();
    super.dispose();
  }

  String? _getToken() {
    try {
      return Provider.of<AuthProvider>(context, listen: false).user?.token;
    } catch (_) {
      return null;
    }
  }

  Future<void> _submitPayment() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid amount'), backgroundColor: Colors.red),
      );
      return;
    }

    // Validate method-specific fields
    if (_selectedMethod == 'bank') {
      if (_selectedFromBank == null || _selectedToBank == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select both source and destination banks'), backgroundColor: Colors.red),
        );
        return;
      }
    } else if (_selectedMethod == 'cheque') {
      if (_selectedChequeBank == null || _chequeNumberCtrl.text.isEmpty || _chequeDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all cheque details'), backgroundColor: Colors.red),
        );
        return;
      }
    } else if (_selectedMethod == 'slip') {
      if (_selectedSlipBank == null || _slipNumberCtrl.text.isEmpty || _slipDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all slip details'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // Build payment details
      Map<String, dynamic> paymentData = {
        'amount': amount,
        'payment_method': _selectedMethod,
        'payment_date': DateFormat('yyyy-MM-dd').format(_paymentDate),
      };

      // Add method-specific details
      if (_selectedMethod == 'bank') {
        paymentData['from_bank'] = _selectedFromBank?.name;
        paymentData['to_bank'] = _selectedToBank?.name;
        paymentData['description'] = _bankDescriptionCtrl.text.trim();
      } else if (_selectedMethod == 'cheque') {
        paymentData['bank'] = _selectedChequeBank?.name;
        paymentData['cheque_number'] = _chequeNumberCtrl.text.trim();
        paymentData['cheque_date'] = DateFormat('yyyy-MM-dd').format(_chequeDate!);
      } else if (_selectedMethod == 'slip') {
        paymentData['bank'] = _selectedSlipBank?.name;
        paymentData['slip_number'] = _slipNumberCtrl.text.trim();
        paymentData['slip_date'] = DateFormat('yyyy-MM-dd').format(_slipDate!);
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/customers/${widget.customer.id}/payments'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
        },
        body: json.encode(paymentData),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) {
          Navigator.pop(context, true);
        } else {
          _showError(data['message'] ?? 'Failed to record payment');
        }
      } else {
        _showError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print(e);
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _openBankPicker({
    required BuildContext context,
    required String title,
    required Function(Bank) onSelected,
    Bank? currentSelection,
    Color accentColor = const Color(0xFF7C3AED),
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
        accentColor: accentColor,
      ),
    );
    if (result != null) onSelected(result);
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
    Color? accentColor,
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
                        color: accentColor ?? Colors.blue,
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
                  Icon(Icons.check_circle_rounded, color: accentColor ?? Colors.blue, size: 18),
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

  @override
  Widget build(BuildContext context) {
    final outstandingBalance = widget.customer.balance;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.payments_outlined,
                      color: Color(0xFF7C3AED),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Record Payment',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.customer.name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Outstanding Balance
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: outstandingBalance > 0
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: outstandingBalance > 0
                        ? const Color(0xFFEF4444).withOpacity(0.3)
                        : const Color(0xFF10B981).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Outstanding Balance',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Rs ${_currencyFormat.format(outstandingBalance)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: outstandingBalance > 0
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Amount Field
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Payment Amount *',
                  prefixText: 'Rs ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Payment Date
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _paymentDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Color(0xFF7C3AED),
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setState(() => _paymentDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 10),
                      Text(
                        'Payment Date: ${_dateFormat.format(_paymentDate)}',
                        style: const TextStyle(fontSize: 14),
                      ),
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
                      isSelected: _selectedMethod == 'cash',
                      onTap: () => setState(() => _selectedMethod = 'cash'),
                    ),
                    const SizedBox(width: 8),
                    _buildMethodChip(
                      label: 'Bank',
                      icon: Icons.account_balance_outlined,
                      color: const Color(0xFF3B82F6),
                      isSelected: _selectedMethod == 'bank',
                      onTap: () => setState(() => _selectedMethod = 'bank'),
                    ),
                    const SizedBox(width: 8),
                    _buildMethodChip(
                      label: 'Cheque',
                      icon: Icons.receipt_long_outlined,
                      color: const Color(0xFFF59E0B),
                      isSelected: _selectedMethod == 'cheque',
                      onTap: () => setState(() => _selectedMethod = 'cheque'),
                    ),
                    const SizedBox(width: 8),
                    _buildMethodChip(
                      label: 'Slip',
                      icon: Icons.receipt_outlined,
                      color: const Color(0xFF8B5CF6),
                      isSelected: _selectedMethod == 'slip',
                      onTap: () => setState(() => _selectedMethod = 'slip'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Method-specific fields
              if (_selectedMethod == 'bank') ...[
                _buildBankSelector(
                  label: 'From Bank *',
                  selectedBank: _selectedFromBank,
                  onTap: () => _openBankPicker(
                    context: context,
                    title: 'Select Source Bank',
                    onSelected: (bank) => setState(() => _selectedFromBank = bank),
                    currentSelection: _selectedFromBank,
                    accentColor: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(height: 12),
                _buildBankSelector(
                  label: 'To Bank *',
                  selectedBank: _selectedToBank,
                  onTap: () => _openBankPicker(
                    context: context,
                    title: 'Select Destination Bank',
                    onSelected: (bank) => setState(() => _selectedToBank = bank),
                    currentSelection: _selectedToBank,
                    accentColor: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bankDescriptionCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'e.g. Transfer for payment',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                    ),
                  ),
                ),
              ] else if (_selectedMethod == 'cheque') ...[
                _buildBankSelector(
                  label: 'Bank *',
                  selectedBank: _selectedChequeBank,
                  onTap: () => _openBankPicker(
                    context: context,
                    title: 'Select Bank',
                    onSelected: (bank) => setState(() => _selectedChequeBank = bank),
                    currentSelection: _selectedChequeBank,
                    accentColor: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _chequeNumberCtrl,
                  decoration: InputDecoration(
                    labelText: 'Cheque Number *',
                    hintText: 'e.g. 001234',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _chequeDate ?? DateTime.now(),
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
                      setState(() => _chequeDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event, size: 18, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 12),
                        Text(
                          _chequeDate != null
                              ? 'Cheque Date: ${_dateFormat.format(_chequeDate!)}'
                              : 'Select Cheque Date *',
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (_selectedMethod == 'slip') ...[
                _buildBankSelector(
                  label: 'Bank *',
                  selectedBank: _selectedSlipBank,
                  onTap: () => _openBankPicker(
                    context: context,
                    title: 'Select Bank',
                    onSelected: (bank) => setState(() => _selectedSlipBank = bank),
                    currentSelection: _selectedSlipBank,
                    accentColor: const Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _slipNumberCtrl,
                  decoration: InputDecoration(
                    labelText: 'Slip Number *',
                    hintText: 'e.g. SLIP-001',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _slipDate ?? DateTime.now(),
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
                      setState(() => _slipDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event, size: 18, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 12),
                        Text(
                          _slipDate != null
                              ? 'Slip Date: ${_dateFormat.format(_slipDate!)}'
                              : 'Select Slip Date *',
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text('Record Payment'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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