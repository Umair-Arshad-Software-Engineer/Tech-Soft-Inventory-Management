// backend/src/models/DamagedStock.js
const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const DamagedStock = sequelize.define('DamagedStock', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    product_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'products',
        key: 'id'
      }
    },
    quantity: {
      type: DataTypes.INTEGER,
      allowNull: false,
      validate: {
        isInt: { msg: 'Quantity must be an integer' },
        min: { args: [1], msg: 'Quantity must be at least 1' }
      }
    },
    reason: {
      type: DataTypes.ENUM(
        'shipping_damage',
        'manufacturing_defect',
        'customer_return',
        'shelf_wear',
        'expiry',
        'theft',
        'accident',
        'other'
      ),
      allowNull: false
    },
    status: {
      type: DataTypes.ENUM('pending', 'approved', 'disposed', 'repaired'),
      defaultValue: 'pending'
    },
    notes: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    approved_by: {
      type: DataTypes.STRING(100),
      allowNull: true
    },
    approved_at: {
      type: DataTypes.DATE,
      allowNull: true
    },
    disposed_by: {
      type: DataTypes.STRING(100),
      allowNull: true
    },
    disposed_at: {
      type: DataTypes.DATE,
      allowNull: true
    },
    repaired_by: {
      type: DataTypes.STRING(100),
      allowNull: true
    },
    repaired_at: {
      type: DataTypes.DATE,
      allowNull: true
    },
    repair_notes: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    estimated_loss: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: true,
      validate: {
        isDecimal: { msg: 'Estimated loss must be a decimal number' },
        min: { args: [0], msg: 'Estimated loss cannot be negative' }
      }
    },
    actual_loss: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: true,
      validate: {
        isDecimal: { msg: 'Actual loss must be a decimal number' },
        min: { args: [0], msg: 'Actual loss cannot be negative' }
      }
    }
  }, {
    tableName: 'damaged_stock',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at',
    indexes: [
      {
        fields: ['product_id']
      },
      {
        fields: ['status']
      },
      {
        fields: ['reason']
      },
      {
        fields: ['created_at']
      }
    ]
  });

  return DamagedStock;
};