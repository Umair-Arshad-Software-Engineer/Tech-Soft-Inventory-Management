// lib/providers/product_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/product_model.dart';

class ProductProvider with ChangeNotifier {
  List<ProductModel> _products = [];
  ProductModel? _selectedProduct;
  bool _isLoading = false;
  String? _errorMessage;

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalProducts = 0;
  int _itemsPerPage = 20;

  // Filters
  String? _searchQuery;
  int? _supplierFilter;
  int? _categoryFilter;
  int? _subcategoryFilter;
  int? _unitFilter;
  bool? _lowStockFilter;
  bool? _activeFilter;

  List<ProductModel> get products => _products;
  ProductModel? get selectedProduct => _selectedProduct;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalProducts => _totalProducts;

  // Summary stats
  int get lowStockCount =>
      _products.where((p) => p.physicalQty <= p.minStock).length;
  double get totalInventoryValue {
    return _products.fold(
        0, (sum, product) => sum + (product.costPrice * product.physicalQty));
  }

  // ─────────────────────────────────────────────
  //  SEARCH PRODUCTS (for Sale / POS screen)
  //  Searches by item_name OR barcode, returns
  //  only active products.
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> searchProducts(String query) async {
    if (query.trim().isEmpty) {
      return {'success': true, 'data': <ProductModel>[]};
    }

    try {
      final queryParams = <String, String>{
        'search': query.trim(),
        'active': 'true',
        'limit': '20',
        'page': '1',
      };

      final uri = Uri.parse(ApiConfig.productsUrl)
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          final List<dynamic> productsJson = jsonResponse['data'];
          final results =
          productsJson.map((j) => ProductModel.fromJson(j)).toList();
          return {'success': true, 'data': results};
        } else {
          throw Exception(
              jsonResponse['message'] ?? 'Failed to search products');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'data': <ProductModel>[]};
    }
  }

  // ─────────────────────────────────────────────
  //  FETCH PRODUCT BY BARCODE (for barcode scan)
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchProductByBarcode(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.productByBarcodeUrl(barcode)),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          final product = ProductModel.fromJson(jsonResponse['data']);
          return {'success': true, 'data': product};
        } else {
          return {'success': false, 'error': 'Product not found'};
        }
      } else if (response.statusCode == 404) {
        return {'success': false, 'error': 'Product not found'};
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─────────────────────────────────────────────
  //  FETCH ALL (paginated + filtered)
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchProducts({
    int? page,
    String? search,
    int? supplierId,
    int? categoryId,
    int? subcategoryId,
    int? unitId,
    bool? lowStock,
    bool? active,
    bool refresh = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (refresh) _currentPage = 1;

      _searchQuery = search ?? _searchQuery;
      _supplierFilter = supplierId ?? _supplierFilter;
      _categoryFilter = categoryId ?? _categoryFilter;
      _subcategoryFilter = subcategoryId ?? _subcategoryFilter;
      _unitFilter = unitId ?? _unitFilter;
      _lowStockFilter = lowStock ?? _lowStockFilter;
      _activeFilter = active ?? _activeFilter;

      final queryParams = <String, String>{
        'page': (page ?? _currentPage).toString(),
        'limit': _itemsPerPage.toString(),
      };

      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        queryParams['search'] = _searchQuery!;
      }
      if (_supplierFilter != null) {
        queryParams['supplier_id'] = _supplierFilter.toString();
      }
      if (_categoryFilter != null) {
        queryParams['category_id'] = _categoryFilter.toString();
      }
      if (_subcategoryFilter != null) {
        queryParams['subcategory_id'] = _subcategoryFilter.toString();
      }
      if (_unitFilter != null) {
        queryParams['unit_id'] = _unitFilter.toString();
      }
      if (_lowStockFilter != null) {
        queryParams['low_stock'] = _lowStockFilter.toString();
      }
      if (_activeFilter != null) {
        queryParams['active'] = _activeFilter.toString();
      }

      final uri = Uri.parse(ApiConfig.productsUrl)
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['success']) {
          final List<dynamic> productsJson = jsonResponse['data'];
          _products =
              productsJson.map((json) => ProductModel.fromJson(json)).toList();

          final pagination = jsonResponse['pagination'];
          _totalProducts = pagination['total'];
          _currentPage = pagination['page'];
          _totalPages = pagination['pages'];

          _isLoading = false;
          notifyListeners();
          return {'success': true, 'data': _products};
        } else {
          throw Exception(
              jsonResponse['message'] ?? 'Failed to fetch products');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> fetchProductById(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.productUrl(id)),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success']) {
          _selectedProduct = ProductModel.fromJson(jsonResponse['data']);
          _isLoading = false;
          notifyListeners();
          return {'success': true, 'data': _selectedProduct};
        } else {
          throw Exception(jsonResponse['message'] ?? 'Product not found');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createProduct(
      Map<String, dynamic> productData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.productsUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(productData),
      );

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 201 && jsonResponse['success']) {
        await fetchProducts(refresh: true);
        _isLoading = false;
        notifyListeners();
        return {'success': true, 'data': jsonResponse['data']};
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to create product');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateProduct(
      int id, Map<String, dynamic> productData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse(ApiConfig.productUrl(id)),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(productData),
      );

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['success']) {
        _selectedProduct = ProductModel.fromJson(jsonResponse['data']);
        await fetchProducts(refresh: true);
        _isLoading = false;
        notifyListeners();
        return {'success': true, 'data': _selectedProduct};
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to update product');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteProduct(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.productUrl(id)),
        headers: {'Content-Type': 'application/json'},
      );

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['success']) {
        _products.removeWhere((p) => p.id == id);
        if (_selectedProduct?.id == id) _selectedProduct = null;
        _isLoading = false;
        notifyListeners();
        return {'success': true, 'message': jsonResponse['message']};
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to delete product');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> toggleProductStatus(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.patch(
        Uri.parse(ApiConfig.toggleProductStatusUrl(id)),
        headers: {'Content-Type': 'application/json'},
      );

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['success']) {
        final index = _products.indexWhere((p) => p.id == id);
        if (index != -1) {
          _products[index] = ProductModel.fromJson(jsonResponse['data']);
        }
        if (_selectedProduct?.id == id) {
          _selectedProduct = ProductModel.fromJson(jsonResponse['data']);
        }
        _isLoading = false;
        notifyListeners();
        return {'success': true, 'data': jsonResponse['data']};
      } else {
        throw Exception(
            jsonResponse['message'] ?? 'Failed to toggle status');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateProductQuantity(
      int id, int quantity, String operation) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.patch(
        Uri.parse(ApiConfig.updateProductQuantityUrl(id)),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'quantity': quantity, 'operation': operation}),
      );

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['success']) {
        final index = _products.indexWhere((p) => p.id == id);
        if (index != -1) {
          final updatedProduct = _products[index].copyWith(
            physicalQty: jsonResponse['data']['new_quantity'],
            availableQty: jsonResponse['data']['new_quantity'],
          );
          _products[index] = updatedProduct;
        }
        if (_selectedProduct?.id == id) {
          _selectedProduct = _selectedProduct!.copyWith(
            physicalQty: jsonResponse['data']['new_quantity'],
            availableQty: jsonResponse['data']['new_quantity'],
          );
        }
        _isLoading = false;
        notifyListeners();
        return {'success': true, 'data': jsonResponse['data']};
      } else {
        throw Exception(
            jsonResponse['message'] ?? 'Failed to update quantity');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  void clearFilters() {
    _searchQuery = null;
    _supplierFilter = null;
    _categoryFilter = null;
    _subcategoryFilter = null;
    _unitFilter = null;
    _lowStockFilter = null;
    _activeFilter = null;
    _currentPage = 1;
    notifyListeners();
  }

  void setPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      fetchProducts(page: page);
    }
  }

  void clearSelectedProduct() {
    _selectedProduct = null;
    notifyListeners();
  }
}