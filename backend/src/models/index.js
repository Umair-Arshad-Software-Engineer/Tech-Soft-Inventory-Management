const sequelize = require('../config/db');

// Import models
const User = require('./User');

// Import model functions
const initCategory = require('./Category');
const initSubcategory = require('./Subcategory');
const initUnit = require('./Unit');
const initSupplier = require('./supplier');
const initCustomer = require('./customer');
const initProduct = require('./Product');
const initCustomerPrice = require('./CustomerPrice');
const initProductImage = require('./ProductImage');
const initPurchaseOrder = require('./PurchaseOrder');
const initPurchaseOrderItem = require('./PurchaseOrderItem');
const initPurchaseReceipt = require('./PurchaseReceipt');
const initPurchaseReceiptItem = require('./PurchaseReceiptItem');
const initSupplierLedger = require('./SupplierLedger');
const initSale = require('./Sale');
const initSaleItem = require('./SaleItem');
const initCustomerLedger = require('./CustomerLedger');
const initDamagedStock = require('./DamagedStock');  // ADD THIS
const SaleReturnModel = require('./SaleReturn');
const SaleReturnItemModel = require('./SaleReturnItem');

// Initialize models
const Category = initCategory(sequelize);
const Subcategory = initSubcategory(sequelize);
const Unit = initUnit(sequelize);
const Supplier = initSupplier(sequelize);
const Customer = initCustomer(sequelize);
const Product = initProduct(sequelize);
const CustomerPrice = initCustomerPrice(sequelize);
const ProductImage = initProductImage(sequelize);
const PurchaseOrder = initPurchaseOrder(sequelize);
const PurchaseOrderItem = initPurchaseOrderItem(sequelize);
const PurchaseReceipt = initPurchaseReceipt(sequelize);
const PurchaseReceiptItem = initPurchaseReceiptItem(sequelize);
const SupplierLedger = initSupplierLedger(sequelize);
const Sale = initSale(sequelize);
const SaleItem = initSaleItem(sequelize);
const CustomerLedger = initCustomerLedger(sequelize);
const DamagedStock = initDamagedStock(sequelize);  // ADD THIS
const SaleReturn = SaleReturnModel(sequelize);
const SaleReturnItem = SaleReturnItemModel(sequelize);

// Define associations
Category.hasMany(Subcategory, {
  foreignKey: 'category_id',
  as: 'subcategories'
});

Subcategory.belongsTo(Category, {
  foreignKey: 'category_id',
  as: 'category'
});

// Product associations
Product.belongsTo(Supplier, {
  foreignKey: 'supplier_id',
  as: 'supplier'
});

Product.belongsTo(Category, {
  foreignKey: 'category_id',
  as: 'category'
});

Product.belongsTo(Subcategory, {
  foreignKey: 'subcategory_id',
  as: 'subcategory'
});

Product.belongsTo(Unit, {
  foreignKey: 'unit_id',
  as: 'unit'
});

Product.hasMany(CustomerPrice, {
  foreignKey: 'product_id',
  as: 'customerPrices'
});

// Damaged Stock associations - ADD THIS SECTION
Product.hasMany(DamagedStock, {
  foreignKey: 'product_id',
  as: 'damagedStock',
  onDelete: 'CASCADE'
});

DamagedStock.belongsTo(Product, {
  foreignKey: 'product_id',
  as: 'product'
});

// Product Image associations
Product.hasMany(ProductImage, {
  foreignKey: 'product_id',
  as: 'images',
  onDelete: 'CASCADE'
});

ProductImage.belongsTo(Product, {
  foreignKey: 'product_id',
  as: 'product'
});

// CustomerPrice associations
CustomerPrice.belongsTo(Product, {
  foreignKey: 'product_id',
  as: 'product'
});

CustomerPrice.belongsTo(Customer, {
  foreignKey: 'customer_id',
  as: 'customer'
});

// Customer associations
Customer.hasMany(CustomerPrice, {
  foreignKey: 'customer_id',
  as: 'prices'
});

// CUSTOMER LEDGER ASSOCIATIONS
Customer.hasMany(CustomerLedger, {
  foreignKey: 'customer_id',
  as: 'ledgerEntries',
  onDelete: 'CASCADE'
});

CustomerLedger.belongsTo(Customer, {
  foreignKey: 'customer_id',
  as: 'customer'
});

