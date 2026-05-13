// lib/screens/products/add_edit_product_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/subcategory_provider.dart';
import '../../providers/unit_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../models/product_model.dart';
import 'dart:math';


class AddEditProductScreen extends StatefulWidget {
  final int? productId;

  const AddEditProductScreen({super.key, this.productId});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _minStockController = TextEditingController();
  final _physicalQtyController = TextEditingController();

  // Selected values - CHANGED FROM int? TO String?
  String? _selectedSupplierId;      // Changed
  String? _selectedCategoryId;      // Changed
  String? _selectedSubcategoryId;   // Changed
  String? _selectedUnitId;          // Changed
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.productId == null) {
      _barcodeController.text = _generateBarcode();
    }
    // Rebuild preview when barcode text changes
    _barcodeController.addListener(() => setState(() {}));
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _costPriceController.dispose();
    _salePriceController.dispose();
    _barcodeController.dispose();
    _minStockController.dispose();
    _physicalQtyController.dispose();
    super.dispose();
  }

  String _generateBarcode() {
    final random = Random();
    // Generate 8-digit numeric barcode
    final barcode = List.generate(8, (_) => random.nextInt(10)).join();
    return barcode;
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      // Load required data
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      final unitProvider = Provider.of<UnitProvider>(context, listen: false);
      final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);

      await Future.wait([
        categoryProvider.loadCategories(),
        unitProvider.loadUnits(),
        supplierProvider.fetchSuppliers(context: context),
      ]);

      // If editing, load product data
      if (widget.productId != null) {
        final productProvider = Provider.of<ProductProvider>(context, listen: false);
        final result = await productProvider.fetchProductById(widget.productId!);

        if (result['success'] && result['data'] != null) {
          final product = result['data'] as ProductModel;
          _populateForm(product);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _populateForm(ProductModel product) {
    _nameController.text = product.itemName;
    _descriptionController.text = product.description ?? '';
    _costPriceController.text = product.costPrice.toString();
    _salePriceController.text = product.salePrice.toString();
    _barcodeController.text = product.barcode ?? '';
    _minStockController.text = product.minStock.toString();
    _physicalQtyController.text = product.physicalQty.toString();

    setState(() {
      // Convert int IDs to String if needed
      _selectedSupplierId = product.supplierId?.toString();
      _selectedCategoryId = product.categoryId.toString(); // categoryId is required, so no null check needed
      _selectedSubcategoryId = product.subcategoryId?.toString();
      _selectedUnitId = product.unitId.toString(); // unitId is required
      _isActive = product.isActive;
    });

    // Load subcategories for the selected category
    if (product.categoryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final subcategoryProvider = Provider.of<SubcategoryProvider>(context, listen: false);
        subcategoryProvider.fetchSubcategoriesByCategory(int.parse(product.categoryId.toString()));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.productId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Product' : 'Add Product',
          style: const TextStyle(
            color: Color(0xFF2D3142),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProduct,
            child: Text(
              'Save',
              style: TextStyle(
                color: _isLoading ? Colors.grey : const Color(0xFF7C3AED),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfoSection(),
              const SizedBox(height: 20),
              _buildPricingSection(),
              const SizedBox(height: 20),
              _buildStockSection(),
              const SizedBox(height: 20),
              _buildCategorySection(),
              const SizedBox(height: 20),
              _buildAdditionalSection(),
              const SizedBox(height: 20),
              if (isEditing) _buildStatusSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSection(
      'Basic Information',
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Product Name *',
            hintText: 'Enter product name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.inventory_2),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Product name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'Enter product description',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.description),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Consumer<SupplierProvider>(
          builder: (context, provider, child) {
            return DropdownButtonFormField<String?>(
              value: _selectedSupplierId,
              decoration: const InputDecoration(
                labelText: 'Supplier',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Select Supplier'),
                ),
                ...provider.suppliers.map((s) => DropdownMenuItem<String?>(
                  value: s.id.toString(), // Convert to String
                  child: Text(s.name),
                )),
              ],
              onChanged: (value) {
                setState(() => _selectedSupplierId = value);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPricingSection() {
    return _buildSection(
      'Pricing Information',
      children: [
        TextFormField(
          controller: _costPriceController,
          decoration: const InputDecoration(
            labelText: 'Cost Price *',
            hintText: '0.00',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Cost price is required';
            }
            if (double.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _salePriceController,
          decoration: const InputDecoration(
            labelText: 'Sale Price *',
            hintText: '0.00',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Sale price is required';
            }
            if (double.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildStockSection() {
    return _buildSection(
      'Stock Information',
      children: [
        TextFormField(
          controller: _physicalQtyController,
          decoration: const InputDecoration(
            labelText: 'Physical Quantity *',
            hintText: '0',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.inventory),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Quantity is required';
            }
            if (int.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _minStockController,
          decoration: const InputDecoration(
            labelText: 'Minimum Stock Level *',
            hintText: '0',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.warning),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Minimum stock is required';
            }
            if (int.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    return _buildSection(
      'Category Information',
      children: [
        Consumer<CategoryProvider>(
          builder: (context, provider, child) {
            return DropdownButtonFormField<String?>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Category *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Select Category'),
                ),
                ...provider.categories.map((c) => DropdownMenuItem<String?>(
                  value: c.id, // c.id is already String
                  child: Text(c.name),
                )),
              ],
              onChanged: (value) async {
                setState(() {
                  _selectedCategoryId = value;
                  _selectedSubcategoryId = null;
                });

                if (value != null) {
                  final subcategoryProvider = Provider.of<SubcategoryProvider>(context, listen: false);
                  await subcategoryProvider.fetchSubcategoriesByCategory(int.parse(value));
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Category is required';
                }
                return null;
              },
            );
          },
        ),
        const SizedBox(height: 16),
        Consumer<SubcategoryProvider>(
          builder: (context, provider, child) {
            return DropdownButtonFormField<String?>(
              value: _selectedSubcategoryId,
              decoration: const InputDecoration(
                labelText: 'Subcategory',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Select Subcategory'),
                ),
                ...provider.subcategories.map((s) => DropdownMenuItem<String?>(
                  value: s.id, // s.id is String
                  child: Text(s.name),
                )),
              ],
              onChanged: (value) {
                setState(() => _selectedSubcategoryId = value);
              },
            );
          },
        ),
        const SizedBox(height: 16),
        Consumer<UnitProvider>(
          builder: (context, provider, _) {
            return FormField<String>(
              validator: (v) =>
              (_selectedUnitId == null || _selectedUnitId!.isEmpty)
                  ? 'Unit is required'
                  : null,
              builder: (fieldState) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () async {
                      final result = await showDialog<String>(
                        context: context,
                        builder: (ctx) => _UnitSearchDialog(
                          units: provider.units,
                          selectedId: _selectedUnitId,
                        ),
                      );
                      if (result != null) {
                        setState(() => _selectedUnitId = result);
                        fieldState.didChange(result);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Unit *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.square_foot),
                        errorText: fieldState.errorText,
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_selectedUnitId != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() => _selectedUnitId = null);
                                  fieldState.didChange(null);
                                },
                              ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                      child: Text(
                        _selectedUnitId != null
                            ? () {
                          try {
                            final unit = provider.units.firstWhere(
                                  (u) => u.id == _selectedUnitId,
                            );
                            return '${unit.name} (${unit.symbol})';
                          } catch (e) {
                            return 'Select Unit';
                          }
                        }()
                            : 'Select Unit',
                        style: TextStyle(
                          color: _selectedUnitId != null
                              ? const Color(0xFF2D3142)
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAdditionalSection() {
    return _buildSection(
      'Additional Information',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(
                  labelText: 'Barcode',
                  hintText: '8-digit barcode',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code),
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                maxLength: 8,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (value.length != 8) {
                      return 'Barcode must be exactly 8 digits';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Barcode must be numeric';
                    }
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _barcodeController.text = _generateBarcode();
                  });
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Generate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Barcode preview
        if (_barcodeController.text.isNotEmpty &&
            _barcodeController.text.length == 8)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE0E0E5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_2, color: Color(0xFF7C3AED), size: 20),
                const SizedBox(width: 8),
                Text(
                  _barcodeController.text,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: Color(0xFF2D3142),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatusSection() {
    return _buildSection(
      'Status',
      children: [
        SwitchListTile(
          title: const Text('Active'),
          subtitle: const Text('Product is available for sale'),
          value: _isActive,
          onChanged: (value) {
            setState(() => _isActive = value);
          },
          activeColor: const Color(0xFF7C3AED),
        ),
      ],
    );
  }

  Widget _buildSection(String title, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    if (_selectedUnitId == null || _selectedUnitId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a unit')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final productData = {
      'item_name': _nameController.text,
      'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
      'cost_price': double.parse(_costPriceController.text),
      'sale_price': double.parse(_salePriceController.text),
      'supplier_id': _selectedSupplierId != null ? int.tryParse(_selectedSupplierId!) : null, // Convert back to int if needed
      'category_id': int.parse(_selectedCategoryId!), // Convert back to int
      'subcategory_id': _selectedSubcategoryId != null ? int.tryParse(_selectedSubcategoryId!) : null,
      'unit_id': int.parse(_selectedUnitId!), // Convert back to int
      'barcode': _barcodeController.text.isEmpty ? null : _barcodeController.text,
      'min_stock': int.parse(_minStockController.text),
      'physical_qty': int.parse(_physicalQtyController.text),
      if (widget.productId != null) 'is_active': _isActive,
    };

    try {
      final provider = Provider.of<ProductProvider>(context, listen: false);
      Map<String, dynamic> result;

      if (widget.productId != null) {
        result = await provider.updateProduct(widget.productId!, productData);
      } else {
        result = await provider.createProduct(productData);
      }

      if (result['success'] && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.productId != null
                ? 'Product updated successfully'
                : 'Product created successfully'),
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(result['error'] ?? 'Failed to save product');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────
// Unit widget
// ─────────────────────────────────────────────

class _UnitSearchDialog extends StatefulWidget {
  final List<dynamic> units;
  final String? selectedId;

  const _UnitSearchDialog({required this.units, this.selectedId});

  @override
  State<_UnitSearchDialog> createState() => _UnitSearchDialogState();
}

class _UnitSearchDialogState extends State<_UnitSearchDialog> {
  final _searchController = TextEditingController();
  List<dynamic> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.units;
    _searchController.addListener(() {
      final q = _searchController.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? widget.units
            : widget.units
            .where((u) =>
        u.name.toLowerCase().contains(q) ||
            u.symbol.toLowerCase().contains(q))
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
            child: Row(
              children: [
                const Icon(Icons.square_foot, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Select Unit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search units...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF7C3AED)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF7C3AED)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 12),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => _searchController.clear(),
                )
                    : null,
              ),
            ),
          ),
          // List
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: _filtered.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No units found',
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 16),
              itemBuilder: (context, index) {
                final unit = _filtered[index];
                final isSelected = unit.id == widget.selectedId;
                return ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFFEDE9FB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unit.symbol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                  title: Text(
                    unit.name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: const Color(0xFF2D3142),
                    ),
                  ),
                  subtitle: Text(
                    'Symbol: ${unit.symbol}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle,
                      color: Color(0xFF7C3AED))
                      : null,
                  onTap: () => Navigator.pop(context, unit.id),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
