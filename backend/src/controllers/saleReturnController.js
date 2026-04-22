const { Op } = require('sequelize');
const sequelize = require('../config/db');
const { 
  SaleReturn, 
  SaleReturnItem, 
  Sale, 
  SaleItem, 
  Customer, 
  Product,
  CustomerLedger 
} = require('../models');

// Helper: Generate return number
async function generateReturnNumber() {
  const today = new Date();
  const datePart = `${today.getFullYear()}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}`;
  
  const last = await SaleReturn.findOne({
    where: {
      return_number: { [Op.like]: `RET-${datePart}-%` }
    },
    order: [['id', 'DESC']]
  });

  let seq = 1;
  if (last) {
    const parts = last.return_number.split('-');
    seq = parseInt(parts[parts.length - 1]) + 1;
  }

  return `RET-${datePart}-${String(seq).padStart(4, '0')}`;
}

// Helper: Get customer balance
async function getCustomerBalance(customerId, transaction) {
  const lastEntry = await CustomerLedger.findOne({
    where: { customer_id: customerId },
    order: [['id', 'DESC']],
    transaction
  });
  return lastEntry ? parseFloat(lastEntry.balance) : 0;
}

// Helper: Create ledger entry
async function createLedgerEntry({
  customerId,
  date,
  transactionType,
  referenceId,
  referenceNumber,
  description,
  debit = 0,
  credit = 0,
  transaction
}) {
  const currentBalance = await getCustomerBalance(customerId, transaction);
  const newBalance = currentBalance + debit - credit;
  
  return await CustomerLedger.create({
    customer_id: customerId,
    date: date || new Date(),
    transaction_type: transactionType,
    reference_id: referenceId,
    reference_number: referenceNumber,
    description,
    debit,
    credit,
    balance: newBalance
  }, { transaction });
}

