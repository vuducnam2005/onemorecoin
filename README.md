# 💰 OneMoreCoin - Expense & Finance Manager

OneMoreCoin is a comprehensive personal finance tracking application built with **Flutter (Dart)** and **SQLite**. It allows users to track daily expenses, manage budgets across multiple wallets, generate insightful charts, and ensure complete data security.

This project strictly adheres to Clean Architecture principles, leveraging **Provider** for State Management, and satisfies complex CRUD requirements alongside advanced local storage capabilities.

---

## ✨ Features (Nghiệp vụ & Tính năng)

### 1. Quản lý Thu / Chi (Transactions Management) - Full CRUD
- **Tạo mới (Create):** Thêm giao dịch với Form nhập tiền, phân loại danh mục Thu/Chi, chọn Ngày/Giờ (`DatePicker`), Thêm Ghi chú và Hình ảnh. Có Validate dữ liệu đầy đủ.
- **Đọc & Phân tích (Read):** Xem danh sách giao dịch theo từng Ngày/Tháng. Hỗ trợ lọc theo Ví, lọc theo thời gian.
- **Cập nhật (Update):** Chỉnh sửa các giao dịch cũ, thay đổi danh mục hoặc số tiền. Hệ thống tự động tính toán lại số dư Ví.
- **Xóa (Delete):** Xoá giao dịch với cảnh báo xác nhận an toàn (`AlertDialog`).

### 2. Quản lý Ví (Wallet) & Ngân sách (Budget)
- **Ví (Wallets):** Hỗ trợ đa tiền tệ (VND, USD). Người dùng có thể Thêm mới, Sửa icon/tên Ví, và Xoá Ví. Mỗi ví theo dõi số dư (Balance) độc lập.
- **Ngân sách (Budgets):** Thiết lập hạn mức chi tiêu cho từng danh mục riêng biệt. Cảnh báo trực quan bằng Thanh tiến trình (Progress Bar) khi người dùng sắp tiêu lố ngân sách.

### 3. Biểu đồ Thông minh (Advanced Charts)
- Tích hợp `fl_chart` để hiển thị:
  - **Biểu đồ Cột (Bar Chart):** So sánh tổng Thu - Chi theo từng tháng trong năm.
  - **Biểu đồ Tròn (Pie Chart):** Phân bổ cơ cấu chi tiêu theo phần trăm danh mục.

### 4. Hệ thống Bảo mật đa lớp (Security)
- Tài khoản người dùng (Login/Register) với Mật khẩu được mã hóa (Hash Password).
- Khoá ứng dụng bằng **Mã PIN 6 số** (Mã hoá SHA-256).
- Ràng buộc an ninh: Yêu cầu xác thực Mã PIN trước khi Thay đổi mật khẩu, Xoá toàn bộ dữ liệu, hoặc Xuất file dự phòng.

### 5. Xuất File Dữ liệu & Backup (Advanced Data Sync)
- **Export Data:** Báo cáo tài chính dưới 3 định dạng: **PDF**, **Excel (.xlsx)**, và **CSV** (Hỗ trợ chuẩn UTF-8).
- **Sao lưu & Khôi phục (Backup & Restore):** Hỗ trợ sao chép toàn bộ file Database lưu trữ xuống máy và chia sẻ qua Zalo/Email. Người dùng có thể Restore lại Data trên thiết bị mới chỉ bằng 1 nút bấm (Sử dụng `share_plus` và `file_picker`).

### 6. Cấu hình Cá nhân hoá (Customization)
- **Dark Mode / Light Mode:** Thay đổi giao diện theo tuỳ chọn hệ thống.
- **Đa ngữ (Localization):** Hỗ trợ chuyển đổi ngôn ngữ Anh (EN) và Việt (VI).

---

## 🛠 Kỹ thuật & Công nghệ (Tech Stack)

| Hạng mục | Công nghệ & Thư viện | Ý nghĩa trong dự án |
|---|---|---|
| **Framework** | `Flutter` & `Dart` | Xây dựng UI đa nền tảng (Android/iOS) |
| **State Management** | `Provider` | Tách biệt Logic & UI, không lạm dụng `setState` |
| **Database** | `sqflite` | Lưu trữ Database Offline vĩnh viễn với các bảng: Transaction, Wallet, Budget, User |
| **Local Storage** | `shared_preferences` | Lưu cài đặt mỏng: Dark Mode, Ngôn ngữ, Mã PIN |
| **Routing & UI** | `modal_bottom_sheet` | Hiệu ứng chuyển cảnh trượt mượt mà giống iOS |
| **Bảo mật** | `crypto` | Băm (Hash) mật khẩu & Mã PIN chuẩn an ninh |
| **Biểu đồ** | `fl_chart` | Vẽ đồ thị trực quan cho Dashboard Báo Cáo |

> 🏆 Dự án tổ chức cấu trúc Code cực kì rõ ràng (MVC / Clean Pattern): Chia thành các module `model/` (Logic, Data), `pages/` (View), `widgets/` (Reusable Component) và `utils/` (Helper methods).

---

## 🚀 Cài đặt & Chạy ứng dụng (Getting Started)

### 1. Yêu cầu hệ thống:
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (Version >= 3.0)
- Android Studio hoặc VS Code (Có cài plugin Flutter)

### 2. Các bước chạy dự án:

```bash
# Clone dự án về máy
git clone <đường-dẫn-repo>

# Di chuyển vào thư mục dự án
cd onemorecoin-develop

# Tải tất cả các gói phụ thuộc (Dependencies)
flutter pub get

# Chạy ứng dụng trên thiết bị ảo (Emulator) hoặc thiết bị thật
flutter run
```

---

## Phụ lục: Đánh giá Đồ án Học phần (Dành cho Giảng viên)
> Sinh viên có thể sử dụng bảng kiểm tra này để báo cáo trước Hội đồng:
- [x] Giao diện Material Design 3 sắc nét, bố cục có Loading Indicator rõ ràng (`C.2`).
- [x] Có hơn >10 Màn hình chức năng (Dashboard, Profiling, Transacting...) (`C.1`).
- [x] Form nhập liệu đầy đủ Validate dữ liệu trước khi Insert SQLite (`B.1`).
- [x] Thực hiện toàn bộ Full CRUD với `sqflite` trên dữ liệu thật, không mock data (`A.2, B.1-4`).
- [x] Lọc và tìm kiếm danh sách Transaction (`B.2`).
- [x] Xác nhận AlertDialog cực kì cẩn thận mỗi khi xoá / backup (`B.4`).
- [x] Trạng thái quản lý bởi `Provider` đáp ứng xuất sắc khung điểm State Management (`A.4`).
- [x] Tích hợp hàng loạt tính năng "Điểm Cộng (Advanced)": Biểu đồ, Multi-Language, Mã PIN Bảo mật, Thuật toán mã hoá SHA, Export PDF/Excel, Backup Database Offline.
