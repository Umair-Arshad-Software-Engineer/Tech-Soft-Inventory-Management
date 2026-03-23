// backend/src/models/CustomerLedger.js
const { DataTypes } = require('sequelize');
const { Op } = require('sequelize');

module.exports = (sequelize) => {
  const CustomerLedger = sequelize.define('CustomerLedger', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    customer_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'customers',
        key: 'id'
      }
    },
    date: {
      type: DataTypes.DATEONLY,
      allowNull: false,
      defaultValue: DataTypes.NOW
    },
    transaction_type: {
      type: DataTypes.ENUM('sale', 'payment', 'opening_balance', 'adjustment'),
      allowNull: false
    },
    reference_id: {
      type: DataTypes.INTEGER,
      allowNull: true,
      comment: 'ID of the related transaction (sale_id, payment_id, etc.)'
    },
    reference_number: {
      type: DataTypes.STRING(50),
      allowNull: true,
      comment: 'Invoice number or payment reference'
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    debit: {
      type: DataTypes.DECIMAL(12, 2),
      allowNull: false,
      defaultValue: 0.00,
      validate: {
        isDecimal: { msg: 'Debit must be a decimal number' },
        min: { args: [0], msg: 'Debit cannot be negative' }
      },
      comment: 'Amount customer owes (increases balance)'
    },
    credit: {
      type: DataTypes.DECIMAL(12, 2),
      allowNull: false,
      defaultValue: 0.00,
      validate: {
        isDecimal: { msg: 'Credit must be a decimal number' },
        min: { args: [0], msg: 'Credit cannot be negative' }
      },
      comment: 'Amount paid by customer (decreases balance)'
    },
    balance: {
      type: DataTypes.DECIMAL(12, 2),
      allowNull: false,
      defaultValue: 0.00,
      validate: {
        isDecimal: { msg: 'Balance must be a decimal number' }
      },
      comment: 'Running balance after this transaction'
    }
  }, {
    tableName: 'customer_ledgers',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at',
    indexes: [
      {
        fields: ['customer_id']
      },
      {
        fields: ['date']
      },
      {
        fields: ['reference_id', 'transaction_type']
      }
    ]
  });

  return CustomerLedger;
};