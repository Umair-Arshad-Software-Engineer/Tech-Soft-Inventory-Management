require('dotenv').config(); // Add this at the very top
// const User = require('../models/User');
const { User } = require('../models');
const jwt = require('jsonwebtoken');

// Generate JWT Token
const generateToken = (id) => {
  // Add a fallback and console log for debugging
  const secret = process.env.JWT_SECRET;
  
  if (!secret) {
    console.error('JWT_SECRET is not defined in environment variables!');
    throw new Error('JWT_SECRET is not configured');
  }
  
  return jwt.sign({ id }, secret, {
    expiresIn: '30d',
  });
};

// @desc    Register new user
// @route   POST /api/auth/register
// @access  Public
exports.register = async (req, res) => {
  try {
    const { name, email, password } = req.body;

    // Determine role based on who is calling this endpoint.
    // req.user is set by the protect middleware (JWT).
    // If no token is present, req.user will be undefined → reject.
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Not authorized. Only super_admin or admin can register users.'
      });
    }

    const callerRole = req.user.role;

    // Only super_admin and admin can register new users
    if (!['super_admin', 'admin'].includes(callerRole)) {
      return res.status(403).json({
        success: false,
        message: 'Forbidden. Workers cannot register new users.'
      });
    }

    // super_admin creates admins; admin creates workers
    const newRole = callerRole === 'super_admin' ? 'admin' : 'worker';

    // Check if user exists
    const userExists = await User.findOne({ where: { email } });
    if (userExists) {
      return res.status(400).json({
        success: false,
        message: 'User already exists with this email'
      });
    }

    const user = await User.create({ name, email, password, role: newRole });
    const token = generateToken(user.id);

    res.status(201).json({
      success: true,
      message: `${newRole.charAt(0).toUpperCase() + newRole.slice(1)} registered successfully`,
      data: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        token
      }
    });

  } catch (error) {
    console.error('Register Error:', error);
    if (error.name === 'SequelizeValidationError') {
      return res.status(400).json({
        success: false,
        message: error.errors.map(e => e.message)[0]
      });
    }
    res.status(500).json({ success: false, message: 'Server error. Please try again.' });
  }
};

// @desc    Login user
// @route   POST /api/auth/login
// @access  Public
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate input
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please provide email and password'
      });
    }

    // Find user
    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password'
      });
    }

    // Check password
    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password'
      });
    }

    // Generate token
    const token = generateToken(user.id);

    res.status(200).json({
      success: true,
      message: 'Login successful',
      data: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,   // ← add
        token
      }
    });

  } catch (error) {
    console.error('Login Error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error. Please try again.'
    });
  }
};

// @desc    Get current user
// @route   GET /api/auth/me
// @access  Private
exports.getMe = async (req, res) => {
  try {
    const user = await User.findByPk(req.user.id, {
      attributes: { exclude: ['password'] }
    });

    res.status(200).json({
      success: true,
      data: user
    });

  } catch (error) {
    console.error('GetMe Error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};


exports.getUsers = async (req, res) => {
  try {
    const callerRole = req.user.role;
 
    if (callerRole === 'worker') {
      return res.status(403).json({
        success: false,
        message: 'Forbidden. Workers cannot access user management.',
      });
    }
 
    let whereClause = {};
 
    if (callerRole === 'admin') {
      // Admin can only see workers
      whereClause = { role: 'worker' };
    } else if (callerRole === 'super_admin') {
      // super_admin sees admins and workers (not other super_admins)
      whereClause = {
        role: ['admin', 'worker'],
      };
    }
 
    const users = await User.findAll({
      where: whereClause,
      attributes: { exclude: ['password'] },
      order: [['createdAt', 'DESC']],
    });
 
    res.status(200).json({
      success: true,
      data: users,
    });
  } catch (error) {
    console.error('getUsers Error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
};
 

exports.toggleUserStatus = async (req, res) => {
  try {
    const callerRole = req.user.role;
    const callerId = req.user.id;
    const { id } = req.params;
    const { isActive } = req.body;
 
    if (callerRole === 'worker') {
      return res.status(403).json({
        success: false,
        message: 'Forbidden. Workers cannot change user status.',
      });
    }
 
    if (typeof isActive !== 'boolean') {
      return res.status(400).json({
        success: false,
        message: '`isActive` must be a boolean.',
      });
    }
 
    // Prevent self-deactivation
    if (parseInt(id) === callerId) {
      return res.status(400).json({
        success: false,
        message: 'You cannot change your own status.',
      });
    }
 
    const targetUser = await User.findByPk(id, {
      attributes: { exclude: ['password'] },
    });
 
    if (!targetUser) {
      return res.status(404).json({
        success: false,
        message: 'User not found.',
      });
    }
 
    // Permission check
    if (callerRole === 'admin' && targetUser.role !== 'worker') {
      return res.status(403).json({
        success: false,
        message: 'Admins can only change the status of workers.',
      });
    }
 
    if (
      callerRole === 'super_admin' &&
      targetUser.role === 'super_admin'
    ) {
      return res.status(403).json({
        success: false,
        message: 'Cannot change the status of another super admin.',
      });
    }
 
    await targetUser.update({ isActive });
 
    res.status(200).json({
      success: true,
      message: `User ${isActive ? 'activated' : 'deactivated'} successfully.`,
      data: {
        id: targetUser.id,
        name: targetUser.name,
        email: targetUser.email,
        role: targetUser.role,
        isActive: targetUser.isActive,
      },
    });
  } catch (error) {
    console.error('toggleUserStatus Error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
};