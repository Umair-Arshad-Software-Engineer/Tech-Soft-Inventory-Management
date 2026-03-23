// // // server.js
// // // require('dotenv').config();
// // const fs = require('fs');
// // const path = require('path');
// // const express = require('express');
// // const cors = require('cors');
// // const bodyParser = require('body-parser');
// // require('dotenv').config({
// //   path: path.join(process.cwd(), '.env')
// // });
// // // Force pkg to include mysql2 (needed for Sequelize)
// // require('mysql2');

// // // Import models
// // const { sequelize, User } = require('./src/models');

// // // Import routes
// // const authRoutes = require('./src/routes/authRoutes');
// // const categoryRoutes = require('./src/routes/categoryRoutes');
// // const subcategoryRoutes = require('./src/routes/subcategoryRoutes');
// // const unitRoutes = require('./src/routes/unitRoutes');
// // const supplierRoutes = require('./src/routes/supplierRoutes');
// // const customerRoutes = require('./src/routes/customerRoutes');
// // const productRoutes = require('./src/routes/productRoutes');
// // const customerPriceRoutes = require('./src/routes/customerPriceRoutes');
// // const productImageRoutes = require('./src/routes/productImageRoutes');
// // const purchaseOrderRoutes = require('./src/routes/purchaseOrderRoutes');
// // const saleRoutes = require('./src/routes/saleRoutes');
// // const customerLedgerRoutes = require('./src/routes/customerLedgerRoutes');

// // const app = express();
// // const PORT = process.env.PORT || 3000;

// // // Debug: Check if env vars are loaded
// // console.log('Environment Variables Loaded:');
// // console.log('- PORT:', process.env.PORT);
// // console.log('- DB_NAME:', process.env.DB_NAME);
// // console.log('- JWT_SECRET:', process.env.JWT_SECRET ? '✓ Loaded' : '✗ Missing');

// // // Middleware
// // app.use(cors({
// //   origin: ['http://localhost:3000', 'http://localhost:3001', 'http://localhost:8081'],
// //   credentials: true
// // }));
// // app.use(bodyParser.json());
// // app.use(bodyParser.urlencoded({ extended: true }));

// // // Routes
// // app.use('/api/auth', authRoutes);
// // app.use('/api/categories', categoryRoutes);
// // app.use('/api/subcategories', subcategoryRoutes);
// // app.use('/api/units', unitRoutes);
// // app.use('/api/suppliers', supplierRoutes);
// // app.use('/api/customers', customerRoutes);
// // app.use('/api/products', productRoutes);
// // app.use('/api/customer-prices', customerPriceRoutes);
// // app.use('/api', productImageRoutes);
// // app.use('/api/purchase-orders', purchaseOrderRoutes);
// // app.use('/api/sales', saleRoutes);
// // app.use('/api/customer-ledger', customerLedgerRoutes);

// // // Ensure uploads folder exists
// // const uploadsPath = path.join(process.cwd(), 'uploads');
// // if (!fs.existsSync(uploadsPath)) {
// //   fs.mkdirSync(uploadsPath, { recursive: true });
// //   console.log('📂 Created uploads folder');
// // }
// // app.use('/uploads', express.static(uploadsPath));

// // // Example helper to save uploaded files (replace your multer logic if needed)
// // // function saveFile(filename, buffer) {
// // //   const filePath = path.join(uploadsPath, filename);
// // //   fs.writeFileSync(filePath, buffer);
// // // }

// // // Health check
// // app.get('/', (req, res) => {
// //   res.json({
// //     message: 'API is running...',
// //     timestamp: new Date().toISOString(),
// //     endpoints: {
// //       auth: {
// //         register: 'POST /api/auth/register',
// //         login: 'POST /api/auth/login',
// //         me: 'GET /api/auth/me (requires token)'
// //       }
// //     }
// //   });
// // });

// // // Database sync and server start
// // sequelize.sync({ alter: true })
// //   .then(() => {
// //     console.log('✅ Database & tables synced');

// //     app.listen(PORT, () => {
// //       console.log(`🚀 Server running on port ${PORT}`);
// //       console.log(`📝 API Documentation: http://localhost:${PORT}`);
// //       console.log(`🌐 CORS enabled for local development`);
// //     });
// //   })
// //   .catch(err => {
// //     console.error('❌ Database sync error:', err);
// //     process.exit(1);
// //   });

// // // Error handling middleware
// // app.use((err, req, res, next) => {
// //   console.error('Unhandled error:', err);
// //   res.status(500).json({
// //     success: false,
// //     message: 'Internal server error',
// //     error: process.env.NODE_ENV === 'development' ? err.message : undefined
// //   });
// // });


// // server.js
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
// const sequelize = require('./src/config/db'); // db.js exports sequelize

