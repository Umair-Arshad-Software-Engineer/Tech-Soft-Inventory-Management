// // lib/config/api_config.dart
//
// class ApiConfig {
//   // Change this to your computer's IP address for physical device testing
//   // Use 10.0.2.2 for Android emulator
//   // Use localhost for iOS simulator
//   static const String baseUrl = 'http://192.168.10.9:3000/api';
//
//   // ── Auth ─────────────────────────────────────────────────────────
//   static const String registerUrl = '$baseUrl/auth/register';
//   static const String loginUrl    = '$baseUrl/auth/login';
//   static const String getMeUrl    = '$baseUrl/auth/me';
//
//   // ── Products ─────────────────────────────────────────────────────
//   static const String productsUrl = '$baseUrl/products';
//   static String productUrl(int id)               => '$baseUrl/products/$id';
//   static String toggleProductStatusUrl(int id)   => '$baseUrl/products/$id/toggle-status';
//   static String updateProductQuantityUrl(int id) => '$baseUrl/products/$id/quantity';
//   static String productByBarcodeUrl(String barcode) => '$baseUrl/products/barcode/$barcode';
//
//   // ── Customer Prices ──────────────────────────────────────────────
//   static const String customerPricesUrl    = '$baseUrl/customer-prices';
//   static String customerPriceUrl(int id)   => '$baseUrl/customer-prices/$id';
//   static String toggleCustomerPriceStatusUrl(int id) =>
//       '$baseUrl/customer-prices/$id/toggle-status';
//   static const String bulkCustomerPricesUrl = '$baseUrl/customer-prices/bulk';
//
//   // ── Customers ────────────────────────────────────────────────────
//   static const String customersUrl              = '$baseUrl/customers';
//   static String customerUrl(int id)             => '$baseUrl/customers/$id';
//   static String toggleCustomerStatusUrl(int id) => '$baseUrl/customers/$id/toggle-status';
//   static String customerBalanceUrl(int id)      => '$baseUrl/customers/$id/balance';
//
//   // ── Suppliers ────────────────────────────────────────────────────
//   static const String suppliersUrl = '$baseUrl/suppliers';
//   static String supplierUrl(int id)              => '$baseUrl/suppliers/$id';
//   static String supplierLedgerUrl(int id)        => '$baseUrl/suppliers/$id/ledger';
//
//   // ── Purchase Orders ──────────────────────────────────────────────
//   static const String purchaseOrdersUrl = '$baseUrl/purchase-orders';
//   static String purchaseOrderUrl(int id)         => '$baseUrl/purchase-orders/$id';
//   static String purchaseOrderReceiptsUrl(int id) => '$baseUrl/purchase-orders/$id/receipts';
//
//   // ── Purchase Receipts ────────────────────────────────────────────
//   static const String createReceiptUrl           = '$baseUrl/purchase-orders/receipts';
//   static String receiptByIdUrl(int id)           => '$baseUrl/purchase-orders/receipts/$id';
//   static String deleteReceiptUrl(int id)         => '$baseUrl/purchase-orders/receipts/$id';
//
//   // ── Sales ────────────────────────────────────────────────────────
//   static const String salesUrl                   = '$baseUrl/sales';
//   static String saleUrl(int id)                  => '$baseUrl/sales/$id';
//   static const String salesDailySummaryUrl       = '$baseUrl/sales/summary/daily';
//   static String salePaymentUrl(int id)           => '$baseUrl/sales/$id/payment';
//
//   // In api_config.dart, add under Sales section:
//   static const String saleReturnsUrl         = '$baseUrl/sales/returns';
//   static String saleReturnUrl(int id)        => '$baseUrl/sales/returns/$id';
//   static String saleReturnsBySaleUrl(int id) => '$baseUrl/sales/$id/returns';
// }

import 'network_discovery.dart';

class ApiConfig {
  static String? _baseUrl;

