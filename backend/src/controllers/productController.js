// controllers/productController.js
const { Op } = require('sequelize');
const {
  Product,
  Supplier,
  Category,
  Subcategory,
  Unit,
  Customer,
  CustomerPrice,
  Sale,
  SaleItem,
  PurchaseReceipt,
  PurchaseReceiptItem,
  PurchaseOrder,
  DamagedStock,  // ADD THIS
} = require('../models');


exports.getProductHistory = async (req, res) => {
  try {
    const { id } = req.params;
    const { page = 1, limit = 20, type } = req.query;

    const pageNum  = parseInt(page);
    const limitNum = parseInt(limit);
    const offset   = (pageNum - 1) * limitNum;

    const product = await Product.findByPk(id, {
      attributes: ['id', 'item_name'],
    });
    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found' });
    }

    const results = { sale_history: [], purchase_history: [] };

    // ── Sale history ──────────────────────────────────────────────────────────
    if (!type || type === 'sale') {
      const { count: saleCount, rows: saleItems } = await SaleItem.findAndCountAll({
        where: { product_id: id },
        include: [
          {
            model: Sale,
            as: 'sale',
            attributes: [
              'id', 'invoice_number', 'sale_type', 'sale_date',
              'grand_total', 'payment_status', 'payment_method',
            ],
            include: [
              {
                model: Customer,
                as: 'customer',
                attributes: ['id', 'name', 'contact'],
              },
            ],
          },
        ],
        attributes: ['id', 'quantity', 'unit_price', 'total_price'],
        order: [[{ model: Sale, as: 'sale' }, 'sale_date', 'DESC']],
        limit:  type === 'sale' ? limitNum : undefined,
        offset: type === 'sale' ? offset   : undefined,
        distinct: true,
      });

      results.sale_history = saleItems.map((si) => ({
        id:             si.sale.id,
        invoice_number: si.sale.invoice_number,
        sale_type:      si.sale.sale_type,
        date:           si.sale.sale_date,
        customer:       si.sale.customer,
        quantity:       si.quantity,
        unit_price:     si.unit_price,
        total_price:    si.total_price,
        payment_status: si.sale.payment_status,
        payment_method: si.sale.payment_method,
        grand_total:    si.sale.grand_total,
      }));
      results.sale_count = saleCount;
    }

    // ── Purchase (receipt) history ────────────────────────────────────────────
    if (!type || type === 'purchase') {
      const { count: purchaseCount, rows: receiptItems } = await PurchaseReceiptItem.findAndCountAll({
        where: { product_id: id },
        include: [
          {
            model: PurchaseReceipt,
            as: 'purchaseReceipt',
            attributes: ['id', 'receipt_number', 'receipt_date', 'status', 'notes'],
            include: [
              {
                model: PurchaseOrder,
                as: 'purchaseOrder',
                attributes: ['id', 'po_number', 'supplier_id'],
                include: [
                  {
                    model: Supplier,
                    as: 'supplier',
                    attributes: ['id', 'name', 'contact'],
                  },
                ],
              },
            ],
          },
        ],
        attributes: ['id', 'quantity_received', 'unit_cost', 'batch_number', 'expiry_date'],
        order: [[{ model: PurchaseReceipt, as: 'purchaseReceipt' }, 'receipt_date', 'DESC']],
        limit:  type === 'purchase' ? limitNum : undefined,
        offset: type === 'purchase' ? offset   : undefined,
        distinct: true,
      });

      results.purchase_history = receiptItems.map((ri) => ({
        id:                ri.purchaseReceipt.id,
        receipt_number:    ri.purchaseReceipt.receipt_number,
        po_number:         ri.purchaseReceipt.purchaseOrder?.po_number,
        date:              ri.purchaseReceipt.receipt_date,
        supplier:          ri.purchaseReceipt.purchaseOrder?.supplier,
        quantity_received: ri.quantity_received,
        unit_cost:         ri.unit_cost,
        total_cost:        ri.quantity_received * parseFloat(ri.unit_cost),
        batch_number:      ri.batch_number,
        expiry_date:       ri.expiry_date,
        status:            ri.purchaseReceipt.status,
      }));
      results.purchase_count = purchaseCount;
    }

    // ── Damaged stock history ────────────────────────────────────────────
    if (!type || type === 'damaged') {
      const { count: damagedCount, rows: damagedItems } = await DamagedStock.findAndCountAll({
        where: { product_id: id },
        attributes: ['id', 'quantity', 'reason', 'status', 'notes', 'estimated_loss', 'actual_loss', 'created_at', 'updated_at'],
        order: [['created_at', 'DESC']],
        limit: type === 'damaged' ? limitNum : undefined,
        offset: type === 'damaged' ? offset : undefined,
        distinct: true,
      });

      results.damaged_history = damagedItems;
      results.damaged_count = damagedCount;
    }

    res.json({
      success: true,
      data: results,
      product: { id: product.id, name: product.item_name },
    });
  } catch (error) {
    console.error('Get product history error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Check if barcode exists
exports.checkBarcodeExists = async (req, res) => {
  try {
    const { barcode } = req.query;
    
    if (!barcode) {
      return res.status(400).json({ success: false, message: 'Barcode is required' });
    }
    
    const product = await Product.findOne({ where: { barcode } });
    
    res.json({ 
      success: true, 
      exists: !!product 
    });
  } catch (error) {
    console.error('Check barcode error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Get all products with pagination and filters
exports.getAllProducts = async (req, res) => {
  try {
    const { 
      search, 
      page = 1, 
      limit = 20, 
      supplier_id, 
      category_id, 
      subcategory_id,
      unit_id,
      low_stock,
      active,
      sort_by = 'item_name',
      sort_order = 'ASC'
    } = req.query;

    const pageNum = parseInt(page);
    const limitNum = parseInt(limit);
    const offset = (pageNum - 1) * limitNum;

    const whereClause = {};
    
    if (search) {
      whereClause[Op.or] = [
        { item_name: { [Op.like]: `%${search}%` } },
        { description: { [Op.like]: `%${search}%` } },
        { barcode: { [Op.like]: `%${search}%` } }
      ];
    }

    if (supplier_id) whereClause.supplier_id = supplier_id;
    if (category_id) whereClause.category_id = category_id;
    if (subcategory_id) whereClause.subcategory_id = subcategory_id;
    if (unit_id) whereClause.unit_id = unit_id;
    if (active !== undefined) whereClause.is_active = active === 'true';

    const { count, rows: products } = await Product.findAndCountAll({
      where: whereClause,
      include: [
        { model: Supplier,     as: 'supplier',     attributes: ['id', 'name', 'contact'] },
        { model: Category,     as: 'category',     attributes: ['id', 'name'] },
        { model: Subcategory,  as: 'subcategory',  attributes: ['id', 'name'] },
        { model: Unit,         as: 'unit',         attributes: ['id', 'name', 'symbol'] },
        {
          model: CustomerPrice,
          as: 'customerPrices',
          include: [{ model: Customer, as: 'customer', attributes: ['id', 'name', 'customer_type'] }],
          required: false,
        },
      ],
      attributes: [
        'id', 'item_name', 'description', 'cost_price', 'sale_price',
        'barcode', 'min_stock', 'physical_qty', 'available_qty',
        'is_active', 'created_at', 'updated_at',
      ],
      order: [[sort_by, sort_order]],
      limit: limitNum,
      offset,
      distinct: true,
    });

    const totalValue = products.reduce((sum, p) =>
      sum + (parseFloat(p.cost_price) * p.physical_qty), 0);

    res.json({
      success: true,
      data: products,
      pagination: { total: count, page: pageNum, limit: limitNum, pages: Math.ceil(count / limitNum) },
      summary: {
        total_products: count,
        total_value: totalValue,
        low_stock_count: products.filter(p => p.physical_qty <= p.min_stock).length,
      },
    });
  } catch (error) {
    console.error('Get products error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Get product by ID
exports.getProductById = async (req, res) => {
  try {
    const { id } = req.params;

    const product = await Product.findByPk(id, {
      include: [
        { model: Supplier,    as: 'supplier',    attributes: ['id', 'name', 'contact'] },
        { model: Category,    as: 'category',    attributes: ['id', 'name'] },
        { model: Subcategory, as: 'subcategory', attributes: ['id', 'name'] },
        { model: Unit,        as: 'unit',        attributes: ['id', 'name', 'symbol', 'conversion_factor'] },
        {
          model: CustomerPrice,
          as: 'customerPrices',
          include: [{ model: Customer, as: 'customer', attributes: ['id', 'name', 'customer_type'] }],
        },
      ],
    });

    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found' });
    }

    res.json({ success: true, data: product });
  } catch (error) {
    console.error('Get product error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Get product by barcode
exports.getProductByBarcode = async (req, res) => {
  try {
    const { barcode } = req.params;

    const product = await Product.findOne({
      where: { barcode },
      include: [
        { model: Supplier, as: 'supplier', attributes: ['id', 'name'] },
        { model: Category, as: 'category', attributes: ['id', 'name'] },
        { model: Unit,     as: 'unit',     attributes: ['id', 'name', 'symbol'] },
      ],
    });

    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found with this barcode' });
    }

    res.json({ success: true, data: product });
  } catch (error) {
    console.error('Get product by barcode error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Create new product
exports.createProduct = async (req, res) => {
  try {
    const {
      item_name, description, cost_price, sale_price,
      supplier_id, category_id, subcategory_id, unit_id,
      barcode, min_stock, physical_qty,
    } = req.body;

    if (!item_name || !category_id || !unit_id) {
      return res.status(400).json({ success: false, message: 'Item name, category, and unit are required' });
    }

    if (barcode) {
      const existing = await Product.findOne({ where: { barcode } });
      if (existing) {
        return res.status(400).json({ success: false, message: 'Product with this barcode already exists' });
      }
    }

    if (!await Category.findByPk(category_id))
      return res.status(404).json({ success: false, message: 'Category not found' });
    if (!await Unit.findByPk(unit_id))
      return res.status(404).json({ success: false, message: 'Unit not found' });
    if (supplier_id && !await Supplier.findByPk(supplier_id))
      return res.status(404).json({ success: false, message: 'Supplier not found' });
    if (subcategory_id && !await Subcategory.findByPk(subcategory_id))
      return res.status(404).json({ success: false, message: 'Subcategory not found' });

    const product = await Product.create({
      item_name, description,
      cost_price: cost_price || 0,
      sale_price: sale_price || 0,
      supplier_id, category_id, subcategory_id, unit_id, barcode,
      min_stock: min_stock || 0,
      physical_qty: physical_qty || 0,
      available_qty: physical_qty || 0,
      is_active: true,
    });

    const created = await Product.findByPk(product.id, {
      include: [
        { model: Supplier,    as: 'supplier',    attributes: ['id', 'name'] },
        { model: Category,    as: 'category',    attributes: ['id', 'name'] },
        { model: Subcategory, as: 'subcategory', attributes: ['id', 'name'] },
        { model: Unit,        as: 'unit',        attributes: ['id', 'name', 'symbol'] },
      ],
    });

    res.status(201).json({ success: true, message: 'Product created successfully', data: created });
  } catch (error) {
    console.error('Create product error:', error);
    if (error.name === 'SequelizeValidationError') {
      return res.status(400).json({ success: false, message: 'Validation error', errors: error.errors.map(e => e.message) });
    }
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Update product
exports.updateProduct = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      item_name, description, cost_price, sale_price,
      supplier_id, category_id, subcategory_id, unit_id,
      barcode, min_stock, physical_qty, is_active,
    } = req.body;

    const product = await Product.findByPk(id);
    if (!product) return res.status(404).json({ success: false, message: 'Product not found' });

    if (barcode && barcode !== product.barcode) {
      const existing = await Product.findOne({ where: { barcode, id: { [Op.ne]: id } } });
      if (existing) return res.status(400).json({ success: false, message: 'Product with this barcode already exists' });
    }

    if (category_id  && category_id  !== product.category_id  && !await Category.findByPk(category_id))
      return res.status(404).json({ success: false, message: 'Category not found' });
    if (unit_id      && unit_id      !== product.unit_id      && !await Unit.findByPk(unit_id))
      return res.status(404).json({ success: false, message: 'Unit not found' });
    if (supplier_id  && supplier_id  !== product.supplier_id  && !await Supplier.findByPk(supplier_id))
      return res.status(404).json({ success: false, message: 'Supplier not found' });
    if (subcategory_id && subcategory_id !== product.subcategory_id && !await Subcategory.findByPk(subcategory_id))
      return res.status(404).json({ success: false, message: 'Subcategory not found' });

    await product.update({
      item_name:     item_name     ?? product.item_name,
      description:   description   !== undefined ? description   : product.description,
      cost_price:    cost_price    !== undefined ? cost_price    : product.cost_price,
      sale_price:    sale_price    !== undefined ? sale_price    : product.sale_price,
      supplier_id:   supplier_id   !== undefined ? supplier_id   : product.supplier_id,
      category_id:   category_id   ?? product.category_id,
      subcategory_id: subcategory_id !== undefined ? subcategory_id : product.subcategory_id,
      unit_id:       unit_id       ?? product.unit_id,
      barcode:       barcode       !== undefined ? barcode       : product.barcode,
      min_stock:     min_stock     !== undefined ? min_stock     : product.min_stock,
      physical_qty:  physical_qty  !== undefined ? physical_qty  : product.physical_qty,
      available_qty: physical_qty  !== undefined ? physical_qty  : product.available_qty,
      is_active:     is_active     !== undefined ? is_active     : product.is_active,
    });

    const updated = await Product.findByPk(id, {
      include: [
        { model: Supplier,    as: 'supplier',    attributes: ['id', 'name'] },
        { model: Category,    as: 'category',    attributes: ['id', 'name'] },
        { model: Subcategory, as: 'subcategory', attributes: ['id', 'name'] },
        { model: Unit,        as: 'unit',        attributes: ['id', 'name', 'symbol'] },
      ],
    });

    res.json({ success: true, message: 'Product updated successfully', data: updated });
  } catch (error) {
    console.error('Update product error:', error);
    if (error.name === 'SequelizeValidationError') {
      return res.status(400).json({ success: false, message: 'Validation error', errors: error.errors.map(e => e.message) });
    }
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Delete product
exports.deleteProduct = async (req, res) => {
  try {
    const { id } = req.params;

    const product = await Product.findByPk(id);
    if (!product) return res.status(404).json({ success: false, message: 'Product not found' });

    const customerPricesCount = await CustomerPrice.count({ where: { product_id: id } });
    if (customerPricesCount > 0) {
      return res.status(400).json({
        success: false,
        message: 'Cannot delete product with customer-specific prices. Delete customer prices first.',
      });
    }

    await product.destroy();
    res.json({ success: true, message: 'Product deleted successfully' });
  } catch (error) {
    console.error('Delete product error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Toggle product status
exports.toggleProductStatus = async (req, res) => {
  try {
    const { id } = req.params;

    const product = await Product.findByPk(id);
    if (!product) return res.status(404).json({ success: false, message: 'Product not found' });

    await product.update({ is_active: !product.is_active });

    res.json({
      success: true,
      message: `Product ${product.is_active ? 'activated' : 'deactivated'} successfully`,
      data: { id: product.id, item_name: product.item_name, is_active: product.is_active },
    });
  } catch (error) {
    console.error('Toggle product status error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Update product quantity
exports.updateProductQuantity = async (req, res) => {
  try {
    const { id } = req.params;
    const { quantity, operation } = req.body;

    if (quantity === undefined || !operation) {
      return res.status(400).json({ success: false, message: 'Quantity and operation are required' });
    }

    const product = await Product.findByPk(id);
    if (!product) return res.status(404).json({ success: false, message: 'Product not found' });

    let newQuantity;
    switch (operation) {
      case 'add':
        newQuantity = product.physical_qty + parseInt(quantity);
        break;
      case 'subtract':
        newQuantity = product.physical_qty - parseInt(quantity);
        if (newQuantity < 0)
          return res.status(400).json({ success: false, message: 'Insufficient quantity' });
        break;
      case 'set':
        newQuantity = parseInt(quantity);
        break;
      default:
        return res.status(400).json({ success: false, message: 'Invalid operation. Use add, subtract, or set' });
    }

    await product.update({ physical_qty: newQuantity, available_qty: newQuantity });

    res.json({
      success: true,
      message: 'Product quantity updated successfully',
      data: {
        id: product.id,
        item_name: product.item_name,
        old_quantity: product.physical_qty,
        new_quantity: newQuantity,
        is_low_stock: newQuantity <= product.min_stock,
      },
    });
  } catch (error) {
    console.error('Update product quantity error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Get low stock products
exports.getLowStockProducts = async (req, res) => {
  try {
    const { Op, literal } = require('sequelize');
    const products = await Product.findAll({
      where: { is_active: true, physical_qty: { [Op.lte]: literal('min_stock') } },
      include: [
        { model: Supplier, as: 'supplier', attributes: ['id', 'name'] },
        { model: Unit,     as: 'unit',     attributes: ['id', 'name', 'symbol'] },
      ],
      attributes: ['id', 'item_name', 'physical_qty', 'min_stock', 'cost_price', 'sale_price'],
      order: [['physical_qty', 'ASC']],
    });

    res.json({ success: true, data: products, count: products.length });
  } catch (error) {
    console.error('Get low stock products error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Get products by supplier
exports.getProductsBySupplier = async (req, res) => {
  try {
    const { supplierId } = req.params;

    const products = await Product.findAll({
      where: { supplier_id: supplierId, is_active: true },
      include: [
        { model: Category, as: 'category', attributes: ['id', 'name'] },
        { model: Unit,     as: 'unit',     attributes: ['id', 'name', 'symbol'] },
      ],
      attributes: ['id', 'item_name', 'cost_price', 'sale_price', 'physical_qty'],
      order: [['item_name', 'ASC']],
    });

    res.json({ success: true, data: products });
  } catch (error) {
    console.error('Get products by supplier error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};