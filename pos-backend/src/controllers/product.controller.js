const pool = require('../config/db');

// LUỒNG 1: GET /api/products?page=1&limit=10
// Lấy danh sách 10 sản phẩm cơ bản theo trang
exports.getProductsByPage = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit, 10) || 10));
    const offset = (page - 1) * limit;

    // Đếm tổng số sản phẩm để tính tổng số trang (100.000 / 10 = 10.000 trang)
    const [[{ total }]] = await pool.query('SELECT COUNT(*) AS total FROM products');
    const totalPages = Math.ceil(total / limit);

    // Tối ưu phân trang sâu (kể cả nhảy thẳng trang 10.000 vẫn nhanh nhờ chỉ lọc trên cột id đã đánh index)
    const [items] = await pool.query(
      `SELECT p.id, p.code, p.name, p.unit, p.price, p.discount_percent, p.vat_percent
       FROM products p
       INNER JOIN (
         SELECT id FROM products ORDER BY id ASC LIMIT ? OFFSET ?
       ) AS page_ids ON p.id = page_ids.id
       ORDER BY p.id ASC`,
      [limit, offset]
    );

    return res.status(200).json({
      success: true,
      data: {
        page,
        limit,
        totalProducts: total,
        totalPages,
        items,
      },
    });
  } catch (err) {
    console.error('Lỗi Luồng 1 (getProductsByPage):', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi tải danh sách sản phẩm',
    });
  }
};

// LUỒNG 2: GET /api/products/:id/stock
// Giả lập độ trễ tồn kho rồi trả về 10 (KHÔNG giữ kết nối MySQL lúc đang sleep)
exports.getProductStock = async (req, res) => {
  try {
    const productId = parseInt(req.params.id, 10);
    if (Number.isNaN(productId) || productId <= 0) {
      return res.status(400).json({
        success: false,
        message: 'ID sản phẩm không hợp lệ',
      });
    }

    const sleepMs = Number(process.env.STOCK_SLEEP_MS) || 3000;
    await new Promise((resolve) => setTimeout(resolve, sleepMs));

    return res.status(200).json({
      success: true,
      data: {
        product_id: productId,
        stock: 10,
      },
    });
  } catch (err) {
    console.error('Lỗi Luồng 2 (getProductStock):', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi tải tồn kho',
    });
  }
};

// LUỒNG 3: GET /api/products/:id/media
// Lấy link ảnh / video (<5MB) độc lập cho 1 sản phẩm
exports.getProductMedia = async (req, res) => {
  try {
    const productId = parseInt(req.params.id, 10);
    if (Number.isNaN(productId) || productId <= 0) {
      return res.status(400).json({
        success: false,
        message: 'ID sản phẩm không hợp lệ',
      });
    }

    const [rows] = await pool.query(
      'SELECT product_id, media_type, media_url FROM product_media WHERE product_id = ? LIMIT 1',
      [productId]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy media cho sản phẩm này',
      });
    }

    return res.status(200).json({
      success: true,
      data: rows[0],
    });
  } catch (err) {
    console.error('Lỗi Luồng 3 (getProductMedia):', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi tải media sản phẩm',
    });
  }
};