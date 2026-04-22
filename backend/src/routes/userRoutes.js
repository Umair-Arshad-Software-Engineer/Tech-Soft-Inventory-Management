const express = require('express');
const router = express.Router();
const { getUsers, toggleUserStatus } = require('../controllers/authController'); // ← fix this
const { protect } = require('../middleware/authMiddleware');
 
// All routes require a valid JWT
router.use(protect);
 
router.get('/', getUsers);                        // GET  /api/users
router.patch('/:id/status', toggleUserStatus);    // PATCH /api/users/:id/status
 
module.exports = router;