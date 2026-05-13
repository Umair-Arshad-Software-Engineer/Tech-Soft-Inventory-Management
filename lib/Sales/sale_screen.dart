// lib/screens/sales/sale_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../models/customer.dart';
import '../../models/product_model.dart';
import '../../providers/customer_provider.dart';
import '../../providers/product_provider.dart';
import '../Banks/banknames.dart';
import '../providers/sale_provider.dart';
import '../services/sale_pdf_generator.dart';

// ─────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────

class SaleItem {
  final ProductModel product;
  int quantity;
  double unitPrice;
  double? customerSpecificPrice;
  bool usingCustomerPrice;

  SaleItem({
    required this.product,
    this.quantity = 1,
    required this.unitPrice,
    this.customerSpecificPrice,
    this.usingCustomerPrice = false,
  });

  double get total => unitPrice * quantity;
  double get standardPrice => product.salePrice.toDouble();
  bool get hasPriceDifference =>
      customerSpecificPrice != null && customerSpecificPrice != standardPrice;
}

// Quantity Input Widget - Reusable component
class QuantityInput extends StatelessWidget {
  final int quantity;
  final Function(int) onChanged;
  final double width;

  const QuantityInput({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.width = 70,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        initialValue: quantity.toString(),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
          ),
        ),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        onChanged: (value) {
          if (value.isEmpty) return;
          final newQty = int.tryParse(value);
          if (newQty != null && newQty >= 1 && newQty <= 9999) {
            onChanged(newQty);
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────

class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key});

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen>
    with SingleTickerProviderStateMixin {
  bool _isPosMode = true;

  final List<SaleItem> _cartItems = [];
  Customer? _selectedCustomer;
  double _discountAmount = 0.0;
  double _discountPercent = 0.0;
  bool _usePercentDiscount = true;

  bool _useCustomerPrices = false;
  bool _isFetchingCustomerPrices = false;
  Map<int, double> _customerPriceMap = {};

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<ProductModel> _searchResults = [];
  bool _isSearching = false;

  final TextEditingController _invoiceNoteController = TextEditingController();
  DateTime _invoiceDate = DateTime.now();
  DateTime? _dueDate;
  DateTime? _creditDueDate;

  String? _selectedCategory;
  String? _selectedSubcategory;
  List<ProductModel> _allProducts = [];
  bool _isLoadingProducts = false;

  late final AnimationController _toggleAnim;

  // Controls the bottom options panel expansion in POS mode
  bool _showOptionsPanel = false;

  // ── FIX: Persistent discount controllers ──────────────────────
  // These live for the lifetime of the screen, so typing is never interrupted.
  late final TextEditingController _discountPercentCtrl;
  late final TextEditingController _discountAmountCtrl;
  // Track whether the controllers are being updated programmatically
  // so we don't trigger an onChange → setState → rebuild loop.
  bool _updatingDiscountCtrl = false;
  // ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _toggleAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _searchController.addListener(_onSearchChanged);

    // Initialise persistent discount controllers with the starting values.
    _discountPercentCtrl =
        TextEditingController(text: _discountPercent.toStringAsFixed(1));
    _discountAmountCtrl =
        TextEditingController(text: _discountAmount.toStringAsFixed(2));

    _loadAllProducts();
  }

