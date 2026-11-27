const express = require('express');
const router = express.Router();
const productController = require('../controllers/product.controller');

router.get('/', productController.getProductsByPage);
router.get('/:id/stock', productController.getProductStock);
router.get('/:id/media', productController.getProductMedia);

module.exports = router;