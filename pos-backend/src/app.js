const express = require('express');
const cors = require('cors');
require('dotenv').config();

const pool = require('./config/db');
const authRoutes = require('./routes/auth.routes'); 
const productRoutes = require('./routes/product.routes');
const cartRoutes = require('./routes/cart.routes');
const orderRoutes = require('./routes/order.routes');
const notificationRoutes = require('./routes/notification.routes');

const app = express();
app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
  res.json({ success: true, message: 'Server Backend dang chay!' });
});

app.use('/api/auth', authRoutes); 
app.use('/api/products', productRoutes);
app.use('/api/cart', cartRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/notifications', notificationRoutes);

const PORT = process.env.PORT || 3000;

pool.getConnection()
  .then((conn) => {
    console.log('✅ Ket noi MySQL thanh cong!');
    conn.release();
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Server dang chay tai http://localhost:${PORT}`);
    });
  })
  .catch((err) => {
    console.error('❌ Loi ket noi MySQL:', err.message);
  });