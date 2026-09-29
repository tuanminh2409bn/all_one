# Tổng kết công việc — all_one

Cập nhật: 2026-09-29, bản `1.0.0+4`. Đây là bản tóm tắt để bàn giao; thông số từng màn hình, tài nguyên và lịch sử kiểm thử chi tiết nằm trong [PROJECT_HANDOFF.md](PROJECT_HANDOFF.md).

## 1. Nền tảng và luồng vào App

- Xây dựng App Flutter mô phỏng giao diện NH All One theo canvas tham chiếu 588×1280, giữ nội dung tiếng Hàn và đối chiếu với ảnh/video App gốc.
- Hoàn thiện chuỗi mở App: logo App native → splash kỷ niệm số 10 → màn hình chứng thư → nhập PIN đăng nhập → hiệu ứng loading → Home. iOS và Android dùng Flutter 3.47.5; cấu hình Xcode Cloud được đồng bộ SDK và Swift Package Manager.
- Có luồng khách và Firebase Email/Password. Tài khoản đã đăng nhập tạo/xác nhận hoặc kiểm tra PIN riêng; PIN được lưu bằng secure storage, tách theo tài khoản và mục đích. Lần nhập sai thứ năm khóa việc xác minh.
- Dữ liệu tài khoản, người nhận, giao dịch và số dư được lưu cục bộ trước; người dùng Firebase đồng bộ trạng thái lên Firestore. Dữ liệu mẫu không được đưa vào sổ giao dịch thật của người dùng mới.

## 2. Home, tài khoản và lịch sử giao dịch

- Dựng Home bằng widget Flutter: header, banner, thẻ tài khoản, các mục ưu đãi, tiện ích, tài sản và thanh điều hướng. Các biểu tượng/logo quan trọng dùng tài nguyên tham chiếu thay vì biểu tượng ước lượng.
- Số dư và nút `숨김` có khoảng cách thiết kế 10 px; nút đi theo chữ số cuối khi số dư dài hơn. Chế độ chữ lớn chỉ tăng kích thước khi người dùng bật.
- Thẻ `오늘의 혜택` dùng chữ Flutter native và ba APNG biểu tượng 140×140 cắt từ video mới ở 30 fps; đổi nội dung mỗi 2,5 giây, chu kỳ 7,5 giây. Hai mũi tên trên nút tài sản được vẽ vector theo nhịp video gốc; có chế độ giảm chuyển động.
- Nút `거래내역` mở màn hình lịch sử với header và danh tính tài khoản cố định, bộ lọc một tháng, giao dịch thu/chi và số dư sau giao dịch. Bộ lọc có chọn khoảng thời gian, loại giao dịch, thứ tự và hộp cảnh báo cho ngày bắt đầu trong tương lai.
- Thêm Loading 2 khi từ Home bấm `거래내역`: phủ Home, đổi sang nền lịch sử ở cuối hiệu ứng rồi bỏ lớp phủ. Các màn hình quản lý tài khoản, quản lý người nhận và hướng dẫn `한도해제` đã được nối luồng và chỉnh vùng an toàn với bàn phím/thanh điều hướng Android.

## 3. Người nhận và chuyển khoản mô phỏng

- Màn hình chọn người nhận hỗ trợ nhập số tài khoản/ngân hàng, người nhận gần đây, thường dùng, tài khoản của tôi và danh bạ. Nút `다음` chỉ bật khi dữ liệu hợp lệ. Logo ngân hàng và chứng khoán được chuẩn hóa theo tài nguyên đã cung cấp.
- Người nhận đã lưu có dấu sao riêng. `삭제하기` chỉ hiện khi danh sách gần đây có người nhận được đánh dấu sao. Mỗi người nhận có công tắc `이체 전 추가 확인` độc lập, được lưu cùng dữ liệu người nhận.
- Chạm người nhận đã lưu mở màn hình nhập tiền, hiển thị tên/số tài khoản đích và số dư thực tế của tài khoản nguồn. Nút dưới cùng giữ màu xám khi chưa nhập tiền, chuyển xanh khi số tiền dương.
- Bàn phím PIN chuyển tiền có bốn dấu tròn xanh lần lượt theo số đã nhập, ba phím điều khiển hàng cuối căn theo ba vị trí độc lập, và hai biểu tượng mờ cắt từ App gốc. Nút xáo bàn phím đổi vị trí cả mười chữ số lẫn hai biểu tượng.
- PIN sai mở hộp `안내`; số lần sai tăng theo từng lần gửi. PIN đúng sẽ mở cảnh báo xác nhận thêm nếu công tắc của người nhận bật, hoặc đi thẳng tới `이체확인` nếu tắt.
- Màn hình `이체확인` được chỉnh logo, tiêu đề, thông tin tài khoản, phí, ghi chú, bút sửa, dấu đóng và kích thước nút theo ảnh gốc. Sau nút xanh, luồng hiện tại **quay về Home và mở lỗi NH6901 mô phỏng**; App chưa thực hiện chuyển khoản ngân hàng thật.
- Popup NH6901 dùng logo NH chất lượng cao thay cho crop JPEG mờ. Các lớp phủ/loading ở bốn chặng chuyển khoản đã được đo theo video và tái sử dụng APNG Loading 2.

## 4. Chữ, bố cục và ảnh tham chiếu

- Font chữ thông thường dùng `NotoSansKR-Medium.otf` ở `w500`, phần nhấn mạnh dùng Bold. Bốn vùng thông tin tài khoản/lịch sử được chỉ định theo ảnh gốc dùng font Regular `w400` thật và màu xám; kiểm thử giới hạn ngoại lệ này, giữ các màn hình khác ở `w500` trở lên.
- Chữ trung tính ở nhiều màn hình được tăng độ tương phản theo phản hồi iOS/Android; vẫn giữ màu xanh, đỏ, trắng cho ý nghĩa trạng thái và một số sắc độ theo đúng ảnh gốc.
- Đã sửa chữ bị co trên lịch sử iOS, các vùng overflow khi nhập người nhận, khoảng cách số dư Home, safe area cho màn hình nhập tiền/xác nhận, và nhiều chi tiết pixel của ảnh chụp App gốc.
- Các trạng thái quan trọng có ảnh golden để so sánh: Home, lịch sử, người nhận, nhập tiền, PIN, cảnh báo, xác nhận, loading và popup lỗi. Ảnh golden chỉ được cập nhật khi thay đổi giao diện có chủ đích và đã xem vùng khác biệt.

## 5. Kiểm thử, build và Git

- Kiểm tra bản mới: bộ test serial đạt **67/74**; toàn bộ test chức năng đạt, còn 7 kịch bản golden lệch ít pixel ở các màn hình không chỉnh lần này. Giữ nguyên các baseline không liên quan. `flutter analyze --no-pub` chỉ báo deprecation `onReorder` đã có từ trước.
- Trước đây đã build và chạy thử APK debug trên Samsung SM-A366B; bản APK release cũng từng build thành công. Xcode Cloud có script post-clone và iOS target 15.0 để dựng dự án từ checkout sạch.
- Archive iOS release không ký bản 4 thành công bằng Flutter 3.47.5 và Xcode 26.5. Kết quả ký/phân phối trên Xcode Cloud cần xác nhận từ check GitHub sau push; archive cục bộ không đồng nghĩa Cloud đã thành công.
- APK Android release bản 4 build thành công, khoảng 131,8 MB, hỗ trợ ARM64/ARMv7/x86_64 và Android 7.0 (API 24) trở lên. File gửi thử: `build/releases/all_one-1.0.0-build4-release.apk`; giữ cấu hình ký debug hiện có. Bộ test chức năng chạy riêng đạt **61/61**.
- Lockfile Dart và các file khóa Swift Package Manager đi cùng cấu hình Flutter 3.47.5 trong bản mới; không còn dùng pin Cloud 3.38.10 cũ.

## 6. Giới hạn cần nhớ khi tiếp tục

- Chữ ưu đãi Home đã chuyển sang native, không còn phóng to chữ trong video. Biểu tượng vẫn bị giới hạn bởi chất lượng nguồn video 140×140; không khẳng định có thể khôi phục chi tiết không tồn tại trong nguồn.
- Kết quả chuyển khoản hiện là luồng giao diện mô phỏng lỗi NH6901, không phải giao dịch ngân hàng thật; không được mô tả cho khách là chuyển tiền thành công.
- APK release hiện dùng cấu hình ký debug; chưa phải gói ký phát hành chính thức. Một số sửa đổi gần nhất chưa được smoke-test trên iPhone/Android vật lý.
- Khi tiếp tục: đọc [AGENTS.md](AGENTS.md) và [PROJECT_HANDOFF.md](PROJECT_HANDOFF.md), giữ nguyên thay đổi chưa commit của người dùng, chạy kiểm thử đúng phạm vi rồi mới build/đẩy theo yêu cầu.
