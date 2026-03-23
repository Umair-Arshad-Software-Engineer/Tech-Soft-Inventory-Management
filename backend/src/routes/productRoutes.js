// backend/src/routes/productRoutes.js
const express = require('express');
const router = express.Router();
const productController = require('../controllers/productController');



// Product routes - all publicly accessible now
router.get('/', productController.getAllProducts);
router.get('/low-stock', productController.getLowStockProducts);
router.get('/supplier/:supplierId', productController.getProductsBySupplier);
router.get('/barcode/:barcode', productController.getProductByBarcode);
router.get('/:id', productController.getProductById);
router.post('/', productController.createProduct);
router.put('/:id', productController.updateProduct);
router.delete('/:id', productController.deleteProduct);
router.patch('/:id/toggle-status', productController.toggleProductStatus);
router.patch('/:id/quantity', productController.updateProductQuantity);
router.get('/:id/history', productController.getProductHistory);


module.exports = router;