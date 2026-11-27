const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notification.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const verifyToken =
  typeof authMiddleware === 'function'
    ? authMiddleware
    : authMiddleware.verifyToken;

router.use(verifyToken);

router.post('/token', notificationController.registerDeviceToken);
router.delete('/token', notificationController.removeDeviceToken);
router.get('/', notificationController.getNotifications);
router.patch('/read-all', notificationController.markAllAsRead);
router.patch('/:id/read', notificationController.markAsRead);
router.post('/test', notificationController.sendTestNotification);

module.exports = router;