const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');

// 1. ĐĂNG KÝ: POST /api/auth/register
exports.register = async (req, res) => {
  try {
    const { username, password, full_name } = req.body;

    if (!username || !password || !full_name) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng nhập đầy đủ username, password và full_name',
      });
    }

    const cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.length < 4) {
      return res.status(400).json({
        success: false,
        message: 'Tên đăng nhập phải có ít nhất 4 ký tự',
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Mật khẩu phải có ít nhất 6 ký tự',
      });
    }

    const [existing] = await pool.query(
      'SELECT id FROM users WHERE username = ? LIMIT 1',
      [cleanUsername]
    );

    if (existing.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'Tên đăng nhập đã tồn tại',
      });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const [result] = await pool.query(
      'INSERT INTO users (username, password_hash, full_name) VALUES (?, ?, ?)',
      [cleanUsername, passwordHash, full_name.trim()]
    );

    return res.status(201).json({
      success: true,
      message: 'Đăng ký tài khoản thành công',
      data: {
        id: result.insertId,
        username: cleanUsername,
        full_name: full_name.trim(),
      },
    });
  } catch (err) {
    console.error('Lỗi đăng ký:', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi đăng ký',
    });
  }
};

// 2. ĐĂNG NHẬP: POST /api/auth/login
exports.login = async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng nhập tên đăng nhập và mật khẩu',
      });
    }

    const cleanUsername = username.trim().toLowerCase();

    // Tìm user trong MySQL
    const [rows] = await pool.query(
      'SELECT id, username, password_hash, full_name FROM users WHERE username = ? LIMIT 1',
      [cleanUsername]
    );

    if (rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Sai tên đăng nhập hoặc mật khẩu',
      });
    }

    const user = rows[0];

    // So sánh mật khẩu nhập vào với chuỗi đã mã hóa trong DB
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Sai tên đăng nhập hoặc mật khẩu',
      });
    }

    // Tạo JWT token có hạn 7 ngày
    const token = jwt.sign(
      { id: user.id, username: user.username },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    return res.status(200).json({
      success: true,
      message: 'Đăng nhập thành công',
      data: {
        token,
        user: {
          id: user.id,
          username: user.username,
          full_name: user.full_name,
        },
      },
    });
  } catch (err) {
    console.error('Lỗi đăng nhập:', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi đăng nhập',
    });
  }
};

// 3. LẤY THÔNG TIN USER ĐANG ĐĂNG NHẬP: GET /api/auth/me
exports.getMe = async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, username, full_name, created_at FROM users WHERE id = ? LIMIT 1',
      [req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy tài khoản',
      });
    }

    return res.status(200).json({
      success: true,
      data: rows[0],
    });
  } catch (err) {
    console.error('Lỗi getMe:', err);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi lấy thông tin tài khoản',
    });
  }
};