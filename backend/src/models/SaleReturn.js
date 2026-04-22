    const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const SaleReturn = sequelize.define('SaleReturn', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    return_number: {
      type: DataTypes.STRING(50),
      allowNull: false,
      unique: true,
      validate: {
        notEmpty: { msg: 'Return number is required' }
      }
    },
    sale_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'sales',
        key: 'id'
      }
    },
    customer_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'customers',
        key: 'id'
      }
    },
    return_date: {
      type: DataTypes.DATEONLY,
      allowNull: false,
      defaultValue: DataTypes.NOW
    },
    return_type: {
      type: DataTypes.ENUM('full', 'partial'),
      allowNull: false,
      defaultValue: 'partial'
    },
    refund_method: {
      type: DataTypes.ENUM('cash', 'bank_transfer', 'cheque', 'credit_note', 'adjustment'),
      allowNull: false,
      defaultValue: 'cash'
    },
    refund_amount: {
      type: DataTypes.DECIMAL(12, 2),
      allowNull: false,
      defaultValue: 0.00
    },
    adjustment_type: {
      type: DataTypes.ENUM('reduce_balance', 'refund', 'credit_note'),
      allowNull: true
    },
    reason: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    notes: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    status: {
      type: DataTypes.ENUM('pending', 'approved', 'completed', 'rejected'),
      allowNull: false,
      defaultValue: 'completed'
    },
    created_by: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'users',
        key: 'id'
      }
    }
  }, {
    tableName: 'sale_returns',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at',
    indexes: [
      {
        unique: true,
        fields: ['return_number']
      },
      {
        fields: ['sale_id']
      },
      {
        fields: ['customer_id']
      },
      {
        fields: ['return_date']
      },
      {
        fields: ['status']
      }
    ]
  });

  return SaleReturn;
};