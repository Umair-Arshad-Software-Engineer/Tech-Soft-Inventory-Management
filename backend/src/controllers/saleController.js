// backend/src/controllers/saleController.js
const { Op, fn, col, literal } = require('sequelize');
const sequelize = require('../config/db');
const { Sale, SaleItem, Customer, Product, Unit, Category, CustomerLedger } = require('../models');

// ─────────────────────────────────────────────
//  HELPER: generate invoice number
// ─────────────────────────────────────────────
async function generateInvoiceNumber(type) {
  const prefix = type === 'invoice' ? 'INV' : 'POS';
  const today = new Date();
  const datePart = `${today.getFullYear()}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}`;

  // find last sale of today with same prefix
  const last = await Sale.findOne({
    where: {
      invoice_number: { [Op.like]: `${prefix}-${datePart}-%` },
    },
    order: [['id', 'DESC']],
  });

  let seq = 1;
  if (last) {
    const parts = last.invoice_number.split('-');
    seq = parseInt(parts[parts.length - 1]) + 1;
  }

  return `${prefix}-${datePart}-${String(seq).padStart(4, '0')}`;
}

async function getCustomerBalance(customerId, transaction) {
  const lastEntry = await CustomerLedger.findOne({
    where: { customer_id: customerId },
    order: [['id', 'DESC']],
    transaction,
  });
  return lastEntry ? parseFloat(lastEntry.balance) : 0;
}

// Helper to create ledger entry
async function createLedgerEntry({
  customerId,
  date,
  transactionType,
  referenceId,
  referenceNumber,
  description,
  debit = 0,
  credit = 0,
  transaction,
}) {
  // Get current balance
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
    balance: newBalance,
  }, { transaction });
}

