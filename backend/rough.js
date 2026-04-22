
// const fs = require('fs');
// const path = require('path');
// const express = require('express');
// const cors = require('cors');
// const bodyParser = require('body-parser');

// // Load .env from same folder as exe
// require('dotenv').config({ path: path.join(process.cwd(), '.env') });

// // Force pkg to include mysql2
// require('mysql2');

// // Import sequelize instance
// const sequelize = require('./src/config/db');

// // Import models
// const User = require('./src/models/User'); // ← Import User model directly

// // Import routes
// const authRoutes = require('./src/routes/authRoutes');
// const categoryRoutes = require('./src/routes/categoryRoutes');
// const subcategoryRoutes = require('./src/routes/subcategoryRoutes');
// const unitRoutes = require('./src/routes/unitRoutes');
// const supplierRoutes = require('./src/routes/supplierRoutes');
// const customerRoutes = require('./src/routes/customerRoutes');
// const productRoutes = require('./src/routes/productRoutes');
// const damagedStockRoutes = require('./src/routes/damagedStockRoutes');  // ADD THIS
// const customerPriceRoutes = require('./src/routes/customerPriceRoutes');
// const productImageRoutes = require('./src/routes/productImageRoutes');
// const purchaseOrderRoutes = require('./src/routes/purchaseOrderRoutes');
// const saleRoutes = require('./src/routes/saleRoutes');
// const customerLedgerRoutes = require('./src/routes/customerLedgerRoutes');

// const app = express();
// const PORT = process.env.PORT || 3000;

// // ─── Admin Seed Config ────────────────────────────────────────────────────────
// const ADMIN_USER = {
//   name: 'Tech Soft',
//   email: 'techsoft@gmail.com',
//   password: '1129@AliHaider',
// };
// // ─────────────────────────────────────────────────────────────────────────────

// // Crash protection (keep console open)
// process.on('uncaughtException', err => {
//   console.error('UNCAUGHT EXCEPTION:', err);
// });
// process.on('unhandledRejection', err => {
//   console.error('UNHANDLED REJECTION:', err);
// });

// // Middleware
// app.use(cors({
//   origin: ['http://localhost:3000', 'http://localhost:3001', 'http://localhost:8081'],
//   credentials: true
// }));
// app.use(bodyParser.json());
// app.use(bodyParser.urlencoded({ extended: true }));

// // Routes
// app.use('/api/auth', authRoutes);
// app.use('/api/categories', categoryRoutes);
// app.use('/api/subcategories', subcategoryRoutes);
// app.use('/api/units', unitRoutes);
// app.use('/api/suppliers', supplierRoutes);
// app.use('/api/customers', customerRoutes);
// app.use('/api/products', productRoutes);
// app.use('/api/customer-prices', customerPriceRoutes);
// app.use('/api', productImageRoutes);
// app.use('/api/purchase-orders', purchaseOrderRoutes);
// app.use('/api/sales', saleRoutes);
// app.use('/api/customer-ledger', customerLedgerRoutes);

// // Ensure uploads folder exists
// const uploadsPath = path.join(process.cwd(), 'uploads');
// if (!fs.existsSync(uploadsPath)) {
//   fs.mkdirSync(uploadsPath, { recursive: true });
//   console.log('📂 Created uploads folder');
// }
// app.use('/uploads', express.static(uploadsPath));

// // Health check
// app.get('/', (req, res) => {
//   res.json({ message: 'API running', timestamp: new Date().toISOString() });
// });

// // ─── Seed Admin User ──────────────────────────────────────────────────────────
// async function seedAdminUser() {
//   try {
//     const existing = await User.findOne({ where: { email: ADMIN_USER.email } });

//     if (existing) {
//       console.log('ℹ️  Admin user already exists — skipping seed.');
//       return;
//     }

//     // Use User.create() so the beforeCreate bcrypt hook runs automatically
//     await User.create({
//       name: ADMIN_USER.name,
//       email: ADMIN_USER.email,
//       password: ADMIN_USER.password,
//       role: 'super_admin',   // ← add this
//     });

//     // console.log('✅ Admin user created:');
//     // console.log(`   Name  : ${ADMIN_USER.name}`);
//     // console.log(`   Email : ${ADMIN_USER.email}`);
//   } catch (err) {
//      console.error('❌ Failed to seed admin user:', err.message);
//   }
// }
// // ─────────────────────────────────────────────────────────────────────────────

// // Database sync and server start
// (async () => {
//   try {
//     await sequelize.authenticate();
//     console.log('✅ Database connected');

//     await sequelize.sync({ alter: true });
//     console.log('✅ Database & tables synced');

//     // Seed admin after tables are ready
//     await seedAdminUser();

//     app.listen(PORT, () => {
//       console.log(`🚀 Server running on port ${PORT}`);
//       console.log('Press CTRL+C to exit.');
//     });
//   } catch (err) {
//     console.error('❌ Database error:', err);
//     console.log('Press any key to exit...');
//     process.stdin.setRawMode(true);
//     process.stdin.resume();
//     process.stdin.on('data', process.exit.bind(process, 1));
//   }
// })();
// server.js