// // Import routes
// const authRoutes = require('./src/routes/authRoutes');
// const categoryRoutes = require('./src/routes/categoryRoutes');
// const subcategoryRoutes = require('./src/routes/subcategoryRoutes');
// const unitRoutes = require('./src/routes/unitRoutes');
// const supplierRoutes = require('./src/routes/supplierRoutes');
// const customerRoutes = require('./src/routes/customerRoutes');
// const productRoutes = require('./src/routes/productRoutes');
// const customerPriceRoutes = require('./src/routes/customerPriceRoutes');
// const productImageRoutes = require('./src/routes/productImageRoutes');
// const purchaseOrderRoutes = require('./src/routes/purchaseOrderRoutes');
// const saleRoutes = require('./src/routes/saleRoutes');
// const customerLedgerRoutes = require('./src/routes/customerLedgerRoutes');

// const app = express();
// const PORT = process.env.PORT || 3000;

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

// // Database sync and server start
// (async () => {
//   try {
//     await sequelize.authenticate();
//     console.log('✅ Database connected');

//     await sequelize.sync({ alter: true });
//     console.log('✅ Database & tables synced');

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
const fs = require('fs');
const path = require('path');
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');

// Load .env from same folder as exe
require('dotenv').config({ path: path.join(process.cwd(), '.env') });

// Force pkg to include mysql2
require('mysql2');

// Import sequelize instance
const sequelize = require('./src/config/db');

// Import models
const User = require('./src/models/User'); // ← Import User model directly

// Import routes
const authRoutes = require('./src/routes/authRoutes');
const categoryRoutes = require('./src/routes/categoryRoutes');
const subcategoryRoutes = require('./src/routes/subcategoryRoutes');
const unitRoutes = require('./src/routes/unitRoutes');
const supplierRoutes = require('./src/routes/supplierRoutes');
const customerRoutes = require('./src/routes/customerRoutes');
const productRoutes = require('./src/routes/productRoutes');
const customerPriceRoutes = require('./src/routes/customerPriceRoutes');
const productImageRoutes = require('./src/routes/productImageRoutes');
const purchaseOrderRoutes = require('./src/routes/purchaseOrderRoutes');
const saleRoutes = require('./src/routes/saleRoutes');
const customerLedgerRoutes = require('./src/routes/customerLedgerRoutes');

const app = express();
const PORT = process.env.PORT || 3000;

// ─── Admin Seed Config ────────────────────────────────────────────────────────
const ADMIN_USER = {
  name: 'Tech Soft',
  email: 'techsoft@gmail.com',
  password: '1129@AliHaider',
};
// ─────────────────────────────────────────────────────────────────────────────

// Crash protection (keep console open)
process.on('uncaughtException', err => {
  console.error('UNCAUGHT EXCEPTION:', err);
});
process.on('unhandledRejection', err => {
  console.error('UNHANDLED REJECTION:', err);
});

// Middleware
app.use(cors({
  origin: ['http://localhost:3000', 'http://localhost:3001', 'http://localhost:8081'],
  credentials: true
}));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/subcategories', subcategoryRoutes);
app.use('/api/units', unitRoutes);
app.use('/api/suppliers', supplierRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/products', productRoutes);
app.use('/api/customer-prices', customerPriceRoutes);
app.use('/api', productImageRoutes);
app.use('/api/purchase-orders', purchaseOrderRoutes);
app.use('/api/sales', saleRoutes);
app.use('/api/customer-ledger', customerLedgerRoutes);

// Ensure uploads folder exists
const uploadsPath = path.join(process.cwd(), 'uploads');
if (!fs.existsSync(uploadsPath)) {
  fs.mkdirSync(uploadsPath, { recursive: true });
  console.log('📂 Created uploads folder');
}
app.use('/uploads', express.static(uploadsPath));

// Health check
app.get('/', (req, res) => {
  res.json({ message: 'API running', timestamp: new Date().toISOString() });
});

// ─── Seed Admin User ──────────────────────────────────────────────────────────
async function seedAdminUser() {
  try {
    const existing = await User.findOne({ where: { email: ADMIN_USER.email } });

    if (existing) {
      console.log('ℹ️  Admin user already exists — skipping seed.');
      return;
    }

    // Use User.create() so the beforeCreate bcrypt hook runs automatically
    await User.create({
      name: ADMIN_USER.name,
      email: ADMIN_USER.email,
      password: ADMIN_USER.password,
    });

    // console.log('✅ Admin user created:');
    // console.log(`   Name  : ${ADMIN_USER.name}`);
    // console.log(`   Email : ${ADMIN_USER.email}`);
  } catch (err) {
     console.error('❌ Failed to seed admin user:', err.message);
  }
}
// ─────────────────────────────────────────────────────────────────────────────

// Database sync and server start
(async () => {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connected');

    await sequelize.sync({ alter: true });
    console.log('✅ Database & tables synced');

    // Seed admin after tables are ready
    await seedAdminUser();

    app.listen(PORT, () => {
      console.log(`🚀 Server running on port ${PORT}`);
      console.log('Press CTRL+C to exit.');
    });
  } catch (err) {
    console.error('❌ Database error:', err);
    console.log('Press any key to exit...');
    process.stdin.setRawMode(true);
    process.stdin.resume();
    process.stdin.on('data', process.exit.bind(process, 1));
  }
})();