const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const path = require('path');
const fs = require('fs');

const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');

let isFirebaseReady = false;

if (fs.existsSync(serviceAccountPath)) {
  try {
    const serviceAccount = require(serviceAccountPath);
    if (!getApps().length) {
      initializeApp({
        credential: cert(serviceAccount),
      });
    }
    isFirebaseReady = true;
    console.log('✅ Khởi tạo Firebase Admin SDK thành công!');
  } catch (err) {
    console.error('❌ Lỗi đọc file serviceAccountKey.json:', err.message);
  }
} else {
  console.warn('⚠️ Không tìm thấy src/config/serviceAccountKey.json — tạm tắt gửi FCM.');
}

module.exports = { getMessaging, isFirebaseReady };