// Supplier associations
Supplier.hasMany(Product, {
  foreignKey: 'supplier_id',
  as: 'products'
});

// Supplier Ledger associations
Supplier.hasMany(SupplierLedger, {
  foreignKey: 'supplier_id',
  as: 'ledgerEntries'
});

SupplierLedger.belongsTo(Supplier, {
  foreignKey: 'supplier_id',
  as: 'supplier'
});

// Unit associations
Unit.hasMany(Product, {
  foreignKey: 'unit_id',
  as: 'products'
});

PurchaseOrder.belongsTo(Supplier, {
  foreignKey: 'supplier_id',
  as: 'supplier'
});

PurchaseOrder.belongsTo(User, {
  foreignKey: 'created_by',
  as: 'creator'
});

PurchaseOrder.hasMany(PurchaseOrderItem, {
  foreignKey: 'purchase_order_id',
  as: 'items',
  onDelete: 'CASCADE'
});

PurchaseOrder.hasMany(PurchaseReceipt, {
  foreignKey: 'purchase_order_id',
  as: 'receipts'
});

// Purchase Order Item associations
PurchaseOrderItem.belongsTo(PurchaseOrder, {
  foreignKey: 'purchase_order_id',
  as: 'purchaseOrder'
});

PurchaseOrderItem.belongsTo(Product, {
  foreignKey: 'product_id',
  as: 'product'
});

PurchaseOrderItem.hasMany(PurchaseReceiptItem, {
  foreignKey: 'purchase_order_item_id',
  as: 'receiptItems'
});

// Purchase Receipt associations
PurchaseReceipt.belongsTo(PurchaseOrder, {
  foreignKey: 'purchase_order_id',
  as: 'purchaseOrder'
});

PurchaseReceipt.belongsTo(User, {
  foreignKey: 'created_by',
  as: 'creator'
});

PurchaseReceipt.hasMany(PurchaseReceiptItem, {
  foreignKey: 'purchase_receipt_id',
  as: 'items',
  onDelete: 'CASCADE'
});

// Purchase Receipt Item associations
PurchaseReceiptItem.belongsTo(PurchaseReceipt, {
  foreignKey: 'purchase_receipt_id',
  as: 'purchaseReceipt'
});

PurchaseReceiptItem.belongsTo(PurchaseOrderItem, {
  foreignKey: 'purchase_order_item_id',
  as: 'purchaseOrderItem'
});

PurchaseReceiptItem.belongsTo(Product, {
  foreignKey: 'product_id',
  as: 'product'
});

// Sale associations
Sale.belongsTo(Customer, {
  foreignKey: 'customer_id',
  as: 'customer'
});

Sale.hasMany(SaleItem, {
  foreignKey: 'sale_id',
  as: 'items',
  onDelete: 'CASCADE'
});

// SaleItem associations
SaleItem.belongsTo(Sale, {
  foreignKey: 'sale_id',
  as: 'sale'
});

SaleItem.belongsTo(Product, {
  foreignKey: 'product_id',
  as: 'product'
});

// Customer Sales associations
Customer.hasMany(Sale, {
  foreignKey: 'customer_id',
  as: 'sales'
});

Sale.hasMany(SaleReturn, { foreignKey: 'sale_id', as: 'returns' });
SaleReturn.belongsTo(Sale, { foreignKey: 'sale_id', as: 'originalSale' });

SaleReturn.belongsTo(Customer, { foreignKey: 'customer_id', as: 'customer' });
Customer.hasMany(SaleReturn, { foreignKey: 'customer_id', as: 'returns' });

SaleReturn.hasMany(SaleReturnItem, { foreignKey: 'return_id', as: 'items' });
SaleReturnItem.belongsTo(SaleReturn, { foreignKey: 'return_id', as: 'return' });

SaleReturnItem.belongsTo(Product, { foreignKey: 'product_id', as: 'product' });
Product.hasMany(SaleReturnItem, { foreignKey: 'product_id', as: 'returns' });

const models = {
  User,
  Category,
  Subcategory,
  Unit,
  Supplier,
  Customer,
  Product,
  CustomerPrice,
  ProductImage,
  PurchaseOrder,
  PurchaseOrderItem,
  PurchaseReceipt,
  PurchaseReceiptItem,
  SupplierLedger,
  Sale,
  SaleItem,
  CustomerLedger,
  DamagedStock, 
  SaleReturn,
  SaleReturnItem,
  sequelize
};

module.exports = models;