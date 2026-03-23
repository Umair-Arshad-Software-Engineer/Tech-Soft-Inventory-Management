const express = require('express');
const router = express.Router();
const customerController = require('../controllers/customerController');
const customerLedgerController = require('../controllers/customerLedgerController'); // Add this import


// Customer CRUD routes (without authentication)
router.get('/', customerController.getAllCustomers);
router.get('/active', customerController.getActiveCustomers);
router.get('/balances', customerLedgerController.getAllCustomersLedgerSummary); // ADD THIS LINE
router.get('/:id', customerController.getCustomerById);
router.post('/', customerController.createCustomer);
router.put('/:id', customerController.updateCustomer);
router.delete('/:id', customerController.deleteCustomer);
router.patch('/:id/toggle-status', customerController.toggleCustomerStatus);
router.patch('/:id/update-balance', customerController.updateCustomerBalance);

module.exports = router;