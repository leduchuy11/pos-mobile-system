const pool = require('../config/db');
const { getMessaging, isFirebaseReady } = require('../config/firebase');

function formatVnd(amount) {
  const rounded = Math.round(Number(amount) || 0);
  return `${rounded.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.')} đ`;
}

/**
 * Lưu lịch sử thông báo vào MySQL và bắn Push Notification tới mọi thiết bị (Android & iOS) của user
 */
async function sendNotificationToUser({ userId, orderId = null, title, body }) {
  // 1. Luôn lưu lịch sử vào bảng notifications trước
  const [insertResult] = await pool.query(
    `INSERT INTO notifications (user_id, order_id, title, body)
     VALUES (?, ?, ?, ?)`,
    [userId, orderId, title, body]
  );
  const notificationId = insertResult.insertId;

  // 2. Lấy toàn bộ FCM Token đang đăng nhập của user này
  const [deviceRows] = await pool.query(
    'SELECT fcm_token FROM user_devices WHERE user_id = ?',
    [userId]
  );

  const tokens = deviceRows.map((row) => row.fcm_token).filter(Boolean);

  if (!isFirebaseReady || tokens.length === 0) {
    return {
      notificationId,
      sentCount: 0,
      failedCount: 0,
      skipped: true,
    };
  }

  // Đếm số thông báo chưa đọc để gắn badge số đỏ trên icon app iOS
  const [[{ unreadCount }]] = await pool.query(
    'SELECT COUNT(*) AS unreadCount FROM notifications WHERE user_id = ? AND is_read = 0',
    [userId]
  );

  // 3. Đóng gói payload chuẩn cho cả Android và iOS
  // Lưu ý: mọi giá trị trong `data` bắt buộc phải là kiểu chuỗi (String)
  const message = {
    tokens,
    notification: {
      title,
      body,
    },
    data: {
      type: orderId ? 'ORDER_PAID' : 'SYSTEM',
      notification_id: String(notificationId),
      order_id: orderId ? String(orderId) : '',
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'order_notifications',
        sound: 'default',
      },
    },
    apns: {
      headers: {
        'apns-priority': '10',
      },
      payload: {
        aps: {
          sound: 'default',
          badge: Number(unreadCount) || 1,
        },
      },
    },
  };

  const response = await getMessaging().sendEachForMulticast(message);

  // 4. Tự động dọn dẹp token đã hết hạn hoặc máy đã gỡ app
  const invalidTokens = [];
  response.responses.forEach((resp, idx) => {
    if (!resp.success && resp.error) {
      const code = resp.error.code;
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      ) {
        invalidTokens.push(tokens[idx]);
      }
    }
  });

  if (invalidTokens.length > 0) {
    await pool.query('DELETE FROM user_devices WHERE fcm_token IN (?)', [
      invalidTokens,
    ]);
  }

  return {
    notificationId,
    sentCount: response.successCount,
    failedCount: response.failureCount,
    skipped: false,
  };
}

/**
 * Hàm chuyên dụng gọi sau khi thanh toán hóa đơn thành công
 */
async function sendOrderSuccessNotification({
  userId,
  orderId,
  orderCode,
  finalTotal,
}) {
  const title = 'Thanh toán thành công';
  const body = `Đơn hàng ${orderCode} trị giá ${formatVnd(finalTotal)} đã được thanh toán.`;

  return sendNotificationToUser({
    userId,
    orderId,
    title,
    body,
  });
}

module.exports = {
  sendNotificationToUser,
  sendOrderSuccessNotification,
};