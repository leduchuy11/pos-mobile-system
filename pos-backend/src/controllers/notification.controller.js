const pool = require('../config/db');
const notificationService = require('../services/notification.service');

// 1. POST /api/notifications/token -> Lưu hoặc cập nhật chủ sở hữu FCM Token khi đăng nhập / mở app
exports.registerDeviceToken = async (req, res) => {
  try {
    const userId = req.user.id;
    const fcmToken = String(req.body.fcm_token || '').trim();
    const rawPlatform = String(req.body.platform || 'android').toLowerCase();
    const platform = ['android', 'ios', 'web'].includes(rawPlatform)
      ? rawPlatform
      : 'android';

    if (!fcmToken) {
      return res.status(400).json({
        success: false,
        message: 'Thiếu fcm_token',
      });
    }

    // Nếu thiết bị đổi sang tài khoản khác, tự chuyển quyền sở hữu token sang user mới
    await pool.query(
      `INSERT INTO user_devices (user_id, fcm_token, platform)
       VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE
         user_id = VALUES(user_id),
         platform = VALUES(platform),
         updated_at = CURRENT_TIMESTAMP`,
      [userId, fcmToken, platform]
    );

    return res.status(200).json({
      success: true,
      message: 'Đã lưu FCM token thiết bị',
    });
  } catch (err) {
    console.error('Lỗi registerDeviceToken:', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi lưu FCM token',
    });
  }
};

// 2. DELETE /api/notifications/token -> Gỡ FCM Token khi bấm Đăng xuất
exports.removeDeviceToken = async (req, res) => {
  try {
    const userId = req.user.id;
    const fcmToken = String(
      (req.body && req.body.fcm_token) || req.query.fcm_token || ''
    ).trim();

    if (!fcmToken) {
      return res.status(400).json({
        success: false,
        message: 'Thiếu fcm_token để xóa',
      });
    }

    await pool.query(
      'DELETE FROM user_devices WHERE user_id = ? AND fcm_token = ?',
      [userId, fcmToken]
    );

    return res.status(200).json({
      success: true,
      message: 'Đã gỡ FCM token khỏi thiết bị',
    });
  } catch (err) {
    console.error('Lỗi removeDeviceToken:', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi gỡ FCM token',
    });
  }
};

// 3. GET /api/notifications -> Lấy danh sách lịch sử thông báo + số chưa đọc
exports.getNotifications = async (req, res) => {
  try {
    const userId = req.user.id;

    const [items] = await pool.query(
      `SELECT id, order_id, title, body, is_read, created_at
       FROM notifications
       WHERE user_id = ?
       ORDER BY created_at DESC
       LIMIT 50`,
      [userId]
    );

    const [[{ unreadCount }]] = await pool.query(
      'SELECT COUNT(*) AS unreadCount FROM notifications WHERE user_id = ? AND is_read = 0',
      [userId]
    );

    return res.status(200).json({
      success: true,
      data: {
        unreadCount: Number(unreadCount) || 0,
        items: items.map((row) => ({
          ...row,
          is_read: Boolean(row.is_read),
        })),
      },
    });
  } catch (err) {
    console.error('Lỗi getNotifications:', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi tải thông báo',
    });
  }
};

// 4. PATCH /api/notifications/:id/read -> Đánh dấu 1 thông báo đã đọc
exports.markAsRead = async (req, res) => {
  try {
    const notificationId = parseInt(req.params.id, 10);
    if (Number.isNaN(notificationId) || notificationId <= 0) {
      return res.status(400).json({
        success: false,
        message: 'ID thông báo không hợp lệ',
      });
    }

    await pool.query(
      'UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?',
      [notificationId, req.user.id]
    );

    return res.status(200).json({
      success: true,
      message: 'Đã đánh dấu đã đọc',
    });
  } catch (err) {
    console.error('Lỗi markAsRead:', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi cập nhật thông báo',
    });
  }
};

// 5. PATCH /api/notifications/read-all -> Đánh dấu tất cả đã đọc
exports.markAllAsRead = async (req, res) => {
  try {
    await pool.query(
      'UPDATE notifications SET is_read = 1 WHERE user_id = ? AND is_read = 0',
      [req.user.id]
    );

    return res.status(200).json({
      success: true,
      message: 'Đã đánh dấu đọc tất cả thông báo',
    });
  } catch (err) {
    console.error('Lỗi markAllAsRead:', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi cập nhật thông báo',
    });
  }
};

// 6. POST /api/notifications/test -> API bắn thử thông báo từ server (dùng để test khi tắt hẳn app)
exports.sendTestNotification = async (req, res) => {
  try {
    const title = String(req.body.title || 'Thông báo thử nghiệm').trim();
    const body = String(
      req.body.body || 'Server Node.js đã bắn Push Notification thành công!'
    ).trim();

    const result = await notificationService.sendNotificationToUser({
      userId: req.user.id,
      title,
      body,
    });

    return res.status(200).json({
      success: true,
      message: 'Đã xử lý gửi thông báo thử nghiệm',
      data: result,
    });
  } catch (err) {
    console.error('Lỗi sendTestNotification:', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi gửi thông báo thử nghiệm',
    });
  }
};