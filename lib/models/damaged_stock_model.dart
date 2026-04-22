// lib/models/damaged_stock_model.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DamagedStockModel {
  final int id;
  final int productId;
  final int quantity;
  final String reason;
  final String status;
  final String? notes;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? disposedBy;
  final DateTime? disposedAt;
  final String? repairedBy;
  final DateTime? repairedAt;
  final String? repairNotes;
  final double? estimatedLoss;
  final double? actualLoss;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional: related data
  String? productName;
  String? productBarcode;
  double? productCostPrice;
  double? productSalePrice;

  DamagedStockModel({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.reason,
    required this.status,
    this.notes,
    this.approvedBy,
    this.approvedAt,
    this.disposedBy,
    this.disposedAt,
    this.repairedBy,
    this.repairedAt,
    this.repairNotes,
    this.estimatedLoss,
    this.actualLoss,
    required this.createdAt,
    required this.updatedAt,
    this.productName,
    this.productBarcode,
    this.productCostPrice,
    this.productSalePrice,
  });

  factory DamagedStockModel.fromJson(Map<String, dynamic> json) {
    // Debug print to see what we're receiving
    print('Parsing damaged stock JSON: $json');

    // Try to get product fields from either nested product object or flattened fields
    Map<String, dynamic> productData = {};

    // Check if product is nested
    if (json['product'] != null && json['product'] is Map<String, dynamic>) {
      productData = json['product'];
    }

    return DamagedStockModel(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      quantity: json['quantity'] ?? 0,
      reason: json['reason'] ?? 'other',
      status: json['status'] ?? 'pending',
      notes: json['notes'],
      approvedBy: json['approved_by'],
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at']) : null,
      disposedBy: json['disposed_by'],
      disposedAt: json['disposed_at'] != null ? DateTime.tryParse(json['disposed_at']) : null,
      repairedBy: json['repaired_by'],
      repairedAt: json['repaired_at'] != null ? DateTime.tryParse(json['repaired_at']) : null,
      repairNotes: json['repair_notes'],
      estimatedLoss: json['estimated_loss'] != null ? double.tryParse(json['estimated_loss'].toString()) : null,
      actualLoss: json['actual_loss'] != null ? double.tryParse(json['actual_loss'].toString()) : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at']) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at']) ?? DateTime.now())
          : DateTime.now(),

      // Try to get product info from multiple possible locations
      productName: json['product_name']?.toString()
          ?? productData['item_name']?.toString()
          ?? productData['name']?.toString(),

      productBarcode: json['product_barcode']?.toString()
          ?? productData['barcode']?.toString(),

      productCostPrice: json['product_cost_price'] != null
          ? double.tryParse(json['product_cost_price'].toString())
          : (productData['cost_price'] != null
          ? double.tryParse(productData['cost_price'].toString())
          : null),

      productSalePrice: json['product_sale_price'] != null
          ? double.tryParse(json['product_sale_price'].toString())
          : (productData['sale_price'] != null
          ? double.tryParse(productData['sale_price'].toString())
          : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'quantity': quantity,
      'reason': reason,
      'status': status,
      'notes': notes,
      'estimated_loss': estimatedLoss,
      'actual_loss': actualLoss,
      'repair_notes': repairNotes,
    };
  }

  double get lossAmount {
    if (actualLoss != null) return actualLoss!;
    if (estimatedLoss != null) return estimatedLoss!;
    if (productCostPrice != null) return productCostPrice! * quantity;
    return 0;
  }

  String get formattedCreatedAt => DateFormat('MMM dd, yyyy HH:mm').format(createdAt);
  String get formattedApprovedAt => approvedAt != null ? DateFormat('MMM dd, yyyy HH:mm').format(approvedAt!) : 'N/A';
  String get formattedDisposedAt => disposedAt != null ? DateFormat('MMM dd, yyyy HH:mm').format(disposedAt!) : 'N/A';
  String get formattedRepairedAt => repairedAt != null ? DateFormat('MMM dd, yyyy HH:mm').format(repairedAt!) : 'N/A';
  Color get statusColor {
    switch (status) {
      case 'pending':
        return const Color(0xFFF59E0B); // Orange
      case 'approved':
        return const Color(0xFF3B82F6); // Blue
      case 'disposed':
        return const Color(0xFFEF4444); // Red
      case 'repaired':
        return const Color(0xFF10B981); // Green
      default:
        return Colors.grey;
    }
  }

  String get statusText {
    switch (status) {
      case 'pending':
        return 'Pending Approval';
      case 'approved':
        return 'Approved';
      case 'disposed':
        return 'Disposed';
      case 'repaired':
        return 'Repaired';
      default:
        return status;
    }
  }
}

enum DamageReason {
  shippingDamage,
  manufacturingDefect,
  customerReturn,
  shelfWear,
  expiry,
  theft,
  accident,
  other;

  String get displayName {
    switch (this) {
      case DamageReason.shippingDamage:
        return 'Shipping Damage';
      case DamageReason.manufacturingDefect:
        return 'Manufacturing Defect';
      case DamageReason.customerReturn:
        return 'Customer Return';
      case DamageReason.shelfWear:
        return 'Shelf Wear';
      case DamageReason.expiry:
        return 'Expired';
      case DamageReason.theft:
        return 'Theft';
      case DamageReason.accident:
        return 'Accident';
      case DamageReason.other:
        return 'Other';
    }
  }

  static DamageReason fromString(String value) {
    switch (value) {
      case 'shipping_damage':
        return DamageReason.shippingDamage;
      case 'manufacturing_defect':
        return DamageReason.manufacturingDefect;
      case 'customer_return':
        return DamageReason.customerReturn;
      case 'shelf_wear':
        return DamageReason.shelfWear;
      case 'expiry':
        return DamageReason.expiry;
      case 'theft':
        return DamageReason.theft;
      case 'accident':
        return DamageReason.accident;
      default:
        return DamageReason.other;
    }
  }

  String get apiValue {
    switch (this) {
      case DamageReason.shippingDamage:
        return 'shipping_damage';
      case DamageReason.manufacturingDefect:
        return 'manufacturing_defect';
      case DamageReason.customerReturn:
        return 'customer_return';
      case DamageReason.shelfWear:
        return 'shelf_wear';
      case DamageReason.expiry:
        return 'expiry';
      case DamageReason.theft:
        return 'theft';
      case DamageReason.accident:
        return 'accident';
      case DamageReason.other:
        return 'other';
    }
  }
}