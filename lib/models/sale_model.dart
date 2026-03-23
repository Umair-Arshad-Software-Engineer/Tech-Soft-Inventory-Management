// lib/models/sale_model.dart
import 'package:flutter/material.dart';

class SaleModel {
  final int id;
  final String invoiceNumber;
  final String saleType;
  final int? customerId;
  final CustomerInfo? customer;
  final DateTime saleDate;
  final DateTime? dueDate;
  final double subtotal;
  final String discountType;
  final double discountValue;
  final double discountAmount;
  final double taxAmount;
  final double grandTotal;
  final double amountPaid;
  final double changeAmount;
  final String paymentMethod;
  final String paymentStatus;
  final String? notes;
  final List<SaleItemModel>? items;
  final DateTime createdAt;
  final DateTime updatedAt;

  SaleModel({
    required this.id,
    required this.invoiceNumber,
    required this.saleType,
    this.customerId,
    this.customer,
    required this.saleDate,
    this.dueDate,
    required this.subtotal,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.taxAmount,
    required this.grandTotal,
    required this.amountPaid,
    required this.changeAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    this.notes,
    this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  double get outstandingBalance => grandTotal - amountPaid;
  bool get isFullyPaid => paymentStatus == 'paid';
  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now()) && !isFullyPaid;




  Color get statusColor {
    switch (paymentStatus) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'unpaid':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    // Helper function to safely convert to double
    double toDoubleSafe(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (e) {
          debugPrint('Error parsing double from string: $value');
          return 0.0;
        }
      }
      return 0.0;
    }

    // Helper function to safely parse date
    DateTime parseDateSafe(String? dateStr) {
      if (dateStr == null) return DateTime.now();
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        debugPrint('Error parsing date: $dateStr');
        return DateTime.now();
      }
    }

    return SaleModel(
      id: json['id'] ?? 0,
      invoiceNumber: json['invoice_number'] ?? '',
      saleType: json['sale_type'] ?? 'pos',
      customerId: json['customer_id'],
      customer: json['customer'] != null ? CustomerInfo.fromJson(json['customer']) : null,
      saleDate: parseDateSafe(json['sale_date']),
      dueDate: json['due_date'] != null ? parseDateSafe(json['due_date']) : null,
      subtotal: toDoubleSafe(json['subtotal']),
      discountType: json['discount_type'] ?? 'fixed',
      discountValue: toDoubleSafe(json['discount_value']),
      discountAmount: toDoubleSafe(json['discount_amount']),
      taxAmount: toDoubleSafe(json['tax_amount']),
      grandTotal: toDoubleSafe(json['grand_total']),
      amountPaid: toDoubleSafe(json['amount_paid']),
      changeAmount: toDoubleSafe(json['change_amount']),
      paymentMethod: json['payment_method'] ?? 'cash',
      paymentStatus: json['payment_status'] ?? 'unpaid',
      notes: json['notes'],
      items: json['items'] != null
          ? (json['items'] as List).map((e) => SaleItemModel.fromJson(e)).toList()
          : null,
      createdAt: parseDateSafe(json['created_at']),
      updatedAt: parseDateSafe(json['updated_at']),
    );
  }
}

class CustomerInfo {
  final int id;
  final String name;
  final String? contact;
  final String? address;
  final String? email;
  final String customerType;

  CustomerInfo({
    required this.id,
    required this.name,
    this.contact,
    this.address,
    this.email,
    required this.customerType,
  });

  factory CustomerInfo.fromJson(Map<String, dynamic> json) {
    return CustomerInfo(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      contact: json['contact'],
      address: json['address'],
      email: json['email'],
      customerType: json['customer_type'] ?? 'regular',
    );
  }
}

class SaleItemModel {
  final int id;
  final int? productId;
  final String productName;
  final String? barcode;
  final double unitPrice;
  final int quantity;
  final double totalPrice;
  final ProductInfo? product;

  SaleItemModel({
    required this.id,
    this.productId,
    required this.productName,
    this.barcode,
    required this.unitPrice,
    required this.quantity,
    required this.totalPrice,
    this.product,
  });

  factory SaleItemModel.fromJson(Map<String, dynamic> json) {
    // Helper function to safely convert to double
    double toDoubleSafe(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (e) {
          debugPrint('Error parsing double from string in SaleItem: $value');
          return 0.0;
        }
      }
      return 0.0;
    }

    return SaleItemModel(
      id: json['id'] ?? 0,
      productId: json['product_id'],
      productName: json['product_name'] ?? '',
      barcode: json['barcode'],
      unitPrice: toDoubleSafe(json['unit_price']),
      quantity: json['quantity'] ?? 0,
      totalPrice: toDoubleSafe(json['total_price']),
      product: json['product'] != null ? ProductInfo.fromJson(json['product']) : null,
    );
  }
}

class ProductInfo {
  final int id;
  final String itemName;
  final String? barcode;
  final UnitInfo? unit;

  ProductInfo({
    required this.id,
    required this.itemName,
    this.barcode,
    this.unit,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      id: json['id'] ?? 0,
      itemName: json['item_name'] ?? '',
      barcode: json['barcode'],
      unit: json['unit'] != null ? UnitInfo.fromJson(json['unit']) : null,
    );
  }
}

class UnitInfo {
  final int id;
  final String name;
  final String symbol;

  UnitInfo({
    required this.id,
    required this.name,
    required this.symbol,
  });

  factory UnitInfo.fromJson(Map<String, dynamic> json) {
    return UnitInfo(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      symbol: json['symbol'] ?? '',
    );
  }
}