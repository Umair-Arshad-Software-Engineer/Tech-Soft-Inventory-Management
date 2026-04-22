// backend/src/controllers/damagedStockController.js
const { Op } = require('sequelize');
const {
  DamagedStock,
  Product,
  Supplier,
  Category,
  Unit,
  sequelize
} = require('../models');

// Get all damaged stock items with pagination and filters
exports.getAllDamagedStock = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      status,
      reason,
      product_id,
      search,
      from_date,
      to_date,
      sort_by = 'created_at',
      sort_order = 'DESC'
    } = req.query;

    const pageNum = parseInt(page);
    const limitNum = parseInt(limit);
    const offset = (pageNum - 1) * limitNum;

    const whereClause = {};

    if (status) whereClause.status = status;
    if (reason) whereClause.reason = reason;
    if (product_id) whereClause.product_id = product_id;

    if (search) {
      whereClause[Op.or] = [
        { '$product.item_name$': { [Op.like]: `%${search}%` } },
        { '$product.barcode$': { [Op.like]: `%${search}%` } },
        { notes: { [Op.like]: `%${search}%` } }
      ];
    }

    if (from_date && to_date) {
      whereClause.created_at = {
        [Op.between]: [new Date(from_date), new Date(to_date)]
      };
    } else if (from_date) {
      whereClause.created_at = { [Op.gte]: new Date(from_date) };
    } else if (to_date) {
      whereClause.created_at = { [Op.lte]: new Date(to_date) };
    }

    const { count, rows } = await DamagedStock.findAndCountAll({
      where: whereClause,
      include: [
        {
          model: Product,
          as: 'product',
          attributes: ['id', 'item_name', 'barcode', 'cost_price', 'sale_price', 'physical_qty', 'available_qty'],
          include: [
            { model: Supplier, as: 'supplier', attributes: ['id', 'name'] },
            { model: Category, as: 'category', attributes: ['id', 'name'] },
            { model: Unit, as: 'unit', attributes: ['id', 'name', 'symbol'] }
          ]
        }
      ],
      attributes: [
        'id',
        'quantity',
        'reason',
        'status',
        'notes',
        'approved_by',
        'approved_at',
        'disposed_by',
        'disposed_at',
        'repaired_by',
        'repaired_at',
        'repair_notes',
        'estimated_loss',
        'actual_loss',
        'created_at',
        'updated_at'
      ],
      order: [[sort_by, sort_order]],
      limit: limitNum,
      offset,
      distinct: true
    });

    // Calculate summary statistics
    const stats = await DamagedStock.findAll({
      where: whereClause,
      attributes: [
        [sequelize.fn('SUM', sequelize.col('quantity')), 'total_quantity'],
        [sequelize.fn('SUM', sequelize.col('estimated_loss')), 'total_estimated_loss'],
        [sequelize.fn('SUM', sequelize.col('actual_loss')), 'total_actual_loss'],
        [sequelize.literal(`SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END)`), 'pending_count'],
        [sequelize.literal(`SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END)`), 'approved_count'],
        [sequelize.literal(`SUM(CASE WHEN status = 'disposed' THEN 1 ELSE 0 END)`), 'disposed_count'],
        [sequelize.literal(`SUM(CASE WHEN status = 'repaired' THEN 1 ELSE 0 END)`), 'repaired_count']
      ],
      raw: true
    });

    res.json({
      success: true,
      data: {
        items: rows,
        pagination: {
          total: count,
          page: pageNum,
          limit: limitNum,
          total_pages: Math.ceil(count / limitNum)
        },
        summary: {
          total_items: count,
          total_quantity: parseInt(stats[0]?.total_quantity || 0),
          total_estimated_loss: parseFloat(stats[0]?.total_estimated_loss || 0),
          total_actual_loss: parseFloat(stats[0]?.total_actual_loss || 0),
          pending_count: parseInt(stats[0]?.pending_count || 0),
          approved_count: parseInt(stats[0]?.approved_count || 0),
          disposed_count: parseInt(stats[0]?.disposed_count || 0),
          repaired_count: parseInt(stats[0]?.repaired_count || 0)
        }
      }
    });
  } catch (error) {
    console.error('Get damaged stock error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Get single damaged stock item
exports.getDamagedStockById = async (req, res) => {
  try {
    const { id } = req.params;

    const damagedItem = await DamagedStock.findByPk(id, {
      include: [
        {
          model: Product,
          as: 'product',
          attributes: ['id', 'item_name', 'barcode', 'cost_price', 'sale_price', 'physical_qty', 'available_qty', 'min_stock'],
          include: [
            { model: Supplier, as: 'supplier', attributes: ['id', 'name', 'contact'] },
            { model: Category, as: 'category', attributes: ['id', 'name'] },
            { model: Unit, as: 'unit', attributes: ['id', 'name', 'symbol'] }
          ]
        }
      ]
    });

    if (!damagedItem) {
      return res.status(404).json({ success: false, message: 'Damaged stock record not found' });
    }

    // Get the product data
    const product = damagedItem.product;
    
    // Create response with flat structure for easy access
    const responseData = {
      id: damagedItem.id,
      product_id: damagedItem.product_id,
      quantity: damagedItem.quantity,
      reason: damagedItem.reason,
      status: damagedItem.status,
      notes: damagedItem.notes,
      approved_by: damagedItem.approved_by,
      approved_at: damagedItem.approved_at,
      disposed_by: damagedItem.disposed_by,
      disposed_at: damagedItem.disposed_at,
      repaired_by: damagedItem.repaired_by,
      repaired_at: damagedItem.repaired_at,
      repair_notes: damagedItem.repair_notes,
      estimated_loss: damagedItem.estimated_loss,
      actual_loss: damagedItem.actual_loss,
      created_at: damagedItem.created_at,
      updated_at: damagedItem.updated_at,
      // Product fields flattened
      product_name: product ? product.item_name : null,
      product_barcode: product ? product.barcode : null,
      product_cost_price: product ? parseFloat(product.cost_price) : null,
      product_sale_price: product ? parseFloat(product.sale_price) : null,
      // Include full product object if needed
      product: product
    };

    res.json({ success: true, data: responseData });
  } catch (error) {
    console.error('Get damaged stock by ID error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Create new damaged stock entry
exports.createDamagedStock = async (req, res) => {
  const transaction = await sequelize.transaction();

  try {
    const {
      product_id,
      quantity,
      reason,
      notes,
      estimated_loss
    } = req.body;

    // Validate required fields
    if (!product_id || !quantity || !reason) {
      return res.status(400).json({
        success: false,
        message: 'Product ID, quantity, and reason are required'
      });
    }

    // Check if product exists
    const product = await Product.findByPk(product_id, { transaction });
    if (!product) {
      await transaction.rollback();
      return res.status(404).json({ success: false, message: 'Product not found' });
    }

    // Check if enough stock available
    if (quantity > product.physical_qty) {
      await transaction.rollback();
      return res.status(400).json({
        success: false,
        message: `Insufficient stock. Available: ${product.physical_qty}, Requested: ${quantity}`
      });
    }

    // Calculate estimated loss if not provided
    let finalEstimatedLoss = estimated_loss;
    if (!finalEstimatedLoss) {
      finalEstimatedLoss = product.cost_price * quantity;
    }

    // Create damaged stock record
    const damagedStock = await DamagedStock.create({
      product_id,
      quantity,
      reason,
      notes,
      estimated_loss: finalEstimatedLoss,
      status: 'pending'
    }, { transaction });

    // Reduce product quantity
    await product.update({
      physical_qty: product.physical_qty - quantity,
      available_qty: product.available_qty - quantity
    }, { transaction });

    await transaction.commit();

    // Fetch the created record with associations
    const created = await DamagedStock.findByPk(damagedStock.id, {
      include: [
        {
          model: Product,
          as: 'product',
          attributes: ['id', 'item_name', 'barcode', 'cost_price', 'sale_price']
        }
      ]
    });

    res.status(201).json({
      success: true,
      message: 'Damaged stock reported successfully',
      data: created
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Create damaged stock error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Update damaged stock status
exports.updateDamagedStatus = async (req, res) => {
  const transaction = await sequelize.transaction();

  try {
    const { id } = req.params;
    const {
      status,
      notes,
      actual_loss,
      repair_notes
    } = req.body;

    const damagedItem = await DamagedStock.findByPk(id, { transaction });
    if (!damagedItem) {
      await transaction.rollback();
      return res.status(404).json({ success: false, message: 'Damaged stock record not found' });
    }

    const updateData = { status };

    switch (status) {
      case 'approved':
        updateData.approved_by = req.user?.name || 'System';
        updateData.approved_at = new Date();
        if (notes) updateData.notes = notes;
        if (actual_loss !== undefined) updateData.actual_loss = actual_loss;
        break;

      case 'disposed':
        updateData.disposed_by = req.user?.name || 'System';
        updateData.disposed_at = new Date();
        if (notes) updateData.notes = notes;
        if (actual_loss !== undefined) updateData.actual_loss = actual_loss;
        break;

      case 'repaired':
        updateData.repaired_by = req.user?.name || 'System';
        updateData.repaired_at = new Date();
        if (repair_notes) updateData.repair_notes = repair_notes;
        if (notes) updateData.notes = notes;
        if (actual_loss !== undefined) updateData.actual_loss = actual_loss;
        
        // For repaired items, add quantity back to stock
        const product = await Product.findByPk(damagedItem.product_id, { transaction });
        if (product) {
          await product.update({
            physical_qty: product.physical_qty + damagedItem.quantity,
            available_qty: product.available_qty + damagedItem.quantity
          }, { transaction });
        }
        break;

      default:
        await transaction.rollback();
        return res.status(400).json({ success: false, message: 'Invalid status' });
    }

    await damagedItem.update(updateData, { transaction });
    await transaction.commit();

    const updated = await DamagedStock.findByPk(id, {
      include: [
        {
          model: Product,
          as: 'product',
          attributes: ['id', 'item_name', 'barcode', 'physical_qty', 'available_qty']
        }
      ]
    });

    res.json({
      success: true,
      message: `Damaged stock ${status} successfully`,
      data: updated
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Update damaged status error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Delete damaged stock record
exports.deleteDamagedStock = async (req, res) => {
  const transaction = await sequelize.transaction();

  try {
    const { id } = req.params;

    const damagedItem = await DamagedStock.findByPk(id, { transaction });
    if (!damagedItem) {
      await transaction.rollback();
      return res.status(404).json({ success: false, message: 'Damaged stock record not found' });
    }

    // If status is not disposed or repaired, restore the quantity
    if (damagedItem.status !== 'disposed' && damagedItem.status !== 'repaired') {
      const product = await Product.findByPk(damagedItem.product_id, { transaction });
      if (product) {
        await product.update({
          physical_qty: product.physical_qty + damagedItem.quantity,
          available_qty: product.available_qty + damagedItem.quantity
        }, { transaction });
      }
    }

    await damagedItem.destroy({ transaction });
    await transaction.commit();

    res.json({
      success: true,
      message: 'Damaged stock record deleted successfully'
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Delete damaged stock error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Get damaged stock statistics
exports.getDamagedStockStatistics = async (req, res) => {
  try {
    const { from_date, to_date } = req.query;
    const whereClause = {};

    if (from_date && to_date) {
      whereClause.created_at = {
        [Op.between]: [new Date(from_date), new Date(to_date)]
      };
    }

    const stats = await DamagedStock.findAll({
      where: whereClause,
      attributes: [
        [sequelize.fn('COUNT', sequelize.col('id')), 'total_records'],
        [sequelize.fn('SUM', sequelize.col('quantity')), 'total_quantity'],
        [sequelize.fn('SUM', sequelize.col('estimated_loss')), 'total_estimated_loss'],
        [sequelize.fn('SUM', sequelize.col('actual_loss')), 'total_actual_loss'],
        [sequelize.literal(`SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END)`), 'pending'],
        [sequelize.literal(`SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END)`), 'approved'],
        [sequelize.literal(`SUM(CASE WHEN status = 'disposed' THEN 1 ELSE 0 END)`), 'disposed'],
        [sequelize.literal(`SUM(CASE WHEN status = 'repaired' THEN 1 ELSE 0 END)`), 'repaired']
      ],
      raw: true
    });

    // Get damage reasons breakdown
    const reasonsBreakdown = await DamagedStock.findAll({
      where: whereClause,
      attributes: [
        'reason',
        [sequelize.fn('COUNT', sequelize.col('id')), 'count'],
        [sequelize.fn('SUM', sequelize.col('quantity')), 'total_quantity'],
        [sequelize.fn('SUM', sequelize.col('estimated_loss')), 'total_loss']
      ],
      group: ['reason'],
      raw: true
    });

    // Get monthly trend (last 6 months)
    const monthlyTrend = await DamagedStock.findAll({
      where: {
        created_at: {
          [Op.gte]: sequelize.literal("DATE_SUB(CURDATE(), INTERVAL 6 MONTH)")
        }
      },
      attributes: [
        [sequelize.fn('DATE_FORMAT', sequelize.col('created_at'), '%Y-%m'), 'month'],
        [sequelize.fn('COUNT', sequelize.col('id')), 'count'],
        [sequelize.fn('SUM', sequelize.col('quantity')), 'total_quantity'],
        [sequelize.fn('SUM', sequelize.col('estimated_loss')), 'total_loss']
      ],
      group: [sequelize.fn('DATE_FORMAT', sequelize.col('created_at'), '%Y-%m')],
      order: [[sequelize.fn('DATE_FORMAT', sequelize.col('created_at'), '%Y-%m'), 'ASC']],
      raw: true
    });

    res.json({
      success: true,
      data: {
        summary: stats[0] || {},
        reasons_breakdown: reasonsBreakdown,
        monthly_trend: monthlyTrend
      }
    });
  } catch (error) {
    console.error('Get damaged stock statistics error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Delete damaged stock record (with automatic restock)
exports.deleteDamagedStock = async (req, res) => {
  const transaction = await sequelize.transaction();

  try {
    const { id } = req.params;

    const damagedItem = await DamagedStock.findByPk(id, { transaction });
    if (!damagedItem) {
      await transaction.rollback();
      return res.status(404).json({ success: false, message: 'Damaged stock record not found' });
    }

    // Get the product before deleting
    const product = await Product.findByPk(damagedItem.product_id, { transaction });
    if (!product) {
      await transaction.rollback();
      return res.status(404).json({ success: false, message: 'Product not found' });
    }

    // RESTOCK THE ITEM - Add back the damaged quantity to inventory
    // Only restock if status is NOT 'disposed' (disposed items are physically gone)
    // and NOT 'repaired' (repaired items were already added back)
    if (damagedItem.status !== 'disposed' && damagedItem.status !== 'repaired') {
      await product.update({
        physical_qty: product.physical_qty + damagedItem.quantity,
        available_qty: product.available_qty + damagedItem.quantity
      }, { transaction });
      
      console.log(`✅ Restocked ${damagedItem.quantity} units of product ${product.item_name}`);
    } else if (damagedItem.status === 'disposed') {
      console.log(`⚠️  Not restocking disposed item - quantity ${damagedItem.quantity} was already lost`);
    } else if (damagedItem.status === 'repaired') {
      console.log(`⚠️  Not restocking repaired item - quantity ${damagedItem.quantity} was already added back when repaired`);
    }

    // Delete the damaged stock record
    await damagedItem.destroy({ transaction });
    await transaction.commit();

    res.json({
      success: true,
      message: 'Damaged stock record deleted successfully',
      data: {
        restocked: (damagedItem.status !== 'disposed' && damagedItem.status !== 'repaired'),
        quantity_restocked: (damagedItem.status !== 'disposed' && damagedItem.status !== 'repaired') ? damagedItem.quantity : 0,
        product_name: product.item_name,
        new_quantity: product.physical_qty + (damagedItem.status !== 'disposed' && damagedItem.status !== 'repaired' ? damagedItem.quantity : 0)
      }
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Delete damaged stock error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};