// backend/src/controllers/customerLedgerController.js
const { Op } = require('sequelize');
const sequelize = require('../config/db');
const { CustomerLedger, Customer } = require('../models');

// ─────────────────────────────────────────────
//  GET LEDGER ENTRIES FOR A CUSTOMER
// ─────────────────────────────────────────────
exports.getCustomerLedger = async (req, res) => {
  try {
    const { customerId } = req.params;
    const { page = 1, limit = 50, from_date, to_date, transaction_type } = req.query;

    const pageNum = parseInt(page);
    const limitNum = parseInt(limit);
    const offset = (pageNum - 1) * limitNum;

    const customer = await Customer.findByPk(customerId);
    if (!customer) {
      return res.status(404).json({ success: false, message: 'Customer not found' });
    }

    // Build where clause for filtered view
    const filteredWhere = { customer_id: customerId };
    if (from_date || to_date) {
      filteredWhere.date = {};
      if (from_date) filteredWhere.date[Op.gte] = from_date;
      if (to_date)   filteredWhere.date[Op.lte] = to_date;
    }
    if (transaction_type) filteredWhere.transaction_type = transaction_type;

    // Always sort by date ASC, id ASC (id is tiebreaker = insertion order)
    const ORDER = [['date', 'ASC'], ['id', 'ASC']];

    // Opening balance = sum of all entries BEFORE the date filter window
    // (ignore transaction_type filter so opening balance is always accurate)
    let openingBalance = 0;
    if (from_date) {
      const beforeEntries = await CustomerLedger.findAll({
        where: { customer_id: customerId, date: { [Op.lt]: from_date } },
        attributes: ['debit', 'credit'],
        raw: true,
      });
      openingBalance = beforeEntries.reduce(
        (sum, e) => sum + parseFloat(e.debit) - parseFloat(e.credit), 0
      );
    }

    // Fetch ALL matching entries (needed to compute correct running balances
    // before applying pagination slice)
    const allMatchingEntries = await CustomerLedger.findAll({
      where: filteredWhere,
      order: ORDER,
      raw: true,
    });

    // Recalculate running balance dynamically in correct sort order
    let runningBalance = openingBalance;
    const allWithBalance = allMatchingEntries.map((entry) => {
      runningBalance += parseFloat(entry.debit) - parseFloat(entry.credit);
      return { ...entry, balance: parseFloat(runningBalance.toFixed(2)) };
    });

    // Apply pagination AFTER balance recalculation
    const paginatedEntries = allWithBalance.slice(offset, offset + limitNum);

    // Summary
    const totalDebit  = allMatchingEntries.reduce((s, e) => s + parseFloat(e.debit),  0);
    const totalCredit = allMatchingEntries.reduce((s, e) => s + parseFloat(e.credit), 0);
    const closingBalance = allWithBalance.length > 0
      ? allWithBalance[allWithBalance.length - 1].balance
      : openingBalance;

    res.json({
      success: true,
      data: {
        customer: {
          id: customer.id,
          name: customer.name,
          contact: customer.contact,
          current_balance: parseFloat(customer.balance),
        },
        entries: paginatedEntries,
        summary: {
          total_debit:      parseFloat(totalDebit.toFixed(2)),
          total_credit:     parseFloat(totalCredit.toFixed(2)),
          opening_balance:  parseFloat(openingBalance.toFixed(2)),
          closing_balance:  parseFloat(closingBalance.toFixed(2)),
        },
        pagination: {
          total: allMatchingEntries.length,
          page: pageNum,
          limit: limitNum,
          pages: Math.ceil(allMatchingEntries.length / limitNum),
        },
      },
    });
  } catch (error) {
    console.error('Get customer ledger error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// ─────────────────────────────────────────────
//  GET ALL CUSTOMERS LEDGER SUMMARY
// ─────────────────────────────────────────────
exports.getAllCustomersLedgerSummary = async (req, res) => {
  try {
    const customers = await Customer.findAll({
      attributes: [
        'id',
        'name',
        'contact',
        'customer_type',
        'balance',
        [sequelize.literal(`(
          SELECT SUM(debit) FROM customer_ledgers 
          WHERE customer_ledgers.customer_id = Customer.id
        )`), 'total_purchases'],
        [sequelize.literal(`(
          SELECT SUM(credit) FROM customer_ledgers 
          WHERE customer_ledgers.customer_id = Customer.id
        )`), 'total_payments'],
      ],
      order: [['balance', 'DESC']],
    });

    const totalOutstanding = customers.reduce((sum, c) => sum + parseFloat(c.balance), 0);

    res.json({
      success: true,
      data: {
        customers,
        summary: {
          total_customers: customers.length,
          total_outstanding: totalOutstanding,
        },
      },
    });
  } catch (error) {
    console.error('Get all customers ledger summary error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// ─────────────────────────────────────────────
//  ADD MANUAL LEDGER ADJUSTMENT
// ─────────────────────────────────────────────
exports.addAdjustment = async (req, res) => {
  const t = await sequelize.transaction();
  try {
    const { customerId } = req.params;
    const {
      date,
      description,
      debit = 0,
      credit = 0,
    } = req.body;

    if (!description) {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'Description is required' });
    }

    if (debit <= 0 && credit <= 0) {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'Either debit or credit amount must be greater than 0' });
    }

    const customer = await Customer.findByPk(customerId, { transaction: t });
    if (!customer) {
      await t.rollback();
      return res.status(404).json({ success: false, message: 'Customer not found' });
    }

    // Get last balance
    const lastEntry = await CustomerLedger.findOne({
      where: { customer_id: customerId },
      order: [['date', 'DESC'], ['id', 'DESC']],
      transaction: t,
    });
    const currentBalance = lastEntry ? parseFloat(lastEntry.balance) : 0;
    const newBalance = currentBalance + parseFloat(debit) - parseFloat(credit);

    // Create adjustment entry
    const entry = await CustomerLedger.create({
      customer_id: customerId,
      date: date || new Date(),
      transaction_type: 'adjustment',
      description,
      debit: parseFloat(debit),
      credit: parseFloat(credit),
      balance: newBalance,
    }, { transaction: t });

    // Update customer balance
    await Customer.update(
      { balance: newBalance },
      { where: { id: customerId }, transaction: t }
    );

    await t.commit();

    res.status(201).json({
      success: true,
      message: 'Adjustment added successfully',
      data: entry,
    });
  } catch (error) {
    await t.rollback();
    console.error('Add adjustment error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Add this new function
// customerLedgerController.js — getCustomerPayments
exports.getCustomerPayments = async (req, res) => {
  try {
    const { customerId } = req.params;
    const { page = 1, limit = 20, payment_method } = req.query;  // ← add payment_method

    const pageNum = parseInt(page);
    const limitNum = parseInt(limit);
    const offset = (pageNum - 1) * limitNum;

    const customer = await Customer.findByPk(customerId);
    if (!customer) {
      return res.status(404).json({ success: false, message: 'Customer not found' });
    }

    // Build where clause
    const where = {
      customer_id: customerId,
      transaction_type: 'payment',
    };

    // ← Add this: filter by payment_method if provided
    if (payment_method && payment_method !== 'all') {
      where.payment_method = payment_method;
    }

    const { count, rows: payments } = await CustomerLedger.findAndCountAll({
      where,
      order: [['date', 'DESC'], ['id', 'DESC']],
      limit: limitNum,
      offset,
    });

    res.json({
      success: true,
      data: {
        payments,
        pagination: {
          total: count,
          page: pageNum,
          limit: limitNum,
          pages: Math.ceil(count / limitNum),
        },
      },
    });
  } catch (error) {
    console.error('Get customer payments error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};
// exports.getCustomerPayments = async (req, res) => {
//   try {
//     const { customerId } = req.params;
//     const { page = 1, limit = 20 } = req.query;

//     const pageNum = parseInt(page);
//     const limitNum = parseInt(limit);
//     const offset = (pageNum - 1) * limitNum;

//     // Check if customer exists
//     const customer = await Customer.findByPk(customerId);
//     if (!customer) {
//       return res.status(404).json({ success: false, message: 'Customer not found' });
//     }

//     // Get only payment transactions
//     const { count, rows: payments } = await CustomerLedger.findAndCountAll({
//       where: { 
//         customer_id: customerId,
//         transaction_type: 'payment'
//       },
//       order: [['date', 'DESC'], ['id', 'DESC']],
//       limit: limitNum,
//       offset,
//     });

//     res.json({
//       success: true,
//       data: {
//         payments,
//         pagination: {
//           total: count,
//           page: pageNum,
//           limit: limitNum,
//           pages: Math.ceil(count / limitNum),
//         },
//       },
//     });
//   } catch (error) {
//     console.error('Get customer payments error:', error);
//     res.status(500).json({ success: false, message: 'Server error', error: error.message });
//   }
// };

