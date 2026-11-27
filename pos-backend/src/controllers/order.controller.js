const notificationService = require('../services/notification.service');

const pool = require('../config/db');

const FIXED_VAT_PERCENT = 8;

// Khớp 100% quy tắc tính chiết khấu trong CartViewModel của Flutter
function calcDiscountPercent(subTotal) {
  if (subTotal <= 0) return 0;
  if (subTotal > 5000000) return 15;
  if (subTotal > 1000000) return 10;
  return 5;
}

// Sinh mã hóa đơn duy nhất, ví dụ: HD20261127-4821
function generateOrderCode() {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const d = String(now.getDate()).padStart(2, '0');
  const rand = Math.floor(1000 + Math.random() * 9000);
  return `HD${y}${m}${d}-${rand}`;
}

// 1. POST /api/orders -> Thanh toán các món đang tích chọn trong giỏ
exports.createOrder = async (req, res) => {
  const userId = req.user.id;
  const paymentMethod = (req.body.payment_method || 'Tiền mặt').trim();
  const note = (req.body.note || '').trim();

  const conn = await pool.getConnection();

  try {
    await conn.beginTransaction();

    // Bước 1: Lấy các món đang được tích chọn (is_selected = 1) kèm giá gốc từ bảng products
    const [selectedRows] = await conn.query(
      `SELECT
         c.product_id,
         c.quantity,
         p.code AS product_code,
         p.name AS product_name,
         p.unit,
         p.price AS unit_price
       FROM cart_items c
       INNER JOIN products p ON c.product_id = p.id
       WHERE c.user_id = ? AND c.is_selected = 1
       ORDER BY c.created_at ASC`,
      [userId]
    );

    if (selectedRows.length === 0) {
      await conn.rollback();
      return res.status(400).json({
        success: false,
        message: 'Không có sản phẩm nào được chọn để thanh toán',
      });
    }

    // Bước 2: Lấy tên thật của tài khoản đang đăng nhập làm tên nhân viên trên hóa đơn
    const [userRows] = await conn.query(
      'SELECT full_name FROM users WHERE id = ? LIMIT 1',
      [userId]
    );
    const staffName =
      (req.body.staff_name && String(req.body.staff_name).trim()) ||
      (userRows[0] && userRows[0].full_name) ||
      'Nhân viên';

    // Bước 3: Server tự tính tiền từ giá gốc trong DB (không tin tuyệt đối số tiền client gửi lên)
    let subTotal = 0;
    const orderItems = selectedRows.map((row) => {
      const lineTotal = Math.round(row.unit_price * row.quantity * 100) / 100;
      subTotal += lineTotal;
      return {
        product_id: row.product_id,
        product_code: row.product_code,
        product_name: row.product_name,
        unit: row.unit,
        unit_price: row.unit_price,
        quantity: row.quantity,
        line_total: lineTotal,
      };
    });

    const discountPercent = calcDiscountPercent(subTotal);
    const discountAmount = Math.round(subTotal * (discountPercent / 100) * 100) / 100;
    const afterDiscount = subTotal - discountAmount;
    const vatPercent = FIXED_VAT_PERCENT;
    const vatAmount = Math.round(afterDiscount * (vatPercent / 100) * 100) / 100;
    const finalTotal = Math.round((afterDiscount + vatAmount) * 100) / 100;

    const orderCode = generateOrderCode();

    // Bước 4: Lưu hóa đơn tổng vào bảng orders
    const [orderResult] = await conn.query(
      `INSERT INTO orders (
         order_code, user_id, staff_name, payment_method,
         sub_total, discount_percent, discount_amount,
         vat_percent, vat_amount, final_total, note
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        orderCode,
        userId,
        staffName,
        paymentMethod,
        subTotal,
        discountPercent,
        discountAmount,
        vatPercent,
        vatAmount,
        finalTotal,
        note,
      ]
    );

    const orderId = orderResult.insertId;

    // Bước 5: Lưu danh sách mặt hàng vào bảng order_items
    const itemValues = orderItems.map((item) => [
      orderId,
      item.product_id,
      item.product_code,
      item.product_name,
      item.unit,
      item.unit_price,
      item.quantity,
      item.line_total,
    ]);

    await conn.query(
      `INSERT INTO order_items (
         order_id, product_id, product_code, product_name,
         unit, unit_price, quantity, line_total
       ) VALUES ?`,
      [itemValues]
    );

    // Bước 6: Xóa các món đã thanh toán khỏi giỏ hàng (giữ nguyên các món chưa tích chọn)
    await conn.query(
      'DELETE FROM cart_items WHERE user_id = ? AND is_selected = 1',
      [userId]
    );

    // Chốt giao dịch thành công
    await conn.commit();

    // Lưu lịch sử & bắn Push Notification (tách try/catch để không làm lỗi kết quả thanh toán)
    try {
      await notificationService.sendOrderSuccessNotification({
        userId,
        orderId,
        orderCode,
        finalTotal,
      });
    } catch (notifyErr) {
      console.error('Cảnh báo: Không gửi được Push Notification:', notifyErr.message);
    }

    // Lấy lại đầy đủ bản ghi hóa đơn vừa tạo (có đúng created_at từ MySQL) để Flutter mang đi in PDF
    const [[createdOrder]] = await pool.query(
      'SELECT * FROM orders WHERE id = ? LIMIT 1',
      [orderId]
    );

    return res.status(201).json({
      success: true,
      message: 'Thanh toán thành công',
      data: {
        ...createdOrder,
        items: orderItems,
      },
    });
  } catch (err) {
    await conn.rollback();
    console.error('Lỗi createOrder:', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi tạo hóa đơn',
    });
  } finally {
    conn.release();
  }
};

// 2. GET /api/orders -> Xem danh sách lịch sử hóa đơn của user
exports.getOrders = async (req, res) => {
  try {
    const [orders] = await pool.query(
      'SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC LIMIT 50',
      [req.user.id]
    );

    return res.status(200).json({
      success: true,
      data: orders,
    });
  } catch (err) {
    console.error('Lỗi getOrders:', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi tải lịch sử hóa đơn',
    });
  }
};

// 3. GET /api/orders/:id -> Lấy chi tiết 1 hóa đơn (để xem lại hoặc in lại)
exports.getOrderDetail = async (req, res) => {
  try {
    const orderId = parseInt(req.params.id, 10);
    if (Number.isNaN(orderId) || orderId <= 0) {
      return res.status(400).json({
        success: false,
        message: 'ID hóa đơn không hợp lệ',
      });
    }

    const [orders] = await pool.query(
      'SELECT * FROM orders WHERE id = ? AND user_id = ? LIMIT 1',
      [orderId, req.user.id]
    );

    if (orders.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy hóa đơn',
      });
    }

    const [items] = await pool.query(
      'SELECT * FROM order_items WHERE order_id = ? ORDER BY id ASC',
      [orderId]
    );

    return res.status(200).json({
      success: true,
      data: {
        ...orders[0],
        items,
      },
    });
  } catch (err) {
    console.error('Lỗi getOrderDetail:', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi tải chi tiết hóa đơn',
    });
  }
};