// lib/models/product_model.dart
class ProductModel {
  final int id;
  final String itemName;
  final String? description;
  final double costPrice;
  final double salePrice;
  final int? supplierId;
  final int categoryId;
  final int? subcategoryId;
  final int unitId;
  final String? barcode;
  final int minStock;
  final int physicalQty;
  final int availableQty;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related models
  final SupplierInfo? supplier;
  final CategoryInfo? category;
  final SubcategoryInfo? subcategory;
  final UnitInfo? unit;
  final List<CustomerPriceInfo>? customerPrices;

  ProductModel({
    required this.id,
    required this.itemName,
    this.description,
    required this.costPrice,
    required this.salePrice,
    this.supplierId,
    required this.categoryId,
    this.subcategoryId,
    required this.unitId,
    this.barcode,
    required this.minStock,
    required this.physicalQty,
    required this.availableQty,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.supplier,
    this.category,
    this.subcategory,
    this.unit,
    this.customerPrices,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      itemName: json['item_name'] ?? '',
      description: json['description'],
      costPrice: double.tryParse(json['cost_price']?.toString() ?? '0') ?? 0.0,
      salePrice: double.tryParse(json['sale_price']?.toString() ?? '0') ?? 0.0,
      supplierId: json['supplier_id'],
      categoryId: json['category_id'] ?? 0,
      subcategoryId: json['subcategory_id'],
      unitId: json['unit_id'] ?? 0,
      barcode: json['barcode'],
      minStock: json['min_stock'] ?? 0,
      physicalQty: json['physical_qty'] ?? 0,
      availableQty: json['available_qty'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      supplier: json['supplier'] != null ? SupplierInfo.fromJson(json['supplier']) : null,
      category: json['category'] != null ? CategoryInfo.fromJson(json['category']) : null,
      subcategory: json['subcategory'] != null ? SubcategoryInfo.fromJson(json['subcategory']) : null,
      unit: json['unit'] != null ? UnitInfo.fromJson(json['unit']) : null,
      customerPrices: json['customerPrices'] != null
          ? (json['customerPrices'] as List).map((e) => CustomerPriceInfo.fromJson(e)).toList()
          : null,
    );
  }

  // Add this copyWith method
  ProductModel copyWith({
    int? id,
    String? itemName,
    String? description,
    double? costPrice,
    double? salePrice,
    int? supplierId,
    int? categoryId,
    int? subcategoryId,
    int? unitId,
    String? barcode,
    int? minStock,
    int? physicalQty,
    int? availableQty,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    SupplierInfo? supplier,
    CategoryInfo? category,
    SubcategoryInfo? subcategory,
    UnitInfo? unit,
    List<CustomerPriceInfo>? customerPrices,
  }) {
    return ProductModel(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      description: description ?? this.description,
      costPrice: costPrice ?? this.costPrice,
      salePrice: salePrice ?? this.salePrice,
      supplierId: supplierId ?? this.supplierId,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      unitId: unitId ?? this.unitId,
      barcode: barcode ?? this.barcode,
      minStock: minStock ?? this.minStock,
      physicalQty: physicalQty ?? this.physicalQty,
      availableQty: availableQty ?? this.availableQty,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supplier: supplier ?? this.supplier,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      unit: unit ?? this.unit,
      customerPrices: customerPrices ?? this.customerPrices,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_name': itemName,
      'description': description,
      'cost_price': costPrice,
      'sale_price': salePrice,
      'supplier_id': supplierId,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'unit_id': unitId,
      'barcode': barcode,
      'min_stock': minStock,
      'physical_qty': physicalQty,
    };
  }
}

class SupplierInfo {
  final int id;
  final String name;
  final String? contact;

  SupplierInfo({required this.id, required this.name, this.contact});

  factory SupplierInfo.fromJson(Map<String, dynamic> json) {
    return SupplierInfo(
      id: json['id'],
      name: json['name'],
      contact: json['contact'],
    );
  }
}

class CategoryInfo {
  final int id;
  final String name;

  CategoryInfo({required this.id, required this.name});

  factory CategoryInfo.fromJson(Map<String, dynamic> json) {
    return CategoryInfo(
      id: json['id'],
      name: json['name'],
    );
  }
}

class SubcategoryInfo {
  final int id;
  final String name;

  SubcategoryInfo({required this.id, required this.name});

  factory SubcategoryInfo.fromJson(Map<String, dynamic> json) {
    return SubcategoryInfo(
      id: json['id'],
      name: json['name'],
    );
  }
}

class UnitInfo {
  final int id;
  final String name;
  final String symbol;

  UnitInfo({required this.id, required this.name, required this.symbol});

  factory UnitInfo.fromJson(Map<String, dynamic> json) {
    return UnitInfo(
      id: json['id'],
      name: json['name'],
      symbol: json['symbol'],
    );
  }
}

class CustomerPriceInfo {
  final int id;
  final int productId;
  final int customerId;
  final double price;
  final bool isActive;
  final CustomerInfo? customer;

  CustomerPriceInfo({
    required this.id,
    required this.productId,
    required this.customerId,
    required this.price,
    required this.isActive,
    this.customer,
  });

  factory CustomerPriceInfo.fromJson(Map<String, dynamic> json) {
    return CustomerPriceInfo(
      id: json['id'],
      productId: json['product_id'],
      customerId: json['customer_id'],
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      isActive: json['is_active'] ?? true,  // add null safety
      customer: json['customer'] != null ? CustomerInfo.fromJson(json['customer']) : null,
    );
  }
}

class CustomerInfo {
  final int id;
  final String name;
  final String customerType;

  CustomerInfo({required this.id, required this.name, required this.customerType});

  factory CustomerInfo.fromJson(Map<String, dynamic> json) {
    return CustomerInfo(
      id: json['id'],
      name: json['name'],
      customerType: json['customer_type'],
    );
  }
}