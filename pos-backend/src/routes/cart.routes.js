const express = require('express');
const router = express.Router();
const cartController = require('../controllers/cart.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const verifyToken = typeof authMiddleware === 'function'
  ? authMiddleware
  : authMiddleware.verifyToken;

// Đặt 1 dòng này ở đầu -> toàn bộ API giỏ hàng bên dưới bắt buộc phải có JWT Token
router.use(verifyToken);

router.get('/', cartController.getCart);
router.post('/items', cartController.addToCart);
router.patch('/select-all', cartController.toggleSelectAll);
router.patch('/items/:productId', cartController.updateCartItem);
router.delete('/items/:productId', cartController.removeCartItem);

module.exports = router;