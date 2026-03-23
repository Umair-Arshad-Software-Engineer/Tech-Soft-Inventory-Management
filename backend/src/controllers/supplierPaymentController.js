// backend/src/controllers/supplierPaymentController.js
const { Op } = require('sequelize');
const { SupplierLedger, Supplier, sequelize } = require('../models');
const { recalculateBalances } = require('./supplierLedgerController'); // ADD

// ── POST /suppliers/:supplierId/payments ──────────────────────────────────
exports.createSupplierPayment = async (req, res) => {
  const transaction = await sequelize.transaction();
  try {
    const { supplierId } = req.params;
    const {
      amount,
      payment_method,
      bank_name,
      cheque_number,
      cheque_date,
      reference_number,
      description,
      transaction_date,
    } = req.body;

    if (!amount || parseFloat(amount) <= 0)
      return res.status(400).json({ success: false, message: 'Valid amount is required' });
    if (!payment_method)
      return res.status(400).json({ success: false, message: 'Payment method is required' });

    const supplier = await Supplier.findByPk(supplierId);
    if (!supplier)
      return res.status(404).json({ success: false, message: 'Supplier not found' });

    const methodLabel = { cash: 'Cash', bank: 'Bank Transfer', cheque: 'Cheque', slip: 'Slip' }[payment_method] || payment_method;
    const autoDesc = [
      `Payment to ${supplier.name} via ${methodLabel}`,
      bank_name        ? `| Bank: ${bank_name}`       : null,
      cheque_number    ? `| Chq# ${cheque_number}`    : null,
      reference_number ? `| Ref: ${reference_number}` : null,
    ].filter(Boolean).join(' ');

    const finalDescription = description?.trim() || autoDesc;

    // INSERT with temporary balance — recalculate will correct it
    const entry = await SupplierLedger.create({
      supplier_id:      supplierId,
      reference_type:   'payment',
      reference_id:     null,
      reference_number: reference_number || cheque_number || null,
      debit:            parseFloat(amount).toFixed(2),
      credit:           '0.00',
      balance:          '0.00',   // temporary
      description:      finalDescription,
      transaction_date: transaction_date ? new Date(transaction_date) : new Date(),
      payment_method,
      bank_name:     bank_name     || null,
      cheque_number: cheque_number || null,
      cheque_date:   cheque_date   ? new Date(cheque_date) : null,
      created_by:    req.user?.id,
    }, { transaction });

    // Recalculate ALL balances in transaction_date ASC, id ASC order
    await recalculateBalances(supplierId, transaction);
    await entry.reload({ transaction });

    await transaction.commit();

    res.status(201).json({
      success: true,
      message: 'Payment recorded successfully',
      data: { entry },
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Supplier payment error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// ── GET /suppliers/:supplierId/payments ───────────────────────────────────
exports.getSupplierPayments = async (req, res) => {
  try {
    const { supplierId } = req.params;
    const { payment_method, from, to, page = 1, limit = 50 } = req.query;

    const where = {
      supplier_id:    supplierId,
      reference_type: 'payment',
    };

    if (payment_method && payment_method !== 'all') {
      where.payment_method = payment_method;
    }

    if (from || to) {
      where.transaction_date = {};
      if (from) where.transaction_date[Op.gte] = new Date(from);
      if (to) {
        const toDate = new Date(to);
        toDate.setHours(23, 59, 59, 999);
        where.transaction_date[Op.lte] = toDate;
      }
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);

    const { count, rows } = await SupplierLedger.findAndCountAll({
      where,
      order: [['transaction_date', 'DESC'], ['id', 'DESC']],
      limit:  parseInt(limit),
      offset,
    });

    const totalPaid = await SupplierLedger.sum('debit', { where }) || 0;

    res.json({
      success: true,
      data: {
        payments: rows,
        totalPaid,
        pagination: {
          total: count,
          page:  parseInt(page),
          pages: Math.ceil(count / parseInt(limit)),
        },
      },
    });
  } catch (error) {
    console.error('Get payments error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// ── DELETE /suppliers/:supplierId/payments/:paymentId ─────────────────────
exports.deleteSupplierPayment = async (req, res) => {
  const transaction = await sequelize.transaction();
  try {
    const { supplierId, paymentId } = req.params;

    const entry = await SupplierLedger.findOne({
      where: { id: paymentId, supplier_id: supplierId, reference_type: 'payment' },
    });

    if (!entry)
      return res.status(404).json({ success: false, message: 'Payment not found' });

    // Create reversal entry with temporary balance
    await SupplierLedger.create({
      supplier_id:      supplierId,
      reference_type:   'reversal',
      reference_id:     entry.id,
      reference_number: entry.reference_number ? `REV-${entry.reference_number}` : null,
      debit:            '0.00',
      credit:           parseFloat(entry.debit).toFixed(2),
      balance:          '0.00',   // temporary
      description:      `Reversal of payment: ${entry.description}`,
      transaction_date: new Date(),
      created_by:       req.user?.id,
    }, { transaction });

    await entry.destroy({ transaction });

    // Recalculate ALL balances after delete + reversal
    await recalculateBalances(supplierId, transaction);

    await transaction.commit();

    res.json({ success: true, message: 'Payment deleted and ledger reversed' });
  } catch (error) {
    await transaction.rollback();
    console.error('Delete payment error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};