// ─────────────────────────────────────────────
//  GET ALL SALES
// ─────────────────────────────────────────────
exports.getAllSales = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      search,
      sale_type,
      payment_status,
      payment_method,
      customer_id,
      date_from,
      date_to,
      sort_by = 'created_at',
      sort_order = 'DESC',
    } = req.query;

    const pageNum = parseInt(page);
    const limitNum = parseInt(limit);
    const offset = (pageNum - 1) * limitNum;

    const whereClause = {};

    // Build search condition properly
    let includeCustomer = false;
    if (search) {
      includeCustomer = true;
      // We'll handle search in the include condition
    }
    
    if (sale_type) whereClause.sale_type = sale_type;
    if (payment_status) whereClause.payment_status = payment_status;
    if (payment_method) whereClause.payment_method = payment_method;
    if (customer_id) {
      whereClause.customer_id = customer_id;
      includeCustomer = true;
    }
    if (date_from || date_to) {
      whereClause.sale_date = {};
      if (date_from) whereClause.sale_date[Op.gte] = date_from;
      if (date_to) whereClause.sale_date[Op.lte] = date_to;
    }

    // Build include for customer
    const include = [
      {
        model: Customer,
        as: 'customer',
        attributes: ['id', 'name', 'contact', 'customer_type'],
        required: includeCustomer ? true : false, // Only required if we need customer data
        ...(search ? {
          where: {
            name: { [Op.like]: `%${search}%` }
          }
        } : {})
      },
      {
        model: SaleItem,
        as: 'items',
        attributes: ['id', 'product_name', 'quantity', 'unit_price', 'total_price'],
        include: [
          {
            model: Product,
            as: 'product',
            attributes: ['id', 'item_name', 'barcode'],
            required: false,
          },
        ],
      },
    ];

    // Build main where clause with search on invoice_number
    const mainWhereClause = { ...whereClause };
    if (search && !includeCustomer) {
      mainWhereClause.invoice_number = { [Op.like]: `%${search}%` };
    }

    const { count, rows: sales } = await Sale.findAndCountAll({
      where: mainWhereClause,
      include,
      order: [[sort_by, sort_order]],
      limit: limitNum,
      offset,
      distinct: true,
      subQuery: false,
    });

    // Build summary query separately with proper joins
    let summaryWhereClause = { ...whereClause };
    
    // Create a separate query for totals that handles search properly
    let summaryQuery = {
      where: summaryWhereClause,
      attributes: [
        [fn('SUM', col('Sale.grand_total')), 'total_revenue'],
        [fn('SUM', col('Sale.discount_amount')), 'total_discount'],
        [fn('COUNT', col('Sale.id')), 'total_transactions'],
      ],
      raw: true,
    };

    // If searching by customer name, we need to include the join
    if (search) {
      summaryQuery.include = [
        {
          model: Customer,
          as: 'customer',
          required: true,
          where: {
            name: { [Op.like]: `%${search}%` }
          },
          attributes: []
        }
      ];
      // Also search invoice number
      summaryQuery.where = {
        ...summaryWhereClause,
        [Op.or]: [
          { invoice_number: { [Op.like]: `%${search}%` } },
          { '$customer.name$': { [Op.like]: `%${search}%` } }
        ]
      };
    }

    const totals = await Sale.findOne(summaryQuery);

    res.json({
      success: true,
      data: sales,
      pagination: {
        total: count,
        page: pageNum,
        limit: limitNum,
        pages: Math.ceil(count / limitNum),
      },
      summary: {
        total_revenue: parseFloat(totals?.total_revenue) || 0,
        total_discount: parseFloat(totals?.total_discount) || 0,
        total_transactions: parseInt(totals?.total_transactions) || 0,
      },
    });
  } catch (error) {
    console.error('Get all sales error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// ─────────────────────────────────────────────
//  GET SALE BY ID
// ─────────────────────────────────────────────
exports.getSaleById = async (req, res) => {
  try {
    const { id } = req.params;

    const sale = await Sale.findByPk(id, {
      include: [
        {
          model: Customer,
          as: 'customer',
          attributes: ['id', 'name', 'contact', 'address', 'email', 'customer_type'],
        },
        {
          model: SaleItem,
          as: 'items',
          include: [
            {
              model: Product,
              as: 'product',
              attributes: ['id', 'item_name', 'barcode', 'sale_price', 'cost_price'],
              include: [{ model: Unit, as: 'unit', attributes: ['id', 'name', 'symbol'] }],
            },
          ],
        },
      ],
    });

    if (!sale) {
      return res.status(404).json({ success: false, message: 'Sale not found' });
    }

    res.json({ success: true, data: sale });
  } catch (error) {
    console.error('Get sale by id error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// ─────────────────────────────────────────────
//  CREATE SALE  (POS or Invoice) - UPDATED FOR CREDIT
// ─────────────────────────────────────────────
// In backend/src/controllers/saleController.js - update the createSale function
exports.createSale = async (req, res) => {
  const t = await sequelize.transaction();
  try {
    const {
      sale_type = 'pos',
      customer_id,
      sale_date,
      due_date,
      items,
      discount_type = 'fixed',
      discount_value = 0,
      payment_method = 'cash',
      payment_status,
      amount_paid = 0,
      notes,
      credit_details,
    } = req.body;

    // Log received data for debugging
    console.log('Received sale data:', {
      discount_type,
      discount_value,
      amount_paid,
      payment_method
    });

    // ── Validate ─────────────────────────────
    if (!items || !Array.isArray(items) || items.length === 0) {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'Sale must have at least one item' });
    }

    if (sale_type === 'invoice' && !customer_id) {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'Invoice requires a customer' });
    }

    // ── Validate customer ────────────────────
    if (customer_id) {
      const customer = await Customer.findByPk(customer_id, { transaction: t });
      if (!customer) {
        await t.rollback();
        return res.status(404).json({ success: false, message: 'Customer not found' });
      }
    }

    // ── Validate & snapshot products ─────────
    let subtotal = 0;
    const itemSnapshots = [];

    for (const item of items) {
      if (!item.product_id || !item.quantity || item.quantity < 1) {
        await t.rollback();
        return res.status(400).json({
          success: false,
          message: 'Each item must have product_id and quantity >= 1',
        });
      }

      const product = await Product.findByPk(item.product_id, { transaction: t });
      if (!product) {
        await t.rollback();
        return res.status(404).json({
          success: false,
          message: `Product id ${item.product_id} not found`,
        });
      }

      if (product.available_qty < item.quantity) {
        await t.rollback();
        return res.status(400).json({
          success: false,
          message: `Insufficient stock for "${product.item_name}". Available: ${product.available_qty}`,
        });
      }

      const unitPrice = parseFloat(item.unit_price ?? product.sale_price);
      const totalPrice = unitPrice * parseInt(item.quantity);
      subtotal += totalPrice;

      itemSnapshots.push({
        product_id: product.id,
        product_name: product.item_name,
        barcode: product.barcode,
        unit_price: unitPrice,
        quantity: parseInt(item.quantity),
        total_price: totalPrice,
      });
    }

    // ── Calculate totals with discount ─────────────────────
    let discountAmount = 0;
    const discountVal = parseFloat(discount_value) || 0;
    
    if (discount_type === 'percent') {
      discountAmount = subtotal * (discountVal / 100);
    } else {
      discountAmount = discountVal;
    }
    
    // Ensure discount doesn't exceed subtotal
    discountAmount = Math.min(discountAmount, subtotal);
    const grandTotal = subtotal - discountAmount;

    console.log('Calculated totals:', {
      subtotal,
      discount_type,
      discount_value: discountVal,
      discountAmount,
      grandTotal
    });

    // Check if this is a credit sale
    const isCredit = payment_method === 'credit';
    
    // For credit sales, amount paid should be 0
    const paid = isCredit ? 0 : (parseFloat(amount_paid) || (sale_type === 'pos' ? grandTotal : 0));
    const changeAmount = Math.max(paid - grandTotal, 0);

    // ── Determine payment status ─────────────
    let resolvedPaymentStatus = payment_status;
    if (!resolvedPaymentStatus) {
      if (isCredit) {
        resolvedPaymentStatus = 'unpaid';
      } else if (sale_type === 'pos') {
        resolvedPaymentStatus = 'paid';
      } else {
        resolvedPaymentStatus = paid >= grandTotal ? 'paid' : paid > 0 ? 'partial' : 'unpaid';
      }
    }

    // ── Generate invoice number ───────────────
    const invoiceNumber = await generateInvoiceNumber(sale_type);

    // ── Prepare notes with credit information ──
    let finalNotes = notes || '';
    if (isCredit && credit_details) {
      const creditNotes = [];
      if (credit_details.notes) {
        creditNotes.push(`Credit Note: ${credit_details.notes}`);
      }
      if (credit_details.due_date) {
        const dueDate = new Date(credit_details.due_date);
        creditNotes.push(`Due Date: ${dueDate.toISOString().split('T')[0]}`);
      }
      if (creditNotes.length > 0) {
        finalNotes = finalNotes 
          ? `${finalNotes}\n${creditNotes.join('\n')}`
          : creditNotes.join('\n');
      }
    }

    // ── Create sale ───────────────────────────
    const sale = await Sale.create(
      {
        invoice_number: invoiceNumber,
        sale_type,
        customer_id: customer_id || null,
        sale_date: sale_date || new Date(),
        due_date: isCredit && credit_details?.due_date 
          ? credit_details.due_date 
          : due_date || null,
        subtotal,
        discount_type,
        discount_value: discountVal,
        discount_amount: discountAmount,
        tax_amount: 0,
        grand_total: grandTotal,
        amount_paid: paid,
        change_amount: changeAmount,
        payment_method,
        payment_status: resolvedPaymentStatus,
        notes: finalNotes || null,
      },
      { transaction: t }
    );

    console.log('Sale created:', sale.toJSON());

    // ── Create sale items ─────────────────────
    const saleItems = itemSnapshots.map((snap) => ({ ...snap, sale_id: sale.id }));
    await SaleItem.bulkCreate(saleItems, { transaction: t });

    // ── Deduct stock for each product ─────────
    for (const snap of itemSnapshots) {
      await Product.decrement(
        { physical_qty: snap.quantity, available_qty: snap.quantity },
        { where: { id: snap.product_id }, transaction: t }
      );
    }

    // ── Create LEDGER ENTRY for the sale ─────
    if (customer_id) {
      const outstanding = grandTotal - paid;
      
      const debitAmount = isCredit ? grandTotal : (grandTotal - paid);
      
      if (debitAmount > 0) {
        await createLedgerEntry({
          customerId: customer_id,
          date: sale_date || new Date(),
          transactionType: 'sale',
          referenceId: sale.id,
          referenceNumber: invoiceNumber,
          description: `Sale ${invoiceNumber} - ${sale_type === 'invoice' ? 'Invoice' : 'POS'}${isCredit ? ' (Credit)' : ''}`,
          debit: debitAmount,
          credit: 0,
          transaction: t,
        });
      }

      if (paid > 0) {
        await createLedgerEntry({
          customerId: customer_id,
          date: sale_date || new Date(),
          transactionType: 'payment',
          referenceId: sale.id,
          referenceNumber: invoiceNumber,
          description: `Payment received for ${invoiceNumber} (${payment_method})`,
          debit: 0,
          credit: paid,
          transaction: t,
        });
      }

      const finalBalance = await getCustomerBalance(customer_id, t);
      await Customer.update(
        { balance: finalBalance },
        { where: { id: customer_id }, transaction: t }
      );
    }

    await t.commit();

    // ── Return full sale ──────────────────────
    const created = await Sale.findByPk(sale.id, {
      include: [
        { model: Customer, as: 'customer', attributes: ['id', 'name', 'contact', 'balance'] },
        {
          model: SaleItem,
          as: 'items',
          include: [
            {
              model: Product,
              as: 'product',
              attributes: ['id', 'item_name', 'barcode'],
              include: [{ model: Unit, as: 'unit', attributes: ['id', 'name', 'symbol'] }],
            },
          ],
        },
      ],
    });

    const message = isCredit 
      ? `${sale_type === 'invoice' ? 'Credit invoice' : 'Credit sale'} created successfully`
      : `${sale_type === 'invoice' ? 'Invoice' : 'Sale'} created successfully`;

    res.status(201).json({
      success: true,
      message,
      data: created,
    });
  } catch (error) {
    await t.rollback();
    console.error('Create sale error:', error);

    if (error.name === 'SequelizeValidationError') {
      return res.status(400).json({
        success: false,
        message: 'Validation error',
        errors: error.errors.map((e) => e.message),
      });
    }

    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// ─────────────────────────────────────────────
//  UPDATE SALE (invoice only — limited fields)
// ─────────────────────────────────────────────
exports.updateSale = async (req, res) => {
  try {
    const { id } = req.params;
    const { due_date, payment_status, payment_method, amount_paid, notes } = req.body;

    const sale = await Sale.findByPk(id);
    if (!sale) {
      return res.status(404).json({ success: false, message: 'Sale not found' });
    }

    if (sale.payment_status === 'paid' && payment_status && payment_status !== 'paid') {
      return res.status(400).json({
        success: false,
        message: 'Cannot change status of a fully paid sale',
      });
    }

    await sale.update({
      due_date: due_date !== undefined ? due_date : sale.due_date,
      payment_status: payment_status || sale.payment_status,
      payment_method: payment_method || sale.payment_method,
      amount_paid: amount_paid !== undefined ? parseFloat(amount_paid) : sale.amount_paid,
      notes: notes !== undefined ? notes : sale.notes,
    });

    const updated = await Sale.findByPk(id, {
      include: [
        { model: Customer, as: 'customer', attributes: ['id', 'name', 'contact'] },
        {
          model: SaleItem,
          as: 'items',
          include: [
            {
              model: Product,
              as: 'product',
              attributes: ['id', 'item_name', 'barcode'],
            },
          ],
        },
      ],
    });

    res.json({ success: true, message: 'Sale updated successfully', data: updated });
  } catch (error) {
    console.error('Update sale error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// ─────────────────────────────────────────────
//  DELETE / VOID SALE
// ─────────────────────────────────────────────
exports.deleteSale = async (req, res) => {
  const t = await sequelize.transaction();
  try {
    const { id } = req.params;

    const sale = await Sale.findByPk(id, {
      include: [{ model: SaleItem, as: 'items' }],
    });
    
    if (!sale) {
      await t.rollback();
      return res.status(404).json({ success: false, message: 'Sale not found' });
    }

    // Restore stock
    for (const item of sale.items) {
      await Product.increment(
        { physical_qty: item.quantity, available_qty: item.quantity },
        { where: { id: item.product_id }, transaction: t }
      );
    }

    // ── Reverse ledger entries ──────────────
    if (sale.customer_id) {
      // Create reversal entries (opposite of original)
      await createLedgerEntry({
        customerId: sale.customer_id,
        date: new Date(),
        transactionType: 'adjustment',
        referenceId: sale.id,
        referenceNumber: sale.invoice_number,
        description: `VOID: Sale ${sale.invoice_number} reversed`,
        debit: sale.amount_paid > 0 ? 0 : sale.grand_total, // If paid, credit; if unpaid, debit
        credit: sale.amount_paid > 0 ? sale.grand_total : 0,
        transaction: t,
      });

      // Update customer balance
      const finalBalance = await getCustomerBalance(sale.customer_id, t);
      await Customer.update(
        { balance: finalBalance },
        { where: { id: sale.customer_id }, transaction: t }
      );
    }

    await SaleItem.destroy({ where: { sale_id: id }, transaction: t });
    await sale.destroy({ transaction: t });

    await t.commit();

    res.json({ success: true, message: 'Sale voided, stock restored, and ledger reversed successfully' });
  } catch (error) {
    await t.rollback();
    console.error('Delete sale error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// ─────────────────────────────────────────────
//  GET DAILY SALES SUMMARY
// ─────────────────────────────────────────────
exports.getDailySummary = async (req, res) => {
  try {
    const { date } = req.query;
    const targetDate = date || new Date().toISOString().split('T')[0];

    const sales = await Sale.findAll({
      where: {
        sale_date: targetDate,
        payment_status: { [Op.ne]: 'draft' },
      },
      attributes: [
        'sale_type',
        'payment_method',
        'payment_status',
        [fn('COUNT', col('id')), 'count'],
        [fn('SUM', col('grand_total')), 'total'],
        [fn('SUM', col('discount_amount')), 'discount'],
      ],
      group: ['sale_type', 'payment_method', 'payment_status'],
      raw: true,
    });

    const overall = await Sale.findOne({
      where: {
        sale_date: targetDate,
        payment_status: { [Op.ne]: 'draft' },
      },
      attributes: [
        [fn('COUNT', col('id')), 'total_transactions'],
        [fn('SUM', col('grand_total')), 'total_revenue'],
        [fn('SUM', col('discount_amount')), 'total_discount'],
        [fn('SUM', col('amount_paid')), 'total_collected'],
      ],
      raw: true,
    });

    // Calculate credit sales total
    const creditSalesTotal = await Sale.sum('grand_total', {
      where: {
        sale_date: targetDate,
        payment_method: 'credit',
        payment_status: { [Op.ne]: 'draft' },
      },
    });

    res.json({
      success: true,
      data: {
        date: targetDate,
        breakdown: sales,
        summary: {
          total_transactions: parseInt(overall.total_transactions) || 0,
          total_revenue: parseFloat(overall.total_revenue) || 0,
          total_discount: parseFloat(overall.total_discount) || 0,
          total_collected: parseFloat(overall.total_collected) || 0,
          total_credit: parseFloat(creditSalesTotal) || 0,
        },
      },
    });
  } catch (error) {
    console.error('Daily summary error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// ─────────────────────────────────────────────
//  RECORD PAYMENT (for unpaid/partial invoices)
// ─────────────────────────────────────────────
exports.recordPayment = async (req, res) => {
  const t = await sequelize.transaction();
  try {
    const { id } = req.params;
    const { amount, payment_method, payment_date, notes, cheque_number, bank_name, cheque_date } = req.body;

    if (!amount || parseFloat(amount) <= 0) {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'Valid amount is required' });
    }

    const sale = await Sale.findByPk(id, { 
      include: [{ model: Customer, as: 'customer' }],
      transaction: t 
    });
    
    if (!sale) {
      await t.rollback();
      return res.status(404).json({ success: false, message: 'Sale not found' });
    }
    
    if (sale.payment_status === 'paid') {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'Sale is already fully paid' });
    }

    const newPaid = parseFloat(sale.amount_paid) + parseFloat(amount);
    const newStatus = newPaid >= parseFloat(sale.grand_total) ? 'paid' : 'partial';

    // Build payment details for notes
    let paymentNotes = notes || '';
    if (payment_method === 'cheque' && cheque_number) {
      paymentNotes = paymentNotes 
        ? `${paymentNotes}\nCheque #: ${cheque_number}, Bank: ${bank_name || 'N/A'}, Date: ${cheque_date ? new Date(cheque_date).toISOString().split('T')[0] : 'N/A'}`
        : `Payment via Cheque #${cheque_number}, Bank: ${bank_name || 'N/A'}, Date: ${cheque_date ? new Date(cheque_date).toISOString().split('T')[0] : 'N/A'}`;
    }

    await sale.update(
      {
        amount_paid: newPaid,
        payment_status: newStatus,
        payment_method: payment_method || sale.payment_method,
        notes: paymentNotes ? (sale.notes ? `${sale.notes}\n${paymentNotes}` : paymentNotes) : sale.notes,
      },
      { transaction: t }
    );

    // ── Create LEDGER ENTRY for payment ─────
    if (sale.customer_id) {
      await createLedgerEntry({
        customerId: sale.customer_id,
        date: payment_date || new Date(),
        transactionType: 'payment',
        referenceId: sale.id,
        referenceNumber: sale.invoice_number,
        description: paymentNotes || `Payment received for ${sale.invoice_number} (${payment_method || sale.payment_method})`,
        debit: 0,
        credit: parseFloat(amount),
        transaction: t,
      });

      // Update customer balance
      const finalBalance = await getCustomerBalance(sale.customer_id, t);
      await Customer.update(
        { balance: finalBalance },
        { where: { id: sale.customer_id }, transaction: t }
      );
    }

    await t.commit();

    const updated = await Sale.findByPk(id, {
      include: [{ model: Customer, as: 'customer', attributes: ['id', 'name', 'balance'] }],
    });

    res.json({ success: true, message: 'Payment recorded successfully', data: updated });
  } catch (error) {
    await t.rollback();
    console.error('Record payment error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// ─────────────────────────────────────────────
//  GET CREDIT SALES SUMMARY
// ─────────────────────────────────────────────
exports.getCreditSalesSummary = async (req, res) => {
  try {
    const { customer_id } = req.query;
    
    const whereClause = {
      payment_method: 'credit',
      payment_status: { [Op.ne]: 'paid' },
    };
    
    if (customer_id) {
      whereClause.customer_id = customer_id;
    }

    const creditSales = await Sale.findAll({
      where: whereClause,
      include: [
        {
          model: Customer,
          as: 'customer',
          attributes: ['id', 'name', 'contact'],
        },
      ],
      order: [['due_date', 'ASC']],
    });

    const totalOutstanding = creditSales.reduce((sum, sale) => 
      sum + (sale.grand_total - sale.amount_paid), 0
    );

    const overdueSales = creditSales.filter(sale => 
      sale.due_date && new Date(sale.due_date) < new Date() && sale.payment_status !== 'paid'
    );

    res.json({
      success: true,
      data: {
        credit_sales: creditSales,
        summary: {
          total_outstanding: totalOutstanding,
          total_credit_sales: creditSales.length,
          overdue_count: overdueSales.length,
          overdue_amount: overdueSales.reduce((sum, sale) => 
            sum + (sale.grand_total - sale.amount_paid), 0
          ),
        },
      },
    });
  } catch (error) {
    console.error('Get credit sales summary error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};