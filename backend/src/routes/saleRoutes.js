
// module.exports = router;    
const express = require('express');
const router = express.Router();
const saleController = require('../controllers/saleController');

// ── SPECIFIC ROUTES FIRST (BEFORE parameterized routes) ──
router.get('/returns', saleController.getAllReturns);  // ← Add this line
router.get('/', saleController.getAllSales);
router.post('/', saleController.createSale);
router.get('/summary/daily', saleController.getDailySummary);
router.get('/credit/summary', saleController.getCreditSalesSummary);

// ── Routes with parameters AFTER specific routes ──
router.get('/:id/returns', saleController.getSaleReturns);
router.get('/:id', saleController.getSaleById);
router.put('/:id', saleController.updateSale);
router.delete('/:id', saleController.deleteSale);
router.post('/:id/payment', saleController.recordPayment);

module.exports = router;