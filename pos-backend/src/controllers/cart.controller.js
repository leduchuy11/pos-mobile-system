const pool = require('../config/db');

// Hàm phụ: lấy toàn bộ danh sách sản phẩm trong giỏ của 1 user (kèm thông tin sản phẩm mới nhất)
async function fetchUserCart(userId) {
  const [rows] = await pool.query(
    `SELECT
       c.id AS cart_item_id,
       c.quantity,
       c.is_selected,
       p.id,
       p.code,
       p.name,
       p.unit,
       p.price,
       p.discount_percent,
       p.vat_percent
     FROM cart_items c
     INNER JOIN products p ON c.product_id = p.id
     WHERE c.user_id = ?
     ORDER BY c.created_at DESC`,
    [userId]
  );

  // Gom đúng cấu trúc để Flutter parse thẳng vào CartItemModel và ProductModel
  return rows.map((row) => ({
    id: row.cart_item_id,
    quantity: row.quantity,
    is_selected: Boolean(row.is_selected),
    product: {
      id: row.id,
      code: row.code,
      name: row.name,
      unit: row.unit,
      price: row.price,
      discount_percent: row.discount_percent,
      vat_percent: row.vat_percent,
    },
  }));
}

// 1. GET /api/cart -> Lấy giỏ hàng hiện tại của user đang đăng nhập
exports.getCart = async (req, res) => {
  try {
    const items = await fetchUserCart(req.user.id);
    return res.status(200).json({
      success: true,
      data: items,
    });
  } catch (err) {
    console.error('Lỗi getCart:', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi tải giỏ hàng',
    });
  }
};

// 2. POST /api/cart/items -> Thêm sản phẩm vào giỏ (đã có thì tự cộng dồn số lượng)
exports.addToCart = async (req, res) => {
  try {
    const userId = req.user.id;
    const productId = parseInt(req.body.product_id, 10);
    const quantity = parseInt(req.body.quantity, 10) || 1;

    if (Number.isNaN(productId) || productId <= 0 || quantity <= 0) {
      return res.status(400).json({
        success: false,
        message: 'product_id và quantity phải là số dương hợp lệ',
      });
    }

    // Kiểm tra sản phẩm có tồn tại không
    const [products] = await pool.query(
      'SELECT id FROM products WHERE id = ? LIMIT 1',
      [productId]
    );
    if (products.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy sản phẩm',
      });
    }

    // Chèn mới hoặc cộng dồn số lượng nhờ khóa UNIQUE(user_id, product_id)
    await pool.query(
      `INSERT INTO cart_items (user_id, product_id, quantity, is_selected)
       VALUES (?, ?, ?, 1)
       ON DUPLICATE KEY UPDATE
         quantity = quantity + ?,
         is_selected = 1`,
      [userId, productId, quantity, quantity]
    );

    const items = await fetchUserCart(userId);
    return res.status(200).json({
      success: true,
      message: 'Đã thêm vào giỏ hàng',
      data: items,
    });
  } catch (err) {
    console.error('Lỗi addToCart:', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi thêm vào giỏ hàng',
    });
  }
};

// 3. PATCH /api/cart/items/:productId -> Cập nhật số lượng hoặc trạng thái tích chọn của 1 SP
exports.updateCartItem = async (req, res) => {
  try {
    const userId = req.user.id;
    const productId = parseInt(req.params.productId, 10);
    const { quantity, is_selected } = req.body;

    if (Number.isNaN(productId) || productId <= 0) {
      return res.status(400).json({
        success: false,
        message: 'productId không hợp lệ',
      });
    }

    // Nếu số lượng giảm về <= 0 thì xóa luôn khỏi giỏ
    if (quantity !== undefined) {
      const parsedQty = parseInt(quantity, 10);
      if (Number.isNaN(parsedQty)) {
        return res.status(400).json({
          success: false,
          message: 'quantity không hợp lệ',
        });
      }
      if (parsedQty <= 0) {
        await pool.query(
          'DELETE FROM cart_items WHERE user_id = ? AND product_id = ?',
          [userId, productId]
        );
        return res.status(200).json({
          success: true,
          message: 'Đã xóa sản phẩm khỏi giỏ hàng',
        });
      }
    }

    const updates = [];
    const params = [];

    if (quantity !== undefined) {
      updates.push('quantity = ?');
      params.push(parseInt(quantity, 10));
    }
    if (is_selected !== undefined) {
      updates.push('is_selected = ?');
      params.push(is_selected ? 1 : 0);
    }

    if (updates.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Không có dữ liệu nào để cập nhật',
      });
    }

    params.push(userId, productId);
    const [result] = await pool.query(
      `UPDATE cart_items SET ${updates.join(', ')} WHERE user_id = ? AND product_id = ?`,
      params
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'Sản phẩm không có trong giỏ hàng',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Cập nhật giỏ hàng thành công',
    });
  } catch (err) {
    console.error('Lỗi updateCartItem:', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi cập nhật giỏ hàng',
    });
  }
};

// 4. PATCH /api/cart/select-all -> Chọn tất cả / bỏ chọn tất cả
exports.toggleSelectAll = async (req, res) => {
  try {
    const userId = req.user.id;
    const isSelected = req.body.is_selected ? 1 : 0;

    await pool.query(
      'UPDATE cart_items SET is_selected = ? WHERE user_id = ?',
      [isSelected, userId]
    );

    return res.status(200).json({
      success: true,
      message: 'Đã cập nhật trạng thái chọn tất cả',
    });
  } catch (err) {
    console.error('Lỗi toggleSelectAll:', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi cập nhật chọn tất cả',
    });
  }
};

// 5. DELETE /api/cart/items/:productId -> Xóa 1 sản phẩm khỏi giỏ
exports.removeCartItem = async (req, res) => {
  try {
    const userId = req.user.id;
    const productId = parseInt(req.params.productId, 10);

    if (Number.isNaN(productId) || productId <= 0) {
      return res.status(400).json({
        success: false,
        message: 'productId không hợp lệ',
      });
    }

    await pool.query(
      'DELETE FROM cart_items WHERE user_id = ? AND product_id = ?',
      [userId, productId]
    );

    return res.status(200).json({
      success: true,
      message: 'Đã xóa sản phẩm khỏi giỏ hàng',
    });
  } catch (err) {
    console.error('Lỗi removeCartItem:', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi xóa sản phẩm khỏi giỏ',
    });
  }
};