// lib/providers/damaged_stock_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/damaged_stock_model.dart';

class DamagedStockProvider extends ChangeNotifier {
  List<DamagedStockModel> _damagedItems = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  String? _statusFilter;
  String? _searchQuery;

  List<DamagedStockModel> get damagedItems => _damagedItems;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  String? get statusFilter => _statusFilter;

  // Statistics
  int get totalDamaged => _damagedItems.length;
  int get totalPending => _damagedItems.where((d) => d.status == 'pending').length;
  int get totalApproved => _damagedItems.where((d) => d.status == 'approved').length;
  int get totalDisposed => _damagedItems.where((d) => d.status == 'disposed').length;
  int get totalRepaired => _damagedItems.where((d) => d.status == 'repaired').length;

  double get totalLossValue {
    return _damagedItems.fold(0.0, (sum, item) => sum + item.lossAmount);
  }

  // Helper method to get auth headers
  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final headers = {
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<void> fetchDamagedItems({
    int? page,
    String? status,
    String? search,
    bool refresh = false,
  })
  async {
    if (refresh) {
      _currentPage = 1;
      _statusFilter = status;
      _searchQuery = search;
    }

    // Use page parameter if provided, otherwise use current page
    final pageToUse = page ?? _currentPage;

    // Use status parameter if provided, otherwise use current filter
    final statusToUse = status ?? _statusFilter;

    // Use search parameter if provided, otherwise use current search
    final searchToUse = search ?? _searchQuery;

    _setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final queryParams = <String, String>{
        'page': pageToUse.toString(),
        'limit': '20',
      };

      // Only add status if it's not null and not empty
      if (statusToUse != null && statusToUse.isNotEmpty) {
        queryParams['status'] = statusToUse;
      }

      // Only add search if it's not null and not empty
      if (searchToUse != null && searchToUse.isNotEmpty) {
        queryParams['search'] = searchToUse;
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/damaged-stock').replace(
        queryParameters: queryParams,
      );

      print('Fetching damaged stock from: $uri'); // Debug log

      final headers = await _getAuthHeaders();
      final response = await http.get(uri, headers: headers);

      print('Response status: ${response.statusCode}'); // Debug log
      print('Response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          final data = json['data'];

          // Handle the response structure correctly
          final items = data['items'] ?? data['data'] ?? [];

          _damagedItems = (items as List)
              .map((e) => DamagedStockModel.fromJson(e))
              .toList();

          _currentPage = data['pagination']?['page'] ?? data['current_page'] ?? 1;
          _totalPages = data['pagination']?['total_pages'] ?? data['total_pages'] ?? 1;
          _totalItems = data['pagination']?['total'] ?? data['total'] ?? _damagedItems.length;

          _setState(() => _isLoading = false);
        } else {
          _setState(() {
            _errorMessage = json['message'] ?? 'Failed to load damaged items';
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        _setState(() {
          _errorMessage = 'Session expired. Please login again.';
          _isLoading = false;
        });
      } else {
        _setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching damaged items: $e');
      _setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> addDamagedItem({
    required int productId,
    required int quantity,
    required String reason,
    String? notes,
    double? estimatedLoss,
  })
  async {
    _setState(() => _isLoading = true);

    try {
      final headers = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/damaged-stock'),
        headers: headers,
        body: jsonEncode({
          'product_id': productId,
          'quantity': quantity,
          'reason': reason,
          'notes': notes,
          'estimated_loss': estimatedLoss,
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 201 && result['success'] == true) {
        await fetchDamagedItems(refresh: true);
        return {'success': true, 'data': result['data']};
      } else {
        return {'success': false, 'error': result['message'] ?? 'Failed to add damaged item'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    } finally {
      _setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>> updateDamagedStatus({
    required int id,
    required String status,
    String? notes,
    double? actualLoss,
    String? repairNotes,
  })
  async {
    _setState(() => _isLoading = true);

    try {
      final headers = await _getAuthHeaders();

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/damaged-stock/$id/status'),
        headers: headers,
        body: jsonEncode({
          'status': status,
          'notes': notes,
          'actual_loss': actualLoss,
          'repair_notes': repairNotes,
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['success'] == true) {
        await fetchDamagedItems(refresh: true);
        return {'success': true, 'data': result['data']};
      } else {
        return {'success': false, 'error': result['message'] ?? 'Failed to update status'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    } finally {
      _setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>> deleteDamagedItem(int id) async {
    _setState(() => _isLoading = true);

    try {
      final headers = await _getAuthHeaders();

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/damaged-stock/$id'),
        headers: headers,
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['success'] == true) {
        // Refresh the list to show updated inventory
        await fetchDamagedItems(refresh: true);

        // Show success message with restock info if available
        final restockInfo = result['data'];
        String successMessage = 'Damaged record deleted successfully';
        if (restockInfo != null && restockInfo['restocked'] == true) {
          successMessage = 'Deleted successfully! ${restockInfo['quantity_restocked']} units of "${restockInfo['product_name']}" have been restocked.';
        }

        return {
          'success': true,
          'message': successMessage,
          'data': restockInfo
        };
      } else {
        return {
          'success': false,
          'error': result['message'] ?? 'Failed to delete'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    } finally {
      _setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> getStatistics() {
    return {
      'total': totalDamaged,
      'pending': totalPending,
      'approved': totalApproved,
      'disposed': totalDisposed,
      'repaired': totalRepaired,
      'totalLoss': totalLossValue,
    };
  }

  void setPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      _currentPage = page;
      fetchDamagedItems(page: page);
    }
  }

  void setStatusFilter(String? status) {
    _statusFilter = status;
    _currentPage = 1;
    fetchDamagedItems(refresh: true, status: status);
  }

  void clearFilters() {
    _statusFilter = null;
    _searchQuery = null;
    _currentPage = 1;
    fetchDamagedItems(refresh: true);
  }

  void _setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  Future<DamagedStockModel?> fetchDamagedItemById(int id) async {
    _setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/damaged-stock/$id'),
        headers: headers,
      );

      print('Fetch single item response status: ${response.statusCode}');
      print('Fetch single item response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        print('Parsed JSON structure: ${json.keys}');

        if (json['success'] == true) {
          final data = json['data'];
          print('Data keys: ${data.keys}');
          print('Product name from response: ${data['product_name']}');
          print('Product barcode from response: ${data['product_barcode']}');
          print('Product object: ${data['product']}');

          final item = DamagedStockModel.fromJson(data);
          print('Created model - productName: ${item.productName}, productBarcode: ${item.productBarcode}');

          _setState(() => _isLoading = false);
          return item;
        } else {
          _setState(() {
            _errorMessage = json['message'] ?? 'Failed to load damaged item';
            _isLoading = false;
          });
          return null;
        }
      } else {
        _setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
        return null;
      }
    } catch (e) {
      print('Error fetching damaged item: $e');
      _setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
      return null;
    }
  }
}