// ─────────────────────────────────────────────
// CREATE SALE RETURN
// ─────────────────────────────────────────────
exports.createSaleReturn = async (req, res) => {
  const t = await sequelize.transaction();
  try {
    const {
      sale_id,
      return_date,
      items,
      refund_method = 'cash',
      adjustment_type = 'refund',
      reason,
      notes
    } = req.body;

    // Validate
    if (!sale_id) {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'Sale ID is required' });
    }

    if (!items || !Array.isArray(items) || items.length === 0) {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'At least one item must be returned' });
    }

    // Get original sale
    const originalSale = await Sale.findByPk(sale_id, {
      include: [
        { model: SaleItem, as: 'items' },
        { model: Customer, as: 'customer' }
      ],
      transaction: t
    });

    if (!originalSale) {
      await t.rollback();
      return res.status(404).json({ success: false, message: 'Original sale not found' });
    }

    // Get already returned quantities for each sale item
    const existingReturns = await SaleReturnItem.findAll({
      include: [{
        model: SaleReturn,
        as: 'return',
        where: { sale_id: sale_id, status: 'completed' },
        attributes: []
      }],
      where: {
        sale_item_id: { [Op.in]: originalSale.items.map(item => item.id) }
      },
      attributes: ['sale_item_id', [sequelize.fn('SUM', sequelize.col('quantity_returned')), 'total_returned']],
      group: ['sale_item_id'],
      transaction: t
    });

    // Create a map of already returned quantities
    const returnedMap = {};
    for (const ret of existingReturns) {
      returnedMap[ret.sale_item_id] = parseFloat(ret.dataValues.total_returned);
    }

    // Calculate refund amount and validate items
    let totalRefundAmount = 0;
    const returnItems = [];

    for (const returnItem of items) {
      const originalSaleItem = originalSale.items.find(
        item => item.id === returnItem.sale_item_id
      );

      if (!originalSaleItem) {
        await t.rollback();
        return res.status(404).json({ 
          success: false, 
          message: `Sale item ${returnItem.sale_item_id} not found in original sale` 
        });
      }

      if (returnItem.quantity_returned > originalSaleItem.quantity) {
        await t.rollback();
        return res.status(400).json({
          success: false,
          message: `Return quantity cannot exceed original quantity for ${originalSaleItem.product_name}`
        });
      }

      const refundUnitPrice = returnItem.refund_unit_price || originalSaleItem.unit_price;
      const totalRefund = refundUnitPrice * returnItem.quantity_returned;
      totalRefundAmount += totalRefund;

      returnItems.push({
        sale_item_id: originalSaleItem.id,
        product_id: originalSaleItem.product_id,
        product_name: originalSaleItem.product_name,
        quantity_returned: returnItem.quantity_returned,
        original_unit_price: originalSaleItem.unit_price,
        refund_unit_price: refundUnitPrice,
        total_refund: totalRefund,
        reason: returnItem.reason || null,
        condition: returnItem.condition || 'sellable'
      });
    }

    // Generate return number
    const returnNumber = await generateReturnNumber();

    // Determine return type
    const returnType = items.length === originalSale.items.length && 
      items.every((item, idx) => item.quantity_returned === originalSale.items[idx].quantity)
      ? 'full' : 'partial';

    // Create return record
    const saleReturn = await SaleReturn.create({
      return_number: returnNumber,
      sale_id,
      customer_id: originalSale.customer_id,
      return_date: return_date || new Date(),
      return_type: returnType,
      refund_method,
      adjustment_type,
      refund_amount: totalRefundAmount,
      reason,
      notes,
      status: 'completed'
    }, { transaction: t });

    // Create return items
    for (const item of returnItems) {
      await SaleReturnItem.create({
        ...item,
        return_id: saleReturn.id
      }, { transaction: t });
    }

    // Restore stock
    for (const item of returnItems) {
      await Product.increment(
        { physical_qty: item.quantity_returned, available_qty: item.quantity_returned },
        { where: { id: item.product_id }, transaction: t }
      );
    }

    // Handle financial adjustment
    if (adjustment_type === 'refund') {
      // Create refund ledger entry (credit to customer)
      await createLedgerEntry({
        customerId: originalSale.customer_id,
        date: return_date || new Date(),
        transactionType: 'return_refund',
        referenceId: saleReturn.id,
        referenceNumber: returnNumber,
        description: `Refund for return of ${returnNumber} (${returnType} return)`,
        debit: 0,
        credit: totalRefundAmount,
        transaction: t
      });
    } else if (adjustment_type === 'reduce_balance') {
      // Reduce outstanding balance
      const currentBalance = await getCustomerBalance(originalSale.customer_id, t);
      // const newOutstanding = Math.max(0, originalSale.grandTotal - originalSale.amount_paid - totalRefundAmount);
      const newOutstanding = Math.max(0, originalSale.grand_total - originalSale.amount_paid - totalRefundAmount);
      await createLedgerEntry({
        customerId: originalSale.customer_id,
        date: return_date || new Date(),
        transactionType: 'return_adjustment',
        referenceId: saleReturn.id,
        referenceNumber: returnNumber,
        description: `Return adjustment for ${returnNumber} - Reduced outstanding balance`,
        debit: totalRefundAmount,
        credit: 0,
        transaction: t
      });
    }

    // Update customer balance
    const finalBalance = await getCustomerBalance(originalSale.customer_id, t);
    await Customer.update(
      { balance: finalBalance },
      { where: { id: originalSale.customer_id }, transaction: t }
    );

    // Update original sale's return status
    await originalSale.update({
      return_status: returnType === 'full' ? 'fully_returned' : 'partial_return',
      return_amount: (originalSale.return_amount || 0) + totalRefundAmount
    }, { transaction: t });

    await t.commit();

    // Fetch complete return with items
    const completeReturn = await SaleReturn.findByPk(saleReturn.id, {
      include: [
        { model: Customer, as: 'customer', attributes: ['id', 'name', 'contact'] },
        { model: Sale, as: 'originalSale', attributes: ['id', 'invoice_number', 'grand_total', 'amount_paid'] },
        { model: SaleReturnItem, as: 'items' }
      ]
    });

    res.status(201).json({
      success: true,
      message: 'Sale return processed successfully',
      data: completeReturn
    });
  } catch (error) {
    await t.rollback();
    console.error('Create sale return error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// ─────────────────────────────────────────────
// GET RETURNS FOR A SALE
// ─────────────────────────────────────────────
exports.getSaleReturns = async (req, res) => {
  try {
    const { sale_id } = req.params;
    
    const returns = await SaleReturn.findAll({
      where: { sale_id },
      include: [
        { model: Customer, as: 'customer', attributes: ['id', 'name'] },
        { model: SaleReturnItem, as: 'items' }
      ],
      order: [['created_at', 'DESC']]
    });

    res.json({ success: true, data: returns });
  } catch (error) {
    console.error('Get sale returns error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// ─────────────────────────────────────────────
// GET ALL RETURNS (with filters)
// ─────────────────────────────────────────────
exports.getAllReturns = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      customer_id,
      from_date,
      to_date,
      return_type,
      status
    } = req.query;

    const pageNum = parseInt(page);
    const limitNum = parseInt(limit);
    const offset = (pageNum - 1) * limitNum;

    const whereClause = {};
    if (customer_id) whereClause.customer_id = customer_id;
    if (return_type) whereClause.return_type = return_type;
    if (status) whereClause.status = status;
    if (from_date || to_date) {
      whereClause.return_date = {};
      if (from_date) whereClause.return_date[Op.gte] = from_date;
      if (to_date) whereClause.return_date[Op.lte] = to_date;
    }

  const { count, rows: returns } = await SaleReturn.findAndCountAll({
    where: whereClause,
    include: [
      { model: Customer, as: 'customer', attributes: ['id', 'name', 'contact'] },
      { model: Sale, as: 'originalSale', attributes: ['id', 'invoice_number'] },
      { model: SaleReturnItem, as: 'items' }   // ← ADD THIS LINE
    ],
    order: [['created_at', 'DESC']],
    limit: limitNum,
    offset
  });

    // Calculate summary
    const summary = await SaleReturn.findOne({
      where: whereClause,
      attributes: [
        [sequelize.fn('SUM', sequelize.col('refund_amount')), 'total_refunds'],
        [sequelize.fn('COUNT', sequelize.col('id')), 'total_returns']
      ],
      raw: true
    });

    res.json({
      success: true,
      data: returns,
      pagination: {
        total: count,
        page: pageNum,
        limit: limitNum,
        pages: Math.ceil(count / limitNum)
      },
      summary: {
        total_refunds: parseFloat(summary?.total_refunds) || 0,
        total_returns: parseInt(summary?.total_returns) || 0
      }
    });
  } catch (error) {
    console.error('Get all returns error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// ─────────────────────────────────────────────
// GET RETURN BY ID
// ─────────────────────────────────────────────
exports.getReturnById = async (req, res) => {
  try {
    const { id } = req.params;
    
    const saleReturn = await SaleReturn.findByPk(id, {
      include: [
        { model: Customer, as: 'customer', attributes: ['id', 'name', 'contact', 'email'] },
        { 
          model: Sale, 
          as: 'originalSale', 
          include: [{ model: SaleItem, as: 'items' }]
        },
        { model: SaleReturnItem, as: 'items' }
      ]
    });

    if (!saleReturn) {
      return res.status(404).json({ success: false, message: 'Return not found' });
    }

    res.json({ success: true, data: saleReturn });
  } catch (error) {
    console.error('Get return by id error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};