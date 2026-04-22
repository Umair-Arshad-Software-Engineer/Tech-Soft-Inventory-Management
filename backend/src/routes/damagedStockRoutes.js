// backend/src/routes/damagedStockRoutes.js
const express = require('express');
const router = express.Router();
const damagedStockController = require('../controllers/damagedStockController');

// Damaged stock routes
router.get('/', damagedStockController.getAllDamagedStock);
router.get('/statistics', damagedStockController.getDamagedStockStatistics);
router.get('/:id', damagedStockController.getDamagedStockById);
router.post('/', damagedStockController.createDamagedStock);
router.put('/:id/status', damagedStockController.updateDamagedStatus);
router.delete('/:id', damagedStockController.deleteDamagedStock);

module.exports = router;