  /// Initialize API base URL
  static Future<void> init() async {
    _baseUrl = await NetworkDiscovery.discoverServer();

    // fallback if auto-discovery fails
    _baseUrl ??= 'http://192.168.10.9:3000/api';

    print('🌐 API Base URL: $_baseUrl');
  }

  /// Safe getter
  static String get baseUrl {
    if (_baseUrl == null) {
      throw Exception(
        'ApiConfig not initialized. Call ApiConfig.init() in main() first.',
      );
    }
    return _baseUrl!;
  }

  // ── Auth ─────────────────────────────────────────────────────────
  static String get registerUrl => '$baseUrl/auth/register';
  static String get loginUrl => '$baseUrl/auth/login';
  static String get getMeUrl => '$baseUrl/auth/me';

  // ── Products ─────────────────────────────────────────────────────
  static String get productsUrl => '$baseUrl/products';
  static String productUrl(int id) => '$baseUrl/products/$id';
  static String toggleProductStatusUrl(int id) =>
      '$baseUrl/products/$id/toggle-status';
  static String updateProductQuantityUrl(int id) =>
      '$baseUrl/products/$id/quantity';
  static String productByBarcodeUrl(String barcode) =>
      '$baseUrl/products/barcode/$barcode';

  // ── Customer Prices ──────────────────────────────────────────────
  static String get customerPricesUrl => '$baseUrl/customer-prices';
  static String customerPriceUrl(int id) =>
      '$baseUrl/customer-prices/$id';
  static String toggleCustomerPriceStatusUrl(int id) =>
      '$baseUrl/customer-prices/$id/toggle-status';
  static String get bulkCustomerPricesUrl =>
      '$baseUrl/customer-prices/bulk';

  // ── Customers ────────────────────────────────────────────────────
  static String get customersUrl => '$baseUrl/customers';
  static String customerUrl(int id) => '$baseUrl/customers/$id';
  static String toggleCustomerStatusUrl(int id) =>
      '$baseUrl/customers/$id/toggle-status';
  static String customerBalanceUrl(int id) =>
      '$baseUrl/customers/$id/balance';

  // ── Suppliers ────────────────────────────────────────────────────
  static String get suppliersUrl => '$baseUrl/suppliers';
  static String supplierUrl(int id) => '$baseUrl/suppliers/$id';
  static String supplierLedgerUrl(int id) =>
      '$baseUrl/suppliers/$id/ledger';

  // ── Purchase Orders ──────────────────────────────────────────────
  static String get purchaseOrdersUrl =>
      '$baseUrl/purchase-orders';
  static String purchaseOrderUrl(int id) =>
      '$baseUrl/purchase-orders/$id';
  static String purchaseOrderReceiptsUrl(int id) =>
      '$baseUrl/purchase-orders/$id/receipts';

  // ── Purchase Receipts ────────────────────────────────────────────
  static String get createReceiptUrl =>
      '$baseUrl/purchase-orders/receipts';
  static String receiptByIdUrl(int id) =>
      '$baseUrl/purchase-orders/receipts/$id';
  static String deleteReceiptUrl(int id) =>
      '$baseUrl/purchase-orders/receipts/$id';

  // ── Sales ────────────────────────────────────────────────────────
  static String get salesUrl => '$baseUrl/sales';
  static String saleUrl(int id) => '$baseUrl/sales/$id';
  static String get salesDailySummaryUrl =>
      '$baseUrl/sales/summary/daily';
  static String salePaymentUrl(int id) =>
      '$baseUrl/sales/$id/payment';

  // ── Sale Returns ─────────────────────────────────────────────────
  static String get saleReturnsUrl =>
      '$baseUrl/sales/returns';
  static String saleReturnUrl(int id) =>
      '$baseUrl/sales/returns/$id';
  static String saleReturnsBySaleUrl(int id) =>
      '$baseUrl/sales/$id/returns';
}