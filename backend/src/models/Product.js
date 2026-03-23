// models/Product.js
const { DataTypes } = require('sequelize');
const { Op } = require('sequelize'); // Add this import

module.exports = (sequelize) => {
  const Product = sequelize.define('Product', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    item_name: {
      type: DataTypes.STRING(100),
      allowNull: false,
      validate: {
        notEmpty: { msg: 'Item name is required' }
      }
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    cost_price: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
      defaultValue: 0.00,
      validate: {
        isDecimal: { msg: 'Cost price must be a decimal number' },
        min: { args: [0], msg: 'Cost price cannot be negative' }
      }
    },
    sale_price: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
      defaultValue: 0.00,
      validate: {
        isDecimal: { msg: 'Sale price must be a decimal number' },
        min: { args: [0], msg: 'Sale price cannot be negative' }
      }
    },
    supplier_id: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'suppliers',
        key: 'id'
      }
    },
    category_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'categories',
        key: 'id'
      }
    },
    subcategory_id: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'subcategories',
        key: 'id'
      }
    },
    unit_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'units',
        key: 'id'
      }
    },
    barcode: {
      type: DataTypes.STRING(50),
      allowNull: true,
      unique: {
        msg: 'Barcode must be unique'
      }
    },
    min_stock: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      validate: {
        isInt: { msg: 'Minimum stock must be an integer' },
        min: { args: [0], msg: 'Minimum stock cannot be negative' }
      }
    },
    physical_qty: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      validate: {
        isInt: { msg: 'Physical quantity must be an integer' },
        min: { args: [0], msg: 'Physical quantity cannot be negative' }
      }
    },
    available_qty: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      validate: {
        isInt: { msg: 'Available quantity must be an integer' },
        min: { args: [0], msg: 'Available quantity cannot be negative' }
      }
    },
    is_active: {
      type: DataTypes.BOOLEAN,
      defaultValue: true
    }
  }, {
    tableName: 'products',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at',
    indexes: [
      {
        unique: true,
        fields: ['barcode'],
        where: {
          barcode: { [Op.ne]: null } // Now Op is defined
        }
      },
      {
        fields: ['item_name']
      },
      {
        fields: ['supplier_id']
      },
      {
        fields: ['category_id']
      },
      {
        fields: ['subcategory_id']
      },
      {
        fields: ['is_active']
      }
    ]
  });

  return Product;
};