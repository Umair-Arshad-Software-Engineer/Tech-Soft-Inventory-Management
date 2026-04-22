const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const SaleReturnItem = sequelize.define('SaleReturnItem', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    return_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'sale_returns',
        key: 'id'
      }
    },
    sale_item_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'sale_items',
        key: 'id'
      }
    },
    product_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'products',
        key: 'id'
      }
    },
    product_name: {
      type: DataTypes.STRING(255),
      allowNull: false
    },
    quantity_returned: {
      type: DataTypes.INTEGER,
      allowNull: false,
      validate: {
        min: { args: [1], msg: 'Quantity must be at least 1' }
      }
    },
    original_unit_price: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false
    },
    refund_unit_price: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false
    },
    total_refund: {
      type: DataTypes.DECIMAL(12, 2),
      allowNull: false
    },
    reason: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    condition: {
      type: DataTypes.ENUM('sellable', 'damaged', 'defective'),
      allowNull: false,
      defaultValue: 'sellable'
    }
  }, {
    tableName: 'sale_return_items',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at',
    indexes: [
      {
        fields: ['return_id']
      },
      {
        fields: ['product_id']
      }
    ]
  });

  return SaleReturnItem;
};