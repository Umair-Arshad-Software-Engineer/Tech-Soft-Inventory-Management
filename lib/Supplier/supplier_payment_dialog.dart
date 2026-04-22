// lib/screens/suppliers/supplier_payment_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../config/api_config.dart';
import '../../models/supplier.dart';
import '../../providers/auth_provider.dart';
import '../../providers/supplier_ledger_provider.dart';
import '../Banks/banknames.dart';

class SupplierPaymentDialog extends StatefulWidget {
  final Supplier supplier;
  const SupplierPaymentDialog({super.key, required this.supplier});

  @override
  State<SupplierPaymentDialog> createState() => _SupplierPaymentDialogState();
}

class _SupplierPaymentDialogState extends State<SupplierPaymentDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _chequeNumCtrl = TextEditingController();

  String _paymentMethod = 'cash';
  Bank? _selectedBank;
  DateTime _paymentDate = DateTime.now();
  DateTime? _chequeDate;
  bool _isLoading = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  final _df = DateFormat('MMM dd, yyyy');

  static const _methods = [
    {'value': 'cash',   'label': 'Cash',     'icon': Icons.payments_outlined},
    {'value': 'bank',   'label': 'Bank',      'icon': Icons.account_balance_outlined},
    {'value': 'cheque', 'label': 'Cheque',    'icon': Icons.receipt_long_outlined},
    {'value': 'slip',   'label': 'Slip',      'icon': Icons.receipt_outlined},
  ];

  static const _methodColors = {
    'cash':   Color(0xFF10B981),
    'bank':   Color(0xFF3B82F6),
    'cheque': Color(0xFFF59E0B),
    'slip':   Color(0xFF8B5CF6),
  };

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _refCtrl.dispose();
    _chequeNumCtrl.dispose();
    super.dispose();
  }

  Color get _activeColor =>
      _methodColors[_paymentMethod] ?? const Color(0xFF10B981);

  String? _getToken() {
    try {
      return Provider.of<AuthProvider>(context, listen: false).user?.token;
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if ((_paymentMethod == 'bank' || _paymentMethod == 'cheque') &&
        _selectedBank == null) {
      _err('Please select a bank');
      return;
    }
    if (_paymentMethod == 'cheque') {
      if (_chequeNumCtrl.text.trim().isEmpty) {
        _err('Please enter cheque number');
        return;
      }
      if (_chequeDate == null) {
        _err('Please select cheque date');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/suppliers/${widget.supplier.id}/payments'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
        },
        body: json.encode({
          'amount': double.parse(_amountCtrl.text.trim()),
          'payment_method': _paymentMethod,
          'bank_name': _selectedBank?.name,
          'cheque_number':
          _paymentMethod == 'cheque' ? _chequeNumCtrl.text.trim() : null,
          'cheque_date': _chequeDate?.toIso8601String(),
          'reference_number':
          _refCtrl.text.isEmpty ? null : _refCtrl.text.trim(),
          'description': _descCtrl.text.isEmpty ? null : _descCtrl.text.trim(),
          'transaction_date': _paymentDate.toIso8601String(),
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        // Refresh ledger
        if (mounted) {
          await Provider.of<SupplierLedgerProvider>(context, listen: false)
              .fetchLedger(
              context: context, supplierId: widget.supplier.id, page: 1);
        }
        if (mounted) Navigator.pop(context, true);
      } else {
        _err(data['message'] ?? 'Failed to record payment');
      }
    } catch (e) {
      _err('Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _err(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  Future<void> _pickPaymentDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: _dpTheme,
    );
    if (p != null) setState(() => _paymentDate = p);
  }

  Future<void> _pickChequeDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _chequeDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: _dpTheme,
    );
    if (p != null) setState(() => _chequeDate = p);
  }

  Widget Function(BuildContext, Widget?) get _dpTheme => (ctx, child) => Theme(
    data: Theme.of(ctx).copyWith(
        colorScheme: ColorScheme.light(primary: _activeColor)),
    child: child!,
  );

  Future<void> _openBankPicker() async {
    final result = await showModalBottomSheet<Bank>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _BankSheet(
          selected: _selectedBank, accentColor: _activeColor),
    );
    if (result != null) setState(() => _selectedBank = result);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAmountField(),
                      const SizedBox(height: 20),
                      _buildMethodSelector(),
                      const SizedBox(height: 16),
                      // Bank selector
                      if (_paymentMethod == 'bank' ||
                          _paymentMethod == 'cheque') ...[
                        _lbl('Bank *'),
                        const SizedBox(height: 6),
                        _buildBankTile(),
                        const SizedBox(height: 16),
                      ],
                      // Cheque fields
                      if (_paymentMethod == 'cheque') ...[
                        Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                _lbl('Cheque No. *'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _chequeNumCtrl,
                                  decoration:
                                  _inp(hint: 'e.g. 001234'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                _lbl('Cheque Date *'),
                                const SizedBox(height: 6),
                                _dateTile(
                                  val: _chequeDate != null
                                      ? _df.format(_chequeDate!)
                                      : 'Pick date',
                                  filled: _chequeDate != null,
                                  onTap: _pickChequeDate,
                                ),
                              ],
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                      ],
                      // Reference
                      _lbl('Reference # (optional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _refCtrl,
                        decoration:
                        _inp(hint: 'e.g. TXN-001, CHQ-123'),
                      ),
                      const SizedBox(height: 16),
                      // Description
                      _lbl('Description (optional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 2,
                        decoration: _inp(
                            hint: 'e.g. Monthly payment for goods received'),
                      ),
                      const SizedBox(height: 16),
                      // Payment date
                      _lbl('Payment Date'),
                      const SizedBox(height: 6),
                      _dateTile(
                        val: _df.format(_paymentDate),
                        filled: true,
                        onTap: _pickPaymentDate,
                        icon: Icons.calendar_today_outlined,
                      ),
                      const SizedBox(height: 24),
                      _buildSubmitBtn(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
      decoration: BoxDecoration(
        color: _activeColor.withOpacity(0.06),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
            bottom: BorderSide(color: _activeColor.withOpacity(0.15))),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _activeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.payments_outlined,
                color: _activeColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Record Payment',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                Text(widget.supplier.name,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF8E8E93))),
              ],
            ),
          ),
          IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lbl('Amount *'),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _activeColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _activeColor.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('Rs',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _activeColor)),
              ),
              Container(
                  width: 1, height: 40, color: _activeColor.withOpacity(0.2)),
              Expanded(
                child: TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                        color: Color(0xFFC7C7CC),
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                    border: InputBorder.none,
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Amount required';
                    if ((double.tryParse(v) ?? 0) <= 0) return 'Enter valid amount';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lbl('Payment Method *'),
        const SizedBox(height: 8),
        Row(
          children: _methods.map((m) {
            final val = m['value'] as String;
            final selected = _paymentMethod == val;
            final col = _methodColors[val]!;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _paymentMethod = val;
                  _selectedBank = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? col.withOpacity(0.1)
                        : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: selected ? col : const Color(0xFFE5E5EA),
                        width: selected ? 2 : 1),
                  ),
                  child: Column(children: [
                    Icon(m['icon'] as IconData,
                        size: 22,
                        color: selected ? col : const Color(0xFF8E8E93)),
                    const SizedBox(height: 5),
                    Text(m['label'] as String,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: selected ? col : const Color(0xFF8E8E93))),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBankTile() {
    return GestureDetector(
      onTap: _openBankPicker,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: _selectedBank != null
              ? _activeColor.withOpacity(0.05)
              : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _selectedBank != null
                  ? _activeColor.withOpacity(0.4)
                  : const Color(0xFFE5E5EA)),
        ),
        child: Row(
          children: [
            if (_selectedBank != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(_selectedBank!.iconPath,
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                        Icons.account_balance,
                        size: 28,
                        color: _activeColor)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_selectedBank!.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1C1C1E))),
              ),
              Icon(Icons.check_circle_rounded,
                  color: _activeColor, size: 18),
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
    );
  }

  Widget _buildSubmitBtn() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              _activeColor,
              _activeColor.withOpacity(0.75),
            ],
          ),
          boxShadow: [
            BoxShadow(
                color: _activeColor.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Confirm Payment',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateTile({
    required String val,
    required bool filled,
    required VoidCallback onTap,
    IconData icon = Icons.calendar_today_outlined,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: filled
                ? _activeColor.withOpacity(0.05)
                : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: filled
                    ? _activeColor.withOpacity(0.3)
                    : const Color(0xFFE5E5EA)),
          ),
          child: Row(children: [
            Icon(icon,
                size: 16,
                color: filled ? _activeColor : Colors.grey[400]),
            const SizedBox(width: 8),
            Text(val,
                style: TextStyle(
                    fontSize: 13,
                    color: filled
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFFC7C7CC))),
          ]),
        ),
      );

  Widget _lbl(String t) => Text(t,
      style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF8E8E93),
          fontWeight: FontWeight.w600));

  InputDecoration _inp({required String hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 13),
    isDense: true,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    filled: true,
    fillColor: const Color(0xFFF5F5F7),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _activeColor, width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5)),
  );
}

// ─── Bank Picker Bottom Sheet ──────────────────────────────────────────────

class _BankSheet extends StatefulWidget {
  final Bank? selected;
  final Color accentColor;
  const _BankSheet({required this.selected, required this.accentColor});

  @override
  State<_BankSheet> createState() => _BankSheetState();
}

class _BankSheetState extends State<_BankSheet> {
  final _search = TextEditingController();
  List<Bank> _list = pakistaniBanks;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _filter(String q) => setState(() {
    _list = pakistaniBanks
        .where((b) => b.name.toLowerCase().contains(q.toLowerCase()))
        .toList();
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(2)),
          ),
          Row(
            children: [
              const Text('Select Bank',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Color(0xFF8E8E93)))),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            onChanged: _filter,
            decoration: InputDecoration(
              hintText: 'Search banks…',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: const Color(0xFFF5F5F7),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: widget.accentColor, width: 1.5)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _list.length,
              itemBuilder: (_, i) {
                final b = _list[i];
                final sel = widget.selected?.name == b.name;
                return Material(
                  color: sel
                      ? widget.accentColor.withOpacity(0.06)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(b.iconPath,
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
                            child: Icon(Icons.account_balance,
                                size: 20, color: widget.accentColor),
                          )),
                    ),
                    title: Text(b.name,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                            sel ? FontWeight.bold : FontWeight.normal,
                            color: sel
                                ? widget.accentColor
                                : const Color(0xFF1C1C1E))),
                    trailing: sel
                        ? Icon(Icons.check_circle_rounded,
                        color: widget.accentColor, size: 22)
                        : null,
                    onTap: () => Navigator.pop(context, b),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}