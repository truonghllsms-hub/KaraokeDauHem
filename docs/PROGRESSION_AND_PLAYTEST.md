# Ca hướng dẫn, nâng cấp và thoại giao lưu

Ngày 1 chỉ có hai nhóm, lần lượt tới quán. Nhóm đầu hai người hát 45 phút, nhóm sau ba người hát 60 phút; mỗi nhóm tập một lần gọi đồ. Không sinh nhóm ngẫu nhiên chen vào hàng chờ. Khách về và phòng dọn xong thì tổng kết sớm. Bộ đếm được lưu giữa ca, nên tải lại không tạo thêm khách. Ngày 2 trở đi dùng lượng khách theo sao, danh tiếng và quảng bá.

Bốn phòng thường tầng 1 cùng giá mặc định 250.000đ/giờ, chỉnh trước giờ mở cửa trong khoảng 100.000–400.000đ. Sáu phòng VIP mặc định 500.000–750.000đ/giờ, chỉnh trong khoảng 450.000–2.000.000đ. Bản lưu cũ chuyển các mức giá mặc định cũ của tầng 1 về 250.000đ; giá đã tự chỉnh và giá phiên hát đang diễn ra được giữ.

Có chín mục nâng cấp, mỗi mục sáu cấp: âm thanh, micro không dây, dụng cụ phục vụ, điều hòa, cách âm, thiết bị vệ sinh, đào tạo, quảng bá, đèn và nội thất. Giá cấp sau tăng theo hệ số của từng mục. Hiệu quả nối vào mô phỏng thực: hài lòng, tần suất hỏng/nóng, thời gian chờ đồ, tiền điện, tốc độ dọn, tốc độ làm việc/đi bộ và lượng khách. Đào tạo áp dụng ngay cho người đã tuyển; nâng cấp phòng cũng áp dụng cho phòng lắp sau.

Đánh giá giao lưu dùng tên nhân viên thực sự đã phục vụ và chỉ chọn với nhóm phù hợp, từ bốn sao, không có sự cố xấu. Có các nhân vật bình luận như thợ điện, phụ hồ, shipper, hội chị em. Thoại ngồi cạnh đi theo đúng khách được ghép với nhân viên; nhân viên có câu đáp. Gia đình và cặp đôi không dùng nội dung này. Câu khen sáu múi gắn riêng Minh Khang; người đánh giá lớn tuổi chỉ xuất hiện với nhóm phù hợp.

Chữ ở các bảng nhân sự, người giao lưu, nhạc và lưu game tăng lên tối thiểu 22px trong không gian thiết kế 1024×1536. Bong bóng 20px, giới hạn trong cạnh màn hình. Phân biệt thoại nền trắng/chữ đen với yêu cầu nền màu/chữ trắng. Đổi các ký hiệu sao và cảnh báo dễ thiếu glyph ở hóa đơn/tổng kết sang chữ/số. Số việc chờ có nền tương phản và chữ 22px; nút tuyển rút gọn để đọc trọn tên.

## Kiểm chứng trước triển khai

- `tests/run_tests.gd`: 478 kiểm tra, không lỗi; thêm kiểm tra quota ca đầu sau lưu/tải, giá theo tầng, sáu cấp và chi phí tăng, hiệu quả nâng cấp, đối tượng thoại/đánh giá và tên thật.
- `tests/ui_progression.gd`: ba ván mới với seed 7, 42, 2024, mỗi ván ba đêm. Dùng vốn 15 triệu, không thêm tiền thử nghiệm; chọn khách/phòng qua giao diện, chủ quán đi lấy/giao đồ theo đường thực, tuyển phục vụ, mở phòng và mua nâng cấp qua bảng. Cả chín ca kết thúc, nút sang ngày hoạt động; số dư khớp sổ và không vi phạm bất biến. Ba ca đầu đều đúng hai nhóm phục vụ, không nhóm bỏ về. Ngày 2 phục vụ 11–12 nhóm; ngày 3 phục vụ 14–15 nhóm. Lưu giữa ca đọc lại đúng tiền và thời gian.
- `tests/ui_experience.gd`: chỗ ngồi, bong bóng, đường sau quầy, đuổi trộm, xe, cỡ chữ, nút sang ngày ngoài vùng cuộn; bổ sung mua đào tạo sau khi đã tuyển người và kiểm tra tốc độ tăng ngay.
- `tests/ui_content.gd`, `tests/ui_saves.gd`: qua kiểm tra nội dung, đánh giá, menu, tự lưu/tiếp tục và tải khi đang bưng khay.
- Chromium/WebGL ở 512×768: mua âm thanh hai cấp liên tiếp, trừ đúng 10.800.000đ; cuộn xem các nâng cấp; mở Kho/Thu chi; lưu và tải lại giữ cấp 2 cùng 4.200.000đ. Không có lỗi JavaScript hoặc lỗi console.

Chơi thử phát hiện và đã sửa: lời nhắc chờ khách khi khách đang hát; tiền điều hòa ở hộp lựa chọn chưa theo cấp nâng; chữ việc chờ quá nhỏ; xử lý đuổi trước khi hình trộm sẵn sàng; tốc độ nhân viên cũ chưa cập nhật ngay khi mua đào tạo.
