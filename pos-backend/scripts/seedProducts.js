const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const pool = require('../src/config/db');

const TOTAL_PRODUCTS = 100000;
const BATCH_SIZE = 5000;

// Đúng 30 sản phẩm mẫu từ app Flutter của bạn (24 ảnh + 6 video < 5MB)
const SEED_TEMPLATES = [
  { name: 'Cà phê Arabica Cầu Đất', unit: 'Hộp', price: 125000, discount_percent: 5, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/1060/400/400' },
  { name: 'Trà Oolong Bảo Lộc', unit: 'Gói', price: 85000, discount_percent: 0, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/225/400/400' },
  { name: 'Bánh quy bơ Đan Mạch', unit: 'Hộp', price: 160000, discount_percent: 10, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/292/400/400' },
  { name: 'Mật ong hoa nhãn', unit: 'Chai', price: 210000, discount_percent: 5, vat_percent: 0, media_type: 'image', media_url: 'https://picsum.photos/id/312/400/400' },
  { name: 'Video Demo Sản phẩm Ong', unit: 'Hộp', price: 320000, discount_percent: 10, vat_percent: 10, media_type: 'video', media_url: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4' },
  { name: 'Sữa tươi không đường', unit: 'Lốc', price: 38000, discount_percent: 0, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/429/400/400' },
  { name: 'Hạt điều rang muối', unit: 'Hũ', price: 145000, discount_percent: 5, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/431/400/400' },
  { name: 'Nước ép cam nguyên chất', unit: 'Chai', price: 45000, discount_percent: 0, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/488/400/400' },
  { name: 'Socola đen 70%', unit: 'Thanh', price: 65000, discount_percent: 5, vat_percent: 10, media_type: 'image', media_url: 'https://picsum.photos/id/493/400/400' },
  { name: 'Video Review Hạt dinh dưỡng', unit: 'Gói', price: 195000, discount_percent: 15, vat_percent: 8, media_type: 'video', media_url: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4' },
  { name: 'Gạo ST25 thượng hạng', unit: 'Túi', price: 175000, discount_percent: 0, vat_percent: 0, media_type: 'image', media_url: 'https://picsum.photos/id/102/400/400' },
  { name: 'Dầu ô liu nguyên chất', unit: 'Chai', price: 240000, discount_percent: 10, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/1080/400/400' },
  { name: 'Mì Ý Spaghetti số 5', unit: 'Gói', price: 52000, discount_percent: 0, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/113/400/400' },
  { name: 'Sốt cà chua hữu cơ', unit: 'Lọ', price: 78000, discount_percent: 5, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/139/400/400' },
  { name: 'Video Trải nghiệm Đồ uống', unit: 'Thùng', price: 290000, discount_percent: 10, vat_percent: 10, media_type: 'video', media_url: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4' },
  { name: 'Ngũ cốc yến mạch', unit: 'Hộp', price: 115000, discount_percent: 5, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/163/400/400' },
  { name: 'Nước mắm Phú Quốc', unit: 'Chai', price: 95000, discount_percent: 0, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/200/400/400' },
  { name: 'Hạt hạnh nhân Mỹ', unit: 'Túi', price: 180000, discount_percent: 10, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/250/400/400' },
  { name: 'Mứt dâu tây Đà Lạt', unit: 'Hũ', price: 68000, discount_percent: 0, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/260/400/400' },
  { name: 'Video Giới thiệu Gia vị', unit: 'Bộ', price: 150000, discount_percent: 5, vat_percent: 8, media_type: 'video', media_url: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4' },
  { name: 'Nước khoáng có ga', unit: 'Lốc', price: 60000, discount_percent: 0, vat_percent: 10, media_type: 'image', media_url: 'https://picsum.photos/id/305/400/400' },
  { name: 'Bơ đậu phộng mịn', unit: 'Hũ', price: 82000, discount_percent: 5, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/326/400/400' },
  { name: 'Cà phê sữa hòa tan', unit: 'Hộp', price: 74000, discount_percent: 0, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/365/400/400' },
  { name: 'Trà xanh matcha Nhật', unit: 'Gói', price: 135000, discount_percent: 10, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/400/400/400' },
  { name: 'Video Đóng gói Quà tặng', unit: 'Hộp', price: 450000, discount_percent: 15, vat_percent: 10, media_type: 'video', media_url: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4' },
  { name: 'Kẹo dẻo trái cây', unit: 'Gói', price: 32000, discount_percent: 0, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/425/400/400' },
  { name: 'Nho khô không hạt', unit: 'Hộp', price: 98000, discount_percent: 5, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/445/400/400' },
  { name: 'Sữa hạt óc chó', unit: 'Thùng', price: 265000, discount_percent: 10, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/460/400/400' },
  { name: 'Bánh gạo nướng', unit: 'Gói', price: 28000, discount_percent: 0, vat_percent: 8, media_type: 'image', media_url: 'https://picsum.photos/id/475/400/400' },
  { name: 'Video Combo Tiết kiệm', unit: 'Combo', price: 399000, discount_percent: 10, vat_percent: 10, media_type: 'video', media_url: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4' },
];

async function seedProducts() {
  const conn = await pool.getConnection();
  const startTime = Date.now();

  try {
    console.log('🧹 Đang dọn dữ liệu cũ ở bảng products và product_media...');
    await conn.query('SET FOREIGN_KEY_CHECKS = 0');
    await conn.query('TRUNCATE TABLE product_media');
    await conn.query('TRUNCATE TABLE products');
    await conn.query('SET FOREIGN_KEY_CHECKS = 1');

    console.log(`🚀 Bắt đầu nạp ${TOTAL_PRODUCTS} sản phẩm & media...`);
    const templateCount = SEED_TEMPLATES.length;

    for (let offset = 0; offset < TOTAL_PRODUCTS; offset += BATCH_SIZE) {
      const productRows = [];
      const mediaRows = [];

      for (let i = 1; i <= BATCH_SIZE && offset + i <= TOTAL_PRODUCTS; i++) {
        const id = offset + i;
        const tpl = SEED_TEMPLATES[(id - 1) % templateCount];
        const code = `SP${String(id).padStart(6, '0')}`;

        productRows.push([
          id,
          code,
          `${tpl.name} #${id}`,
          tpl.unit,
          tpl.price,
          tpl.discount_percent,
          tpl.vat_percent,
        ]);

        mediaRows.push([
          id,
          tpl.media_type,
          tpl.media_url,
        ]);
      }

      await conn.query(
        'INSERT INTO products (id, code, name, unit, price, discount_percent, vat_percent) VALUES ?',
        [productRows]
      );

      await conn.query(
        'INSERT INTO product_media (product_id, media_type, media_url) VALUES ?',
        [mediaRows]
      );

      const loaded = Math.min(offset + BATCH_SIZE, TOTAL_PRODUCTS);
      console.log(`   -> Đã nạp ${loaded.toLocaleString()} / ${TOTAL_PRODUCTS.toLocaleString()} dòng`);
    }

    const seconds = ((Date.now() - startTime) / 1000).toFixed(2);
    console.log(`✅ Hoàn tất nạp 100.000 sản phẩm & 100.000 media trong ${seconds} giây!`);
  } catch (err) {
    console.error('❌ Lỗi khi nạp dữ liệu:', err);
  } finally {
    conn.release();
    await pool.end();
  }
}

seedProducts();