  @override
  void dispose() {
    _toggleAnim.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _invoiceNoteController.dispose();
    _discountPercentCtrl.dispose();
    _discountAmountCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  COMPUTED
  // ─────────────────────────────────────────────

  double get _subtotal =>
      _cartItems.fold(0.0, (sum, item) => sum + item.total);

  double get _discountValue => _usePercentDiscount
      ? _subtotal * (_discountPercent / 100)
      : _discountAmount;

  double get _grandTotal => _subtotal - _discountValue;

  double get _customerPriceSavings => _cartItems
      .where((i) => i.usingCustomerPrice && i.hasPriceDifference)
      .fold(0.0,
          (sum, i) => sum + ((i.standardPrice - i.unitPrice) * i.quantity));

  // ─────────────────────────────────────────────
  //  DISCOUNT CONTROLLER HELPERS
  // ─────────────────────────────────────────────

  /// Call whenever the discount values are changed programmatically
  /// (e.g. applying customer discount, clearing cart) so the text
  /// fields stay in sync without triggering the onChange callbacks.
  void _syncDiscountControllers() {
    _updatingDiscountCtrl = true;
    _discountPercentCtrl.text = _discountPercent.toStringAsFixed(1);
    _discountAmountCtrl.text = _discountAmount.toStringAsFixed(2);
    _updatingDiscountCtrl = false;
  }

  // ─────────────────────────────────────────────
  //  CUSTOMER PRICE LOGIC
  // ─────────────────────────────────────────────

  Future<void> _fetchAndApplyCustomerPrices() async {
    if (_selectedCustomer == null || !_useCustomerPrices) {
      setState(() {
        for (final item in _cartItems) {
          item.usingCustomerPrice = false;
          item.unitPrice = item.standardPrice;
        }
        _customerPriceMap = {};
      });
      return;
    }

    setState(() => _isFetchingCustomerPrices = true);

    try {
      final productIds =
      _cartItems.map((i) => i.product.id).whereType<int>().toList();

      if (productIds.isEmpty) {
        setState(() => _isFetchingCustomerPrices = false);
        return;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.bulkCustomerPricesUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'customer_id': _selectedCustomer!.id,
          'product_ids': productIds,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          final raw = json['data'] as Map<String, dynamic>;
          final priceMap = raw.map(
                  (k, v) => MapEntry(int.parse(k), double.parse(v.toString())));
          setState(() {
            _customerPriceMap = priceMap;
            for (final item in _cartItems) {
              final pid = item.product.id;
              if (pid != null && priceMap.containsKey(pid)) {
                item.customerSpecificPrice = priceMap[pid];
                item.usingCustomerPrice = true;
                item.unitPrice = priceMap[pid]!;
              } else {
                item.customerSpecificPrice = null;
                item.usingCustomerPrice = false;
                item.unitPrice = item.standardPrice;
              }
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not fetch customer prices: $e'),
              backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingCustomerPrices = false);
    }
  }

  double _resolvePrice(ProductModel product) {
    if (_useCustomerPrices &&
        _selectedCustomer != null &&
        product.id != null &&
        _customerPriceMap.containsKey(product.id)) {
      return _customerPriceMap[product.id]!;
    }
    return product.salePrice.toDouble();
  }

  bool _hasCustomerPrice(ProductModel product) =>
      _useCustomerPrices &&
          _selectedCustomer != null &&
          product.id != null &&
          _customerPriceMap.containsKey(product.id);

  // ─────────────────────────────────────────────
  //  SEARCH
  // ─────────────────────────────────────────────

  Future<void> _loadAllProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final provider = Provider.of<ProductProvider>(context, listen: false);
      await provider.fetchProducts();
      if (mounted) {
        setState(() {
          _allProducts = provider.products;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingProducts = false);
  }

  Future<void> _onSearchChanged() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final provider = Provider.of<ProductProvider>(context, listen: false);
      final result = await provider.searchProducts(query);
      if (result['success'] == true && mounted) {
        setState(() {
          _searchResults = (result['data'] as List<dynamic>?)
              ?.map((e) => e as ProductModel)
              .toList() ??
              [];
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isSearching = false);
  }

  void _addToCart(ProductModel product) {
    setState(() {
      final idx = _cartItems.indexWhere((i) => i.product.id == product.id);
      if (idx >= 0) {
        _cartItems[idx].quantity++;
      } else {
        final customPrice = _hasCustomerPrice(product)
            ? _customerPriceMap[product.id]
            : null;
        _cartItems.add(SaleItem(
          product: product,
          unitPrice: _resolvePrice(product),
          customerSpecificPrice: customPrice,
          usingCustomerPrice: customPrice != null,
        ));
      }
      _searchController.clear();
      _searchResults = [];
    });
    HapticFeedback.lightImpact();
  }

  void _removeFromCart(int index) => setState(() => _cartItems.removeAt(index));

  void _clearCart() {
    setState(() {
      _cartItems.clear();
      _selectedCustomer = null;
      _discountAmount = 0;
      _discountPercent = 0;
      _useCustomerPrices = false;
      _customerPriceMap = {};
      _showOptionsPanel = false;
    });
    // Keep controllers in sync after programmatic reset.
    _syncDiscountControllers();
  }

  void _switchMode(bool pos) {
    setState(() => _isPosMode = pos);
    pos ? _toggleAnim.reverse() : _toggleAnim.forward();
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F9),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
              child: _isPosMode ? _buildPosLayout() : _buildInvoiceLayout()),
        ],
      ),
    );
  }

  // ── HEADER ───────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 16, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEF5), width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF2D3142)),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 15),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sales',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E2D))),
              Text('Create & manage sales transactions',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ],
          ),
          const Spacer(),
          Container(
            height: 42,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: const Color(0xFFF0F0F8),
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                _buildToggleBtn('POS Counter', Icons.point_of_sale, true),
                _buildToggleBtn('Invoice', Icons.receipt_long, false),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (_cartItems.isNotEmpty)
            TextButton.icon(
              onPressed: _clearCart,
              icon: const Icon(Icons.delete_outline,
                  size: 16, color: Color(0xFFEF4444)),
              label: const Text('Clear',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, IconData icon, bool isPos) {
    final isActive = _isPosMode == isPos;
    return GestureDetector(
      onTap: () => _switchMode(isPos),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isActive
              ? [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ]
              : [],
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 15,
                color: isActive
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF9CA3AF)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }

  // ── LAYOUTS ──────────────────────────────────

  Widget _buildPosLayout() {
    return Row(
      children: [
        // ── LEFT: product search + options panel at bottom ──
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(child: _buildProductPanel()),
              // ── OPTIONS PANEL: discount + customer prices ──
              _buildLeftOptionsPanel(),
            ],
          ),
        ),
        Container(
          width: 390,
          decoration: const BoxDecoration(
            color: Colors.white,
            border:
            Border(left: BorderSide(color: Color(0xFFEEEEF5), width: 1)),
          ),
          child: _buildCartPanel(isPOS: true),
        ),
      ],
    );
  }

  Widget _buildInvoiceLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildInvoiceMeta(),
                const SizedBox(height: 16),
                _buildSearchBar(),
                const SizedBox(height: 12),
                if (_searchResults.isNotEmpty) _buildSearchDropdown(),
                const SizedBox(height: 16),
                _buildInvoiceItemsTable(),
                const SizedBox(height: 16),
                _buildInvoiceOptionsCard(),
                const SizedBox(height: 16),
                _buildInvoiceNotes(),
              ],
            ),
          ),
        ),
        Container(
          width: 330,
          decoration: const BoxDecoration(
            color: Colors.white,
            border:
            Border(left: BorderSide(color: Color(0xFFEEEEF5), width: 1)),
          ),
          child: _buildCartPanel(isPOS: false),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  LEFT OPTIONS PANEL (POS mode – below product area)
  // ─────────────────────────────────────────────

  Widget _buildLeftOptionsPanel() {
    final hasCustomer = _selectedCustomer != null;
    final hasCustomerDiscount =
        hasCustomer && _selectedCustomer!.discountPercent > 0;
    final bool usingCustomerDiscount = hasCustomerDiscount &&
        _usePercentDiscount &&
        _discountPercent == _selectedCustomer!.discountPercent;

    int activeOptions = 0;
    if (_useCustomerPrices && _customerPriceMap.isNotEmpty) activeOptions++;
    if (_discountValue > 0) activeOptions++;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEEEEF5))),
        boxShadow: _showOptionsPanel
            ? [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -3))
        ]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Toggle strip ──
          InkWell(
            onTap: () => setState(() => _showOptionsPanel = !_showOptionsPanel),
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.tune,
                        size: 16, color: Color(0xFF7C3AED)),
                  ),
                  const SizedBox(width: 10),
                  const Text('Discount & Pricing',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                  const SizedBox(width: 8),
                  if (activeOptions > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$activeOptions active',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                  if (_discountValue > 0) ...[
                    const SizedBox(width: 6),
                    _chip(
                        '- Rs ${_discountValue.toStringAsFixed(2)}',
                        const Color(0xFFECFDF5),
                        const Color(0xFF065F46)),
                  ],
                  if (_useCustomerPrices &&
                      _customerPriceMap.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _chip('Custom ₹', const Color(0xFFECFDF5),
                        const Color(0xFF065F46)),
                  ],
                  const Spacer(),
                  AnimatedRotation(
                    turns: _showOptionsPanel ? 0.5 : 0,
                    duration: const Duration(milliseconds: 260),
                    child: const Icon(Icons.keyboard_arrow_down,
                        size: 20, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable content ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildCompactDiscountSection(
                      usingCustomerDiscount, hasCustomerDiscount)),
                  const SizedBox(width: 12),
                  if (hasCustomer)
                    Expanded(child: _buildCompactCustomerPriceToggle()),
                ],
              ),
            ),
            crossFadeState: _showOptionsPanel
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 260),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  COMPACT DISCOUNT SECTION  ← FIXED
  // ─────────────────────────────────────────────

  Widget _buildCompactDiscountSection(
      bool usingCustomerDiscount, bool hasCustomerDiscount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Discount',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151))),
            const Spacer(),
            GestureDetector(
              onTap: () {
                setState(() => _usePercentDiscount = !_usePercentDiscount);
                // Sync the active controller text after the mode switch so the
                // field shows the right value immediately without a rebuild loop.
                _syncDiscountControllers();
              },
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(
                  _usePercentDiscount ? '% Percent' : 'Rs Fixed',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7C3AED)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // ── FIX: use persistent controllers, no ValueKey rebuild ──
        SizedBox(
          height: 36,
          child: TextField(
            // Use the controller matching the current mode.
            // Do NOT assign a new controller here; use the persistent one.
            controller: _usePercentDiscount
                ? _discountPercentCtrl
                : _discountAmountCtrl,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: _usePercentDiscount ? '0.0 %' : '0.00 Rs',
              hintStyle: const TextStyle(fontSize: 12),
              isDense: true,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: usingCustomerDiscount
                  ? const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.check_circle,
                    color: Color(0xFF10B981), size: 14),
              )
                  : null,
            ),
            onChanged: (v) {
              if (_updatingDiscountCtrl) return;
              final parsed = double.tryParse(v) ?? 0.0;
              setState(() {
                if (_usePercentDiscount) {
                  _discountPercent = parsed.clamp(0, 100);
                } else {
                  _discountAmount = parsed.clamp(0, _subtotal > 0 ? _subtotal : double.infinity);
                }
              });
            },
          ),
        ),
        // ──────────────────────────────────────────────────────────

        if (hasCustomerDiscount) ...[
          const SizedBox(height: 8),
          _buildCustomerDiscountCheckbox(usingCustomerDiscount),
        ],
      ],
    );
  }

  /// Compact customer-price toggle for left options panel
  Widget _buildCompactCustomerPriceToggle() {
    final activeCount = _cartItems.where((i) => i.usingCustomerPrice).length;
    final hasAnyCustom = _customerPriceMap.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Customer Pricing',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _useCustomerPrices
                ? const Color(0xFFECFDF5)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _useCustomerPrices
                  ? const Color(0xFF10B981).withOpacity(0.4)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Checkbox(
                  value: _useCustomerPrices,
                  onChanged: _isFetchingCustomerPrices
                      ? null
                      : (val) async {
                    setState(
                            () => _useCustomerPrices = val ?? false);
                    await _fetchAndApplyCustomerPrices();
                  },
                  activeColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  side: const BorderSide(
                      color: Color(0xFF10B981), width: 1.5),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use Customer Prices',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _useCustomerPrices
                            ? const Color(0xFF065F46)
                            : const Color(0xFF374151),
                      ),
                    ),
                    if (_useCustomerPrices && !_isFetchingCustomerPrices)
                      Text(
                        hasAnyCustom
                            ? '$activeCount item${activeCount != 1 ? 's' : ''} custom'
                            : 'No custom prices set',
                        style: TextStyle(
                            fontSize: 9,
                            color: hasAnyCustom
                                ? const Color(0xFF10B981)
                                : const Color(0xFF9CA3AF)),
                      )
                    else if (!_useCustomerPrices)
                      const Text('Standard prices',
                          style: TextStyle(
                              fontSize: 9, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              if (_isFetchingCustomerPrices)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF10B981)))
              else if (_useCustomerPrices && hasAnyCustom)
                const Icon(Icons.verified,
                    size: 14, color: Color(0xFF10B981))
              else if (_useCustomerPrices && !hasAnyCustom)
                  const Icon(Icons.info_outline,
                      size: 14, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ],
    );
  }

  /// Inline options card shown inside the Invoice left scroll area
  Widget _buildInvoiceOptionsCard() {
    final hasCustomer = _selectedCustomer != null;
    final hasCustomerDiscount =
        hasCustomer && _selectedCustomer!.discountPercent > 0;
    final bool usingCustomerDiscount = hasCustomerDiscount &&
        _usePercentDiscount &&
        _discountPercent == _selectedCustomer!.discountPercent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 16, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              const Text('Discount & Pricing',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E2D))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _buildCompactDiscountSection(
                      usingCustomerDiscount, hasCustomerDiscount)),
              if (hasCustomer) ...[
                const SizedBox(width: 16),
                Expanded(child: _buildCompactCustomerPriceToggle()),
              ],
            ],
          ),
        ],
      ),
    );
  }


  // ── CATEGORY CHIPS ────────────────────────────

  List<String> get _categories {
    final cats = _allProducts
        .map((p) => p.category?.name ?? 'Uncategorized')
        .toSet()
        .toList()
      ..sort();
    return cats;
  }

  List<String> get _subcategories {
    if (_selectedCategory == null) return [];
    final subs = _allProducts
        .where((p) => (p.category?.name ?? 'Uncategorized') == _selectedCategory)
        .map((p) => p.subcategory?.name ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return subs;
  }

  List<ProductModel> get _filteredBrowseProducts {
    return _allProducts.where((p) {
      final cat = p.category?.name ?? 'Uncategorized';
      final sub = p.subcategory?.name ?? '';
      if (_selectedCategory != null && cat != _selectedCategory) return false;
      if (_selectedSubcategory != null && sub != _selectedSubcategory) return false;
      return true;
    }).toList();
  }

  Widget _buildCategoryChips() {
    final cats = _categories;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _filterChip(
            label: 'All',
            icon: Icons.grid_view_rounded,
            selected: _selectedCategory == null,
            color: const Color(0xFF7C3AED),
            onTap: () => setState(() {
              _selectedCategory = null;
              _selectedSubcategory = null;
            }),
          ),
          const SizedBox(width: 6),
          ...cats.map((cat) {
            final count = _allProducts
                .where((p) => (p.category?.name ?? 'Uncategorized') == cat)
                .length;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _filterChip(
                label: '$cat ($count)',
                selected: _selectedCategory == cat,
                color: const Color(0xFF3B82F6),
                onTap: () => setState(() {
                  _selectedCategory = _selectedCategory == cat ? null : cat;
                  _selectedSubcategory = null;
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSubcategoryChips() {
    final subs = _subcategories;
    if (subs.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          _filterChip(
            label: 'All sub',
            selected: _selectedSubcategory == null,
            color: const Color(0xFF10B981),
            small: true,
            onTap: () => setState(() => _selectedSubcategory = null),
          ),
          const SizedBox(width: 6),
          ...subs.map((sub) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _filterChip(
              label: sub,
              selected: _selectedSubcategory == sub,
              color: const Color(0xFF10B981),
              small: true,
              onTap: () => setState(() {
                _selectedSubcategory = _selectedSubcategory == sub ? null : sub;
              }),
            ),
          )),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
    bool small = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
            horizontal: small ? 10 : 12,
            vertical: small ? 4 : 5),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: small ? 12 : 13, color: selected ? color : const Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: small ? 10 : 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PRODUCT PANEL ────────────────────────────

  Widget _buildProductPanel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              _buildSearchBar(),
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildSearchDropdown(),
              ],
            ],
          ),
        ),
        _buildCategoryChips(),
        if (_selectedCategory != null) _buildSubcategoryChips(),
        const Divider(height: 1, color: Color(0xFFEEEEF5)),
        Expanded(
          child: _searchController.text.isNotEmpty
              ? (_searchResults.isEmpty && !_isSearching
              ? _buildNoResults()
              : const SizedBox.shrink())
              : _buildBrowseProductList(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        autofocus: _isPosMode,
        decoration: InputDecoration(
          hintText: 'Scan barcode or search by product name / barcode…',
          hintStyle:
          const TextStyle(fontSize: 14, color: Color(0xFFB0B7C3)),
          prefixIcon: _isSearching
              ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child:
                  CircularProgressIndicator(strokeWidth: 2)))
              : const Icon(Icons.search, color: Color(0xFF9CA3AF)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchResults = []);
              })
              : IconButton(
            icon: const Icon(Icons.qr_code_scanner,
                color: Color(0xFF7C3AED)),
            onPressed: _showBarcodeScanDialog,
            tooltip: 'Scan Barcode',
          ),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onSubmitted: (_) {
          if (_searchResults.length == 1) _addToCart(_searchResults.first);
        },
      ),
    );
  }

  Widget _buildSearchDropdown() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) =>
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
        itemBuilder: (context, i) {
          final p = _searchResults[i];
          final inCart = _cartItems.any((item) => item.product.id == p.id);
          final hasCustomPrice = _hasCustomerPrice(p);
          final displayPrice = _resolvePrice(p);

          return ListTile(
            dense: true,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.inventory_2_outlined,
                  size: 20, color: Color(0xFF7C3AED)),
            ),
            title: Text(p.itemName,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${p.barcode ?? 'No barcode'} · ${p.unit?.symbol ?? ''}',
              style:
              const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (p.physicalQty <= p.minStock)
                  _chip('Low Stock', const Color(0xFFFFF3CD),
                      const Color(0xFF92400E)),
                const SizedBox(width: 6),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rs ${displayPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: hasCustomPrice
                              ? const Color(0xFF10B981)
                              : const Color(0xFF7C3AED)),
                    ),
                    if (hasCustomPrice)
                      Text(
                        'Was Rs ${p.salePrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9CA3AF),
                            decoration: TextDecoration.lineThrough),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                inCart
                    ? Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.check,
                        size: 16, color: Color(0xFF10B981)))
                    : ElevatedButton(
                    onPressed: () => _addToCart(p),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Add',
                        style: TextStyle(
                            fontSize: 12, color: Colors.white))),
              ],
            ),
            onTap: () => _addToCart(p),
          );
        },
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(4)),
    child: Text(text,
        style: TextStyle(
            fontSize: 10,
            color: fg,
            fontWeight: FontWeight.w600)),
  );

  Widget _buildPosEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
                color: Color(0xFFF3F0FF), shape: BoxShape.circle),
            child: const Icon(Icons.point_of_sale,
                size: 50, color: Color(0xFF7C3AED)),
          ),
          const SizedBox(height: 20),
          const Text('Ready to Scan',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E2D))),
          const SizedBox(height: 8),
          const Text(
            'Scan a barcode or type a product name\nto add items to the cart',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _showBarcodeScanDialog,
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text('Scan Barcode'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF7C3AED),
              side: const BorderSide(color: Color(0xFF7C3AED)),
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.search_off,
            size: 48, color: Color(0xFFD1D5DB)),
        const SizedBox(height: 12),
        Text(
          'No products found for "${_searchController.text}"',
          style: const TextStyle(
              color: Color(0xFF9CA3AF), fontSize: 14),
        ),
      ],
    ),
  );

  // ── BROWSE PRODUCT LIST ───────────────────────
  Widget _buildBrowseProductList() {
    if (_isLoadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    final products = _filteredBrowseProducts;
    if (products.isEmpty) {
      return _buildPosEmptyState();
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: products.length,
      itemBuilder: (ctx, i) => _buildProductCard(products[i]),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final inCart = _cartItems.any((item) => item.product.id == product.id);
    final hasCustomPrice = _hasCustomerPrice(product);
    final displayPrice = _resolvePrice(product);
    final isLowStock = product.physicalQty <= product.minStock;
    final catName = product.category?.name ?? '';
    final subName = product.subcategory?.name ?? '';

    return GestureDetector(
      onTap: () => _addToCart(product),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: inCart ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inCart
                ? const Color(0xFF10B981).withOpacity(0.4)
                : const Color(0xFFE5E7EB),
            width: inCart ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 72,
              width: double.infinity,
              decoration: BoxDecoration(
                color: inCart
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFF3F0FF),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(Icons.inventory_2_outlined,
                        size: 32, color: Color(0xFF7C3AED)),
                  ),
                  if (isLowStock)
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: const Color(0xFFF59E0B).withOpacity(0.4)),
                        ),
                        child: const Text('Low',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF92400E))),
                      ),
                    ),
                  if (inCart)
                    Positioned(
                      top: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.check,
                            size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.itemName,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E1E2D)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 3,
                      children: [
                        if (catName.isNotEmpty)
                          _miniChip(catName,
                              const Color(0xFFEDE9FE),
                              const Color(0xFF7C3AED)),
                        if (subName.isNotEmpty)
                          _miniChip(subName,
                              const Color(0xFFD1FAE5),
                              const Color(0xFF065F46)),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rs ${displayPrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: hasCustomPrice
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF7C3AED)),
                              ),
                              if (hasCustomPrice)
                                Text(
                                  'Rs ${product.salePrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF9CA3AF),
                                      decoration:
                                      TextDecoration.lineThrough),
                                ),
                            ],
                          ),
                        ),
                        if (inCart)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '×${_cartItems.firstWhere((i) => i.product.id == product.id).quantity}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
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
      ),
    );
  }

  Widget _miniChip(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(4)),
    child: Text(text,
        style: TextStyle(
            fontSize: 9,
            color: fg,
            fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis),
  );

  // ── CART PANEL (RIGHT) ─────────────────────────

  Widget _buildCartPanel({required bool isPOS}) {
    return Column(
      children: [
        _buildCustomerSection(),
        const Divider(height: 1, color: Color(0xFFEEEEF5)),
        Expanded(
          child: _cartItems.isEmpty
              ? _buildEmptyCart()
              : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _cartItems.length,
            itemBuilder: (ctx, i) => _buildCartItem(i),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEEEEF5)),
        _buildSummarySection(isPOS),
      ],
    );
  }

  Widget _buildCustomerSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showCustomerPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedCustomer != null
                          ? const Color(0xFFF3F0FF)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedCustomer != null
                            ? const Color(0xFF7C3AED).withOpacity(0.3)
                            : const Color(0xFFEF4444).withOpacity(0.5),
                        width: _selectedCustomer == null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedCustomer != null
                              ? Icons.person
                              : Icons.person_add_alt,
                          size: 18,
                          color: _selectedCustomer != null
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedCustomer?.name ?? 'Select Customer *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _selectedCustomer != null
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: _selectedCustomer != null
                                  ? const Color(0xFF7C3AED)
                                  : const Color(0xFFEF4444),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_selectedCustomer != null)
                          GestureDetector(
                            onTap: () => setState(() {
                              _selectedCustomer = null;
                              _useCustomerPrices = false;
                              _customerPriceMap = {};
                              _discountAmount = 0;
                              _discountPercent = 0;
                              _showOptionsPanel = false;
                              _syncDiscountControllers();
                              for (final item in _cartItems) {
                                item.usingCustomerPrice = false;
                                item.customerSpecificPrice = null;
                                item.unitPrice = item.standardPrice;
                              }
                            }),
                            child: const Icon(Icons.close,
                                size: 14, color: Color(0xFF9CA3AF)),
                          )
                        else
                          const Icon(Icons.keyboard_arrow_down,
                              size: 16, color: Color(0xFFEF4444)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _showAddCustomerDialog,
                icon: const Icon(Icons.person_add, size: 20),
                tooltip: 'Add New Customer',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F0FF),
                  foregroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),

          if (_selectedCustomer == null && _cartItems.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.info_outline,
                    size: 14, color: Color(0xFFEF4444)),
                SizedBox(width: 4),
                Text(
                  'Customer selection is required to proceed',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          if (_selectedCustomer != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () =>
                  setState(() => _showOptionsPanel = !_showOptionsPanel),
              child: Row(
                children: [
                  if (_selectedCustomer!.discountPercent > 0)
                    _chip(
                        '${_selectedCustomer!.discountPercent.toStringAsFixed(1)}% discount',
                        const Color(0xFFF3F0FF),
                        const Color(0xFF7C3AED)),
                  if (_discountValue > 0) ...[
                    const SizedBox(width: 6),
                    _chip('Disc: Rs ${_discountValue.toStringAsFixed(2)}',
                        const Color(0xFFECFDF5),
                        const Color(0xFF065F46)),
                  ],
                  if (_useCustomerPrices &&
                      _customerPriceMap.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _chip('Custom ₹', const Color(0xFFECFDF5),
                        const Color(0xFF065F46)),
                  ],
                  const Spacer(),
                  if (_isPosMode)
                    Text(
                      'Pricing options ↙',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartItem(int index) {
    final item = _cartItems[index];
    final showCustomBadge =
        item.usingCustomerPrice && item.hasPriceDifference;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: item.usingCustomerPrice
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.usingCustomerPrice
              ? const Color(0xFF10B981).withOpacity(0.25)
              : const Color(0xFFF0F0F8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.product.itemName,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showCustomBadge) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Custom ₹',
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close,
                    size: 14, color: Color(0xFFEF4444)),
                padding: EdgeInsets.zero,
                constraints:
                const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () => _removeFromCart(index),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 84,
                    child: TextFormField(
                      key: ValueKey(
                          'price_${index}_${item.unitPrice}'),
                      initialValue: item.unitPrice.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 12,
                        color: item.usingCustomerPrice
                            ? const Color(0xFF065F46)
                            : null,
                        fontWeight: item.usingCustomerPrice
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      decoration: InputDecoration(
                        prefix: const Text('Rs ',
                            style: TextStyle(fontSize: 11)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: item.usingCustomerPrice
                                ? const Color(0xFF10B981)
                                : const Color(0xFFD1D5DB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: item.usingCustomerPrice
                                ? const Color(0xFF10B981).withOpacity(0.5)
                                : const Color(0xFFD1D5DB),
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final parsed = double.tryParse(v);
                        if (parsed != null) {
                          setState(
                                  () => _cartItems[index].unitPrice = parsed);
                        }
                      },
                    ),
                  ),
                  if (showCustomBadge)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Std: Rs ${item.standardPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF9CA3AF),
                            decoration: TextDecoration.lineThrough),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              const Spacer(),
              QuantityInput(
                quantity: item.quantity,
                width: 70,
                onChanged: (newQty) {
                  setState(() {
                    _cartItems[index].quantity = newQty;
                  });
                },
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: Text(
                  'Rs ${item.total.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: item.usingCustomerPrice
                          ? const Color(0xFF10B981)
                          : const Color(0xFF7C3AED)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyCart() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shopping_cart_outlined,
            size: 48, color: Color(0xFFD1D5DB)),
        SizedBox(height: 12),
        Text('Cart is empty',
            style:
            TextStyle(fontSize: 15, color: Color(0xFF9CA3AF))),
        SizedBox(height: 4),
        Text('Add products using search',
            style:
            TextStyle(fontSize: 12, color: Color(0xFFD1D5DB))),
      ],
    ),
  );

  // ── CUSTOMER DISCOUNT CHECKBOX ───────────────

  Widget _buildCustomerDiscountCheckbox(bool usingCustomerDiscount) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: usingCustomerDiscount
            ? const Color(0xFFECFDF5)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: usingCustomerDiscount
              ? const Color(0xFF10B981).withOpacity(0.4)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Checkbox(
              value: usingCustomerDiscount,
              onChanged: (val) {
                if (val == true) {
                  _applyCustomerDiscount();
                } else {
                  setState(() {
                    _discountPercent = 0;
                    _discountAmount = 0;
                  });
                  _syncDiscountControllers();
                }
              },
              activeColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              side: const BorderSide(
                  color: Color(0xFF10B981), width: 1.5),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apply Customer Discount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: usingCustomerDiscount
                        ? const Color(0xFF065F46)
                        : const Color(0xFF374151),
                  ),
                ),
                Text(
                  usingCustomerDiscount
                      ? '${_selectedCustomer!.discountPercent.toStringAsFixed(1)}% applied'
                      : '${_selectedCustomer!.discountPercent.toStringAsFixed(1)}% off for ${_selectedCustomer!.name}',
                  style: TextStyle(
                      fontSize: 9,
                      color: usingCustomerDiscount
                          ? const Color(0xFF10B981)
                          : const Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
          if (usingCustomerDiscount)
            const Icon(Icons.verified, size: 14, color: Color(0xFF10B981))
          else
            const Icon(Icons.local_offer, size: 14, color: Color(0xFF9CA3AF)),
        ],
      ),
    );
  }

  void _applyCustomerDiscount() {
    if (_selectedCustomer == null) return;
    setState(() {
      _usePercentDiscount = true;
      _discountPercent = _selectedCustomer!.discountPercent;
    });
    // Sync controller text after setting the value programmatically.
    _syncDiscountControllers();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Applied ${_selectedCustomer!.discountPercent.toStringAsFixed(1)}% discount for ${_selectedCustomer!.name}',
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── SUMMARY + ACTION BUTTONS ──────────────────

  void _showPrintOptionsSheet(Uint8List pdfData) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Text(
              'Print Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _isPosMode ? 'POS Receipt Preview' : 'Invoice Preview',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildPrintOption(
                    icon: Icons.print,
                    label: 'Print',
                    color: const Color(0xFF7C3AED),
                    onTap: () {
                      Navigator.pop(ctx);
                      SalePdfGenerator.printPdf(pdfData);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPrintOption(
                    icon: Icons.share,
                    label: 'Share',
                    color: const Color(0xFF10B981),
                    onTap: () {
                      Navigator.pop(ctx);
                      final filename = _isPosMode
                          ? 'receipt_preview.pdf'
                          : 'invoice_preview.pdf';
                      SalePdfGenerator.sharePdf(pdfData, filename);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _buildPrintOption(
                icon: Icons.visibility,
                label: 'Preview',
                color: const Color(0xFF3B82F6),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPdfPreview(pdfData);
                },
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPdfPreview(Uint8List pdfData) async {
    await Printing.layoutPdf(
      onLayout: (_) => pdfData,
    );
  }

  Future<void> _showQuickPrintPreview() async {
    if (_cartItems.isEmpty || _selectedCustomer == null) return;

    final items = _cartItems.map((item) => {
      'product_name': item.product.itemName,
      'quantity': item.quantity,
      'unit_price': item.unitPrice,
    }).toList();

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final pdfData = await SalePdfGenerator.generateSalePdf(
        saleData: {'invoice_number': 'PREVIEW-${DateTime.now().millisecondsSinceEpoch}'},
        customer: _selectedCustomer,
        items: items,
        subtotal: _subtotal,
        discountValue: _discountValue,
        grandTotal: _grandTotal,
        isPosMode: _isPosMode,
        paymentMethod: 'preview',
        amountPaid: _grandTotal,
        dueDate: null,
        notes: _invoiceNoteController.text,
      );

      if (mounted) Navigator.pop(context);
      _showPrintOptionsSheet(pdfData);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate preview: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSummarySection(bool isPOS) {
    final customCount =
        _cartItems.where((i) => i.usingCustomerPrice).length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _summaryRow('Subtotal', 'Rs ${_subtotal.toStringAsFixed(2)}'),
          if (_discountValue > 0)
            _summaryRow(
                'Discount', '- Rs ${_discountValue.toStringAsFixed(2)}',
                color: const Color(0xFF10B981)),
          if (_customerPriceSavings > 0)
            _summaryRow(
              'Customer Savings',
              '- Rs ${_customerPriceSavings.toStringAsFixed(2)}',
              color: const Color(0xFF10B981),
              icon: Icons.sell_outlined,
            ),
          const Divider(height: 16),
          _summaryRow('Total', 'Rs ${_grandTotal.toStringAsFixed(2)}',
              isBold: true, fontSize: 16),

          if (_useCustomerPrices && customCount > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.local_offer,
                      size: 13, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$customCount item${customCount != 1 ? 's' : ''} priced '
                          'for ${_selectedCustomer!.name}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF065F46),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          if (_cartItems.isNotEmpty && _selectedCustomer != null) ...[
            OutlinedButton.icon(
              onPressed: _showQuickPrintPreview,
              icon: const Icon(Icons.print_outlined, size: 16),
              label: const Text('Quick Print Preview',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                side: const BorderSide(color: Color(0xFF7C3AED)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
            const SizedBox(height: 8),
          ],

          if (isPOS)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed:
                    (_cartItems.isEmpty || _selectedCustomer == null)
                        ? null
                        : _processPayment,
                    icon: const Icon(Icons.payment, size: 16),
                    label: const Text('Charge',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed:
                    _cartItems.isEmpty ? null : _createInvoice,
                    icon: const Icon(Icons.receipt_long, size: 16),
                    label: const Text('Create Invoice',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool isBold = false,
        double fontSize = 13,
        Color? color,
        IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: 13, color: color ?? const Color(0xFF6B7280)),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: fontSize,
                  color: color ?? const Color(0xFF6B7280))),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight:
                  isBold ? FontWeight.bold : FontWeight.w600,
                  color: color ?? const Color(0xFF1E1E2D))),
        ],
      ),
    );
  }

  // ── INVOICE WIDGETS ───────────────────────────

  Widget _buildInvoiceMeta() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Invoice Details',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E2D))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetaField(
                  label: 'Invoice Date',
                  value: _formatDate(_invoiceDate),
                  icon: Icons.calendar_today,
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: context,
                        initialDate: _invoiceDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030));
                    if (picked != null)
                      setState(() => _invoiceDate = picked);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetaField(
                  label: 'Due Date (Optional)',
                  value: _dueDate != null
                      ? _formatDate(_dueDate!)
                      : 'Not set',
                  icon: Icons.event,
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ??
                            DateTime.now()
                                .add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030));
                    if (picked != null)
                      setState(() => _dueDate = picked);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaField(
      {required String label,
        required String value,
        required IconData icon,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF7C3AED)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF9CA3AF))),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItemsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Items',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E2D))),
                const Spacer(),
                if (_useCustomerPrices && _selectedCustomer != null)
                  _chip('Customer Prices Active',
                      const Color(0xFFECFDF5), const Color(0xFF065F46)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            color: const Color(0xFFF9FAFB),
            child: const Row(
              children: [
                Expanded(
                    flex: 4,
                    child: Text('#  Product',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280)))),
                Expanded(
                    child: Text('Qty',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280)))),
                Expanded(
                    child: Text('Price',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280)))),
                Expanded(
                    child: Text('Total',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280)))),
                SizedBox(width: 32),
              ],
            ),
          ),
          if (_cartItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: Text('No items added yet',
                      style: TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 14))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cartItems.length,
              separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              itemBuilder: (ctx, i) {
                final item = _cartItems[i];
                return Container(
                  color: item.usingCustomerPrice
                      ? const Color(0xFFF0FDF4)
                      : null,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            Text('${i + 1}. ',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF))),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.itemName,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                          FontWeight.w500)),
                                  if (item.usingCustomerPrice &&
                                      item.hasPriceDifference)
                                    Text(
                                        '${_selectedCustomer?.name ?? ''} price',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color:
                                            Color(0xFF10B981))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            QuantityInput(
                              quantity: item.quantity,
                              width: 70,
                              onChanged: (newQty) {
                                setState(() {
                                  _cartItems[i].quantity = newQty;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rs ${item.unitPrice.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: item.usingCustomerPrice
                                      ? const Color(0xFF10B981)
                                      : null,
                                  fontWeight:
                                  item.usingCustomerPrice
                                      ? FontWeight.w600
                                      : FontWeight.normal),
                            ),
                            if (item.usingCustomerPrice &&
                                item.hasPriceDifference)
                              Text(
                                'Rs ${item.standardPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF9CA3AF),
                                    decoration:
                                    TextDecoration.lineThrough),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Rs ${item.total.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: item.usingCustomerPrice
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF7C3AED),
                              fontSize: 13),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 16, color: Color(0xFFEF4444)),
                          padding: EdgeInsets.zero,
                          onPressed: () => _removeFromCart(i),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInvoiceNotes() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Notes / Terms',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E2D))),
          const SizedBox(height: 10),
          TextField(
            controller: _invoiceNoteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add notes or payment terms…',
              hintStyle: const TextStyle(
                  fontSize: 13, color: Color(0xFFB0B7C3)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  // ── DIALOGS ───────────────────────────────────

  void _showCustomerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CustomerPickerSheet(
        selectedCustomer: _selectedCustomer,
        onSelected: (c) async {
          Navigator.pop(ctx);
          setState(() => _selectedCustomer = c);
          if (_useCustomerPrices) await _fetchAndApplyCustomerPrices();
        },
        onAddNew: () {
          Navigator.pop(ctx);
          _showAddCustomerDialog();
        },
      ),
    );
  }

  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AddCustomerDialog(
        onCreated: (customer) async {
          setState(() => _selectedCustomer = customer);
          if (_useCustomerPrices) await _fetchAndApplyCustomerPrices();
        },
      ),
    );
  }

  void _showBarcodeScanDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Scan Barcode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Center(
                  child: Icon(Icons.qr_code_scanner,
                      size: 80, color: Color(0xFF7C3AED))),
            ),
            const SizedBox(height: 16),
            const Text(
              'Use a barcode scanner device or enter manually below',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter or scan barcode',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.qr_code),
              ),
              onSubmitted: (barcode) {
                Navigator.pop(ctx);
                _searchController.text = barcode;
                _onSearchChanged();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
        ],
      ),
    );
  }

  // ── SALE ACTIONS ──────────────────────────────

  void _processPayment() {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
          Text('Please select a customer before processing payment'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _PaymentDialog(
        total: _grandTotal,
        customerName: _selectedCustomer!.name,
        onConfirm: (method, amountReceived, paymentDetails) async {
          if (method == 'credit' && paymentDetails != null) {
            if (paymentDetails['due_date'] != null) {
              setState(() {
                _creditDueDate =
                    DateTime.parse(paymentDetails['due_date']);
              });
            }
          } else {
            setState(() => _creditDueDate = null);
          }

          await _submitSale(
            saleType: 'pos',
            paymentMethod: method,
            amountPaid: amountReceived,
            paymentDetails: paymentDetails,
          );
        },
      ),
    );
  }

  void _createInvoice() {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
          Text('Please select a customer for the invoice'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _PaymentDialog(
        total: _grandTotal,
        customerName: _selectedCustomer!.name,
        isInvoice: true,
        onConfirm: (method, amountReceived, paymentDetails) async {
          if (method == 'credit' && paymentDetails != null) {
            if (paymentDetails['due_date'] != null) {
              setState(() {
                _creditDueDate =
                    DateTime.parse(paymentDetails['due_date']);
              });
            }
          } else {
            setState(() => _creditDueDate = null);
          }

          Navigator.pop(ctx);
          await _submitSale(
            saleType: 'invoice',
            paymentMethod: method,
            amountPaid: amountReceived,
            paymentDetails: paymentDetails,
          );
        },
      ),
    );
  }

  void _showPrintDialog(Uint8List pdfData, String invoiceNumber) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Document Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F0FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long,
                size: 40,
                color: Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your document has been created successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              invoiceNumber,
              style: const TextStyle(fontSize: 14, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 16),
            const Text(
              'What would you like to do?',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              SalePdfGenerator.sharePdf(pdfData, '$invoiceNumber.pdf');
            },
            child: const Text('Share'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              SalePdfGenerator.printPdf(pdfData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Print'),
          ),
        ],
      ),
    );
  }


  Future<void> _submitSale({
    required String saleType,
    required String paymentMethod,
    required double amountPaid,
    Map<String, dynamic>? paymentDetails,
  })
  async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
      const Center(child: CircularProgressIndicator()),
    );

    final bool isCredit = paymentMethod == 'credit';
    final finalAmountPaid = isCredit ? 0.0 : amountPaid;
    String? paymentStatus;
    if (isCredit) paymentStatus = 'unpaid';

    double discountAmount = 0;
    if (_usePercentDiscount) {
      discountAmount = _subtotal * (_discountPercent / 100);
    } else {
      discountAmount = _discountAmount;
    }
    discountAmount = discountAmount.clamp(0, _subtotal);

    final saleData = {
      'sale_type': saleType,
      'customer_id': _selectedCustomer?.id,
      'sale_date': _invoiceDate.toIso8601String().split('T').first,
      'due_date': isCredit && _creditDueDate != null
          ? _creditDueDate!.toIso8601String().split('T').first
          : _dueDate?.toIso8601String().split('T').first,
      'items': _cartItems
          .map((item) => {
        'product_id': item.product.id,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
      })
          .toList(),
      'discount_type':
      _usePercentDiscount ? 'percent' : 'fixed',
      'discount_value': _usePercentDiscount
          ? _discountPercent
          : _discountAmount,
      'payment_method': paymentMethod,
      'amount_paid': finalAmountPaid,
      'payment_status': paymentStatus,
      'notes': _buildNotes(paymentMethod, paymentDetails),
    };

    if (paymentDetails != null && !isCredit) {
      saleData['payment_details'] = paymentDetails;
    } else if (isCredit && paymentDetails != null) {
      saleData['credit_details'] = {
        'due_date': paymentDetails['due_date'],
        'notes': paymentDetails['notes'],
      };
    }

    final provider =
    Provider.of<SaleProvider>(context, listen: false);
    final result = await provider.createSale(saleData);

    if (mounted) Navigator.pop(context);

    if (result['success'] == true) {
      final resultData = result['data'] as Map<String, dynamic>;
      final invoiceNumber = resultData['invoice_number'] ?? 'N/A';

      final items = _cartItems.map((item) => {
        'product_name': item.product.itemName,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
      }).toList();

      try {
        final pdfData = await SalePdfGenerator.generateSalePdf(
          saleData: {'invoice_number': invoiceNumber},
          customer: _selectedCustomer,
          items: items,
          subtotal: _subtotal,
          discountValue: _discountValue,
          grandTotal: _grandTotal,
          isPosMode: _isPosMode,
          paymentMethod: paymentMethod,
          amountPaid: finalAmountPaid,
          dueDate: isCredit && _creditDueDate != null ? _creditDueDate : _dueDate,
          notes: _buildNotes(paymentMethod, paymentDetails),
        );

        if (mounted) {
          Navigator.pop(context);
          _clearCart();

          String message;
          if (isCredit) {
            message = _isPosMode ? 'Credit sale created successfully!' : 'Credit invoice created successfully!';
          } else {
            message = _isPosMode ? 'Sale completed successfully!' : 'Invoice created successfully!';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: isCredit ? const Color(0xFF7C3AED) : const Color(0xFF10B981),
              duration: const Duration(seconds: 2),
            ),
          );

          _showPrintDialog(pdfData, invoiceNumber);
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          _clearCart();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sale saved but PDF generation failed: $e'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                result['message'] ?? 'Failed to save sale'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  String _buildNotes(
      String paymentMethod, Map<String, dynamic>? paymentDetails)
  {
    final List<String> notesParts = [];

    if (_invoiceNoteController.text.trim().isNotEmpty) {
      notesParts.add(_invoiceNoteController.text.trim());
    }

    if (paymentMethod == 'credit' && paymentDetails != null) {
      if (paymentDetails['notes'] != null &&
          paymentDetails['notes'].toString().trim().isNotEmpty) {
        notesParts.add('Credit Note: ${paymentDetails['notes']}');
      }
      if (paymentDetails['due_date'] != null) {
        final dueDate = DateTime.parse(paymentDetails['due_date']);
        notesParts.add(
            'Due Date: ${DateFormat('dd/MM/yyyy').format(dueDate)}');
      }
    }

    return notesParts.isNotEmpty ? notesParts.join('\n') : '';
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

// ═════════════════════════════════════════════════════════════════
//  CUSTOMER PICKER SHEET
// ═════════════════════════════════════════════════════════════════

class _CustomerPickerSheet extends StatefulWidget {
  final Customer? selectedCustomer;
  final ValueChanged<Customer> onSelected;
  final VoidCallback onAddNew;

  const _CustomerPickerSheet(
      {required this.selectedCustomer,
        required this.onSelected,
        required this.onAddNew});

  @override
  State<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState
    extends State<_CustomerPickerSheet> {
  final TextEditingController _searchCtrl =
  TextEditingController();
  List<Customer> _filtered = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers([String query = '']) async {
    setState(() => _loading = true);
    try {
      final provider =
      Provider.of<CustomerProvider>(context, listen: false);
      await provider.fetchCustomers(search: query);
      if (mounted) {
        setState(() {
          _filtered = provider.customers;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2)),
                ),
                Row(
                  children: [
                    const Text('Select Customer',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: widget.onAddNew,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New'),
                      style: TextButton.styleFrom(
                          foregroundColor:
                          const Color(0xFF7C3AED)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search customers…',
                    prefixIcon:
                    const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(10)),
                    isDense: true,
                    contentPadding:
                    const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: _loadCustomers,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? const Center(
                child: Text('No customers found',
                    style: TextStyle(
                        color: Color(0xFF9CA3AF))))
                : ListView.builder(
              controller: scrollCtrl,
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final c = _filtered[i];
                final sel = widget
                    .selectedCustomer?.id ==
                    c.id;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                    const Color(0xFFF3F0FF),
                    child: Text(
                      c.name.isNotEmpty
                          ? c.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Color(0xFF7C3AED),
                          fontWeight:
                          FontWeight.bold),
                    ),
                  ),
                  title: Text(c.name,
                      style: const TextStyle(
                          fontWeight:
                          FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(c.contact),
                      if (c.discountPercent > 0)
                        Text(
                          '${c.discountPercent.toStringAsFixed(1)}% discount',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF7C3AED),
                            fontWeight:
                            FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  trailing: sel
                      ? const Icon(
                      Icons.check_circle,
                      color: Color(0xFF7C3AED))
                      : null,
                  onTap: () =>
                      widget.onSelected(c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  ADD CUSTOMER DIALOG
// ═════════════════════════════════════════════════════════════════

class _AddCustomerDialog extends StatefulWidget {
  final ValueChanged<Customer> onCreated;
  const _AddCustomerDialog({required this.onCreated});

  @override
  State<_AddCustomerDialog> createState() =>
      _AddCustomerDialogState();
}

class _AddCustomerDialogState
    extends State<_AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  String _type = 'regular';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final provider =
      Provider.of<CustomerProvider>(context, listen: false);
      final discountPercent =
          double.tryParse(_discountCtrl.text.trim()) ?? 0.0;

      final result = await provider.createCustomer(
        name: _nameCtrl.text.trim(),
        contact: _contactCtrl.text.trim(),
        address: _addressCtrl.text.trim().isNotEmpty
            ? _addressCtrl.text.trim()
            : null,
        email: _emailCtrl.text.trim().isNotEmpty
            ? _emailCtrl.text.trim()
            : null,
        customerType: _type,
        balance: 0,
        discountPercent: discountPercent,
      );

      if (result['success'] == true && mounted) {
        widget.onCreated(result['data'] as Customer);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Customer added successfully'),
              backgroundColor: Color(0xFF10B981)),
        );
      } else {
        throw Exception(result['message'] ?? 'Failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.person_add,
              color: Color(0xFF7C3AED), size: 22),
          SizedBox(width: 10),
          Text('Add New Customer',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E2D))),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Customer Name *',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter customer name';
                    }
                    if (v.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contactCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Contact Number *',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter contact number';
                    }
                    if (v.trim().length < 10) {
                      return 'Enter a valid contact number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final re = RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                      if (!re.hasMatch(v)) {
                        return 'Enter a valid email address';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(
                      labelText: 'Customer Type',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(
                        value: 'regular',
                        child: Row(children: [
                          const Icon(Icons.person,
                              color: Colors.blue, size: 18),
                          const SizedBox(width: 8),
                          const Text('Regular Customer'),
                        ])),
                    DropdownMenuItem(
                        value: 'retail',
                        child: Row(children: [
                          const Icon(Icons.shopping_cart,
                              color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          const Text('Retail Customer'),
                        ])),
                    DropdownMenuItem(
                        value: 'wholesale',
                        child: Row(children: [
                          const Icon(Icons.business,
                              color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          const Text('Wholesale Customer'),
                        ])),
                  ],
                  onChanged: (v) => setState(() => _type = v!),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _discountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Default Discount (%)',
                    hintText: 'e.g. 10 for 10% off',
                    prefixIcon: Icon(Icons.local_offer,
                        color: Color(0xFF7C3AED)),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                  const TextInputType.numberWithOptions(
                      decimal: true),
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final parsed = double.tryParse(v);
                      if (parsed == null) {
                        return 'Enter a valid number';
                      }
                      if (parsed < 0) {
                        return 'Discount cannot be negative';
                      }
                      if (parsed > 100) {
                        return 'Discount cannot exceed 100%';
                      }
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed:
            _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: _saving
              ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : const Text('Add Customer',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  PAYMENT DIALOG
// ═════════════════════════════════════════════════════════════════

class _PaymentDialog extends StatefulWidget {
  final double total;
  final String customerName;
  final bool isInvoice;
  final void Function(String method, double amount,
      Map<String, dynamic>? paymentDetails) onConfirm;

  const _PaymentDialog({
    required this.total,
    required this.customerName,
    this.isInvoice = false,
    required this.onConfirm,
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog>
    with SingleTickerProviderStateMixin {
  String _method = 'cash';
  final TextEditingController _receivedCtrl =
  TextEditingController();

  DateTime? _creditDueDate;
  final TextEditingController _creditNotesCtrl =
  TextEditingController();

  Bank? _selectedFromBank;
  Bank? _selectedToBank;
  final TextEditingController _bankDescriptionCtrl =
  TextEditingController();

  final TextEditingController _chequeNumberCtrl =
  TextEditingController();
  DateTime? _chequeDate;
  Bank? _selectedChequeBank;

  final TextEditingController _slipNumberCtrl =
  TextEditingController();
  DateTime? _slipDate;
  Bank? _selectedSlipBank;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  static const _methodColors = {
    'cash': Color(0xFF10B981),
    'bank': Color(0xFF3B82F6),
    'cheque': Color(0xFFF59E0B),
    'slip': Color(0xFF8B5CF6),
    'credit': Color(0xFF7C3AED),
  };

  static const _methodIcons = {
    'cash': Icons.payments_outlined,
    'bank': Icons.account_balance_outlined,
    'cheque': Icons.receipt_long_outlined,
    'slip': Icons.receipt_outlined,
    'credit': Icons.credit_card_outlined,
  };

  static const _methodLabels = {
    'cash': 'Cash',
    'bank': 'Bank',
    'cheque': 'Cheque',
    'slip': 'Slip',
    'credit': 'Credit',
  };

  @override
  void initState() {
    super.initState();
    _receivedCtrl.text = widget.total.toStringAsFixed(2);
    _animCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _receivedCtrl.dispose();
    _creditNotesCtrl.dispose();
    _bankDescriptionCtrl.dispose();
    _chequeNumberCtrl.dispose();
    _slipNumberCtrl.dispose();
    super.dispose();
  }

  Color get _activeColor =>
      _methodColors[_method] ?? const Color(0xFF10B981);
  double get _received =>
      double.tryParse(_receivedCtrl.text) ?? widget.total;
  double get _change =>
      (_received - widget.total).clamp(0, double.infinity);

  bool get _isValid {
    if (_method == 'cash') return _received >= widget.total;
    if (_method == 'bank') {
      return _selectedFromBank != null && _selectedToBank != null;
    }
    if (_method == 'cheque') {
      return _selectedChequeBank != null &&
          _chequeNumberCtrl.text.trim().isNotEmpty &&
          _chequeDate != null;
    }
    if (_method == 'slip') {
      return _selectedSlipBank != null &&
          _slipNumberCtrl.text.trim().isNotEmpty &&
          _slipDate != null;
    }
    if (_method == 'credit') return true;
    return false;
  }

  Future<void> _pickDate(DateTime? currentDate,
      Function(DateTime) onSelected) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
          ColorScheme.light(primary: _activeColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) onSelected(picked);
  }

  Future<void> _openBankPicker({
    required String title,
    required Function(Bank) onSelected,
    Bank? currentSelection,
  }) async {
    final result = await showModalBottomSheet<Bank>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PaymentBankSheet(
        title: title,
        selected: currentSelection,
        accentColor: _activeColor,
      ),
    );
    if (result != null) onSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Padding(
                padding:
                const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCustomerInfo(),
                    const SizedBox(height: 20),
                    _buildMethodSelector(),
                    const SizedBox(height: 20),
                    if (_method == 'cash') _buildCashFields(),
                    if (_method == 'bank') _buildBankFields(),
                    if (_method == 'cheque')
                      _buildChequeFields(),
                    if (_method == 'slip') _buildSlipFields(),
                    if (_method == 'credit')
                      _buildCreditFields(),
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
      decoration: BoxDecoration(
        color: _activeColor.withOpacity(0.06),
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
            bottom: BorderSide(
                color: _activeColor.withOpacity(0.15))),
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
            child: Icon(_methodIcons[_method],
                color: _activeColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isInvoice
                      ? 'Create Invoice'
                      : 'Process Payment',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Select payment method',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF8E8E93)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _activeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border:
        Border.all(color: _activeColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person,
              color: Color(0xFF7C3AED), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.customerName,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Text(
            'Rs ${widget.total.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _activeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodSelector() {
    final methods = ['cash', 'bank', 'cheque', 'slip', 'credit'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method *',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8E8E93)),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: methods.map((method) {
              final selected = _method == method;
              final color = _methodColors[method]!;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _method = method;
                    _selectedFromBank = null;
                    _selectedToBank = null;
                    _selectedChequeBank = null;
                    _selectedSlipBank = null;
                    _creditDueDate = null;
                    _chequeNumberCtrl.clear();
                    _slipNumberCtrl.clear();
                    _bankDescriptionCtrl.clear();
                    _creditNotesCtrl.clear();
                    _chequeDate = null;
                    _slipDate = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withOpacity(0.1)
                          : const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? color
                            : const Color(0xFFE5E5EA),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _methodIcons[method],
                          size: 18,
                          color: selected
                              ? color
                              : const Color(0xFF8E8E93),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _methodLabels[method]!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: selected
                                ? color
                                : const Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCashFields() {
    return Column(
      children: [
        TextField(
          controller: _receivedCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Amount Received',
            labelStyle: const TextStyle(
                fontSize: 12, color: Color(0xFF8E8E93)),
            prefixText: 'Rs ',
            prefixStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _activeColor),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
              BorderSide(color: _activeColor, width: 1.5),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        if (_received >= widget.total)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text(
                  'Change',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981)),
                ),
                const Spacer(),
                Text(
                  'Rs ${_change.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981)),
                ),
              ],
            ),
          )
        else if (_received < widget.total && _received > 0)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: Color(0xFF92400E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Short by Rs ${(widget.total - _received).toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBankFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBankSelector(
          label: 'From Bank *',
          selectedBank: _selectedFromBank,
          onTap: () => _openBankPicker(
            title: 'Select Source Bank',
            onSelected: (bank) =>
                setState(() => _selectedFromBank = bank),
            currentSelection: _selectedFromBank,
          ),
        ),
        const SizedBox(height: 12),
        _buildBankSelector(
          label: 'To Bank *',
          selectedBank: _selectedToBank,
          onTap: () => _openBankPicker(
            title: 'Select Destination Bank',
            onSelected: (bank) =>
                setState(() => _selectedToBank = bank),
            currentSelection: _selectedToBank,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bankDescriptionCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Description (optional)',
            labelStyle: const TextStyle(
                fontSize: 12, color: Color(0xFF8E8E93)),
            hintText: 'e.g. Transfer for invoice payment',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
              BorderSide(color: _activeColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChequeFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBankSelector(
          label: 'Bank *',
          selectedBank: _selectedChequeBank,
          onTap: () => _openBankPicker(
            title: 'Select Bank',
            onSelected: (bank) =>
                setState(() => _selectedChequeBank = bank),
            currentSelection: _selectedChequeBank,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chequeNumberCtrl,
                decoration: InputDecoration(
                  labelText: 'Cheque Number *',
                  labelStyle: const TextStyle(
                      fontSize: 12, color: Color(0xFF8E8E93)),
                  hintText: 'e.g. 001234',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: _activeColor, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _pickDate(_chequeDate,
                        (date) => setState(() => _chequeDate = date)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: _chequeDate != null
                        ? _activeColor.withOpacity(0.05)
                        : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _chequeDate != null
                          ? _activeColor.withOpacity(0.3)
                          : const Color(0xFFE5E5EA),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: _chequeDate != null
                            ? _activeColor
                            : Colors.grey[400],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _chequeDate != null
                              ? DateFormat('MMM dd, yyyy')
                              .format(_chequeDate!)
                              : 'Cheque Date *',
                          style: TextStyle(
                            fontSize: 13,
                            color: _chequeDate != null
                                ? const Color(0xFF1C1C1E)
                                : const Color(0xFFC7C7CC),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSlipFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBankSelector(
          label: 'Bank *',
          selectedBank: _selectedSlipBank,
          onTap: () => _openBankPicker(
            title: 'Select Bank',
            onSelected: (bank) =>
                setState(() => _selectedSlipBank = bank),
            currentSelection: _selectedSlipBank,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _slipNumberCtrl,
                decoration: InputDecoration(
                  labelText: 'Slip Number *',
                  labelStyle: const TextStyle(
                      fontSize: 12, color: Color(0xFF8E8E93)),
                  hintText: 'e.g. SLIP-001',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: _activeColor, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _pickDate(_slipDate,
                        (date) => setState(() => _slipDate = date)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: _slipDate != null
                        ? _activeColor.withOpacity(0.05)
                        : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _slipDate != null
                          ? _activeColor.withOpacity(0.3)
                          : const Color(0xFFE5E5EA),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: _slipDate != null
                            ? _activeColor
                            : Colors.grey[400],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _slipDate != null
                              ? DateFormat('MMM dd, yyyy')
                              .format(_slipDate!)
                              : 'Slip Date *',
                          style: TextStyle(
                            fontSize: 13,
                            color: _slipDate != null
                                ? const Color(0xFF1C1C1E)
                                : const Color(0xFFC7C7CC),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCreditFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color:
                const Color(0xFF7C3AED).withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline,
                  size: 18, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No payment will be collected now. The amount will be added to customer balance.',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF1C1C1E)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _creditDueDate ??
                  DateTime.now()
                      .add(const Duration(days: 30)),
              firstDate: DateTime.now(),
              lastDate:
              DateTime.now().add(const Duration(days: 365)),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(
                      primary: Color(0xFF7C3AED)),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              setState(() => _creditDueDate = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: _creditDueDate != null
                  ? const Color(0xFFF5F3FF)
                  : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _creditDueDate != null
                    ? const Color(0xFF7C3AED).withOpacity(0.3)
                    : const Color(0xFFE5E5EA),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 20,
                  color: _creditDueDate != null
                      ? const Color(0xFF7C3AED)
                      : Colors.grey[400],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Due Date (Optional)',
                        style: TextStyle(
                          fontSize: 12,
                          color: _creditDueDate != null
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFF8E8E93),
                        ),
                      ),
                      Text(
                        _creditDueDate != null
                            ? DateFormat('MMM dd, yyyy')
                            .format(_creditDueDate!)
                            : 'Set due date for payment',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _creditDueDate != null
                              ? const Color(0xFF1C1C1E)
                              : const Color(0xFFC7C7CC),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_creditDueDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear,
                        size: 16, color: Color(0xFF8E8E93)),
                    onPressed: () =>
                        setState(() => _creditDueDate = null),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _creditNotesCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Notes (optional)',
            labelStyle: const TextStyle(
                fontSize: 12, color: Color(0xFF8E8E93)),
            hintText:
            'Add any notes about this credit sale...',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFF7C3AED), width: 1.5),
            ),
          ),
        ),
      ],
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
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8E8E93)),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selectedBank != null
                  ? _activeColor.withOpacity(0.05)
                  : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selectedBank != null
                    ? _activeColor.withOpacity(0.4)
                    : const Color(0xFFE5E5EA),
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
                        color: _activeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedBank.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(Icons.check_circle_rounded,
                      color: _activeColor, size: 18),
                ] else ...[
                  Icon(Icons.account_balance_outlined,
                      size: 20, color: Colors.grey[400]),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Select bank',
                      style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFC7C7CC)),
                    ),
                  ),
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

  Widget _buildSubmitButton() {
    String buttonText =
    widget.isInvoice ? 'Create Invoice' : 'Confirm Payment';
    if (_method == 'credit') {
      buttonText = widget.isInvoice
          ? 'Create Credit Invoice'
          : 'Process on Credit';
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [_activeColor, _activeColor.withOpacity(0.75)],
          ),
          boxShadow: [
            BoxShadow(
              color: _activeColor.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed:
          _isValid ? () => _confirmPayment() : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _method == 'credit'
                    ? Icons.credit_score
                    : (widget.isInvoice
                    ? Icons.receipt_long
                    : Icons.check_circle_outline),
                color: _isValid
                    ? Colors.white
                    : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                buttonText,
                style: TextStyle(
                  color: _isValid
                      ? Colors.white
                      : Colors.grey.shade600,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmPayment() {
    Map<String, dynamic>? paymentDetails;

    switch (_method) {
      case 'cash':
        paymentDetails = {
          'amount_received': _received,
          'change': _change,
        };
        break;
      case 'bank':
        paymentDetails = {
          'from_bank': _selectedFromBank?.name,
          'to_bank': _selectedToBank?.name,
          'description': _bankDescriptionCtrl.text.trim(),
        };
        break;
      case 'cheque':
        paymentDetails = {
          'bank': _selectedChequeBank?.name,
          'cheque_number': _chequeNumberCtrl.text.trim(),
          'cheque_date': _chequeDate?.toIso8601String(),
        };
        break;
      case 'slip':
        paymentDetails = {
          'bank': _selectedSlipBank?.name,
          'slip_number': _slipNumberCtrl.text.trim(),
          'slip_date': _slipDate?.toIso8601String(),
        };
        break;
      case 'credit':
        paymentDetails = {
          'payment_method': 'credit',
          'due_date': _creditDueDate?.toIso8601String(),
          'notes': _creditNotesCtrl.text.trim(),
        };
        break;
    }

    final amountPaid =
    _method == 'credit' ? 0.0 : _received;
    widget.onConfirm(_method, amountPaid, paymentDetails);
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
  State<_PaymentBankSheet> createState() =>
      _PaymentBankSheetState();
}

class _PaymentBankSheetState
    extends State<_PaymentBankSheet> {
  final TextEditingController _searchCtrl =
  TextEditingController();
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
          .where((bank) =>
          bank.name.toLowerCase().contains(query))
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
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
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
              prefixIcon:
              const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F5F7),
              contentPadding:
              const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredBanks.length,
              itemBuilder: (context, index) {
                final bank = _filteredBanks[index];
                final isSelected =
                    widget.selected?.name == bank.name;

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
                          color: widget.accentColor
                              .withOpacity(0.1),
                          borderRadius:
                          BorderRadius.circular(8),
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
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? widget.accentColor
                          : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle,
                      color: widget.accentColor)
                      : null,
                  onTap: () =>
                      Navigator.pop(context, bank),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}