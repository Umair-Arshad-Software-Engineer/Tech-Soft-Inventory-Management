const express = require('express');
const router = express.Router();
const saleReturnController = require('../controllers/saleReturnController');

router.post('/', saleReturnController.createSaleReturn);
router.get('/', saleReturnController.getAllReturns);
router.get('/sale/:sale_id', saleReturnController.getSaleReturns);
router.get('/:id', saleReturnController.getReturnById);

module.exports = router;