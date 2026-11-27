const express = require('express');
const router = express.Router();
const orderController = require('../controllers/order.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const verifyToken = typeof authMiddleware === 'function'
  ? authMiddleware
  : authMiddleware.verifyToken;

router.use(verifyToken);

router.post('/', orderController.createOrder);
router.get('/', orderController.getOrders);
router.get('/:id', orderController.getOrderDetail);

module.exports = router;