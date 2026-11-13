# Bảng công việc

## Đã xong

**Giai đoạn 0 — Dựng nền**
- [x] Dự án Godot 4.5.1, renderer Compatibility, 1280×720 co giãn
- [x] Cấu trúc thư mục, font tiếng Việt, tài liệu
- [x] Màn hình chính và scene quán mở được, không lỗi parse hay thiếu resource

**Giai đoạn 1 — Một lượt khách hoàn chỉnh**
- [x] Đồng hồ mô phỏng, tốc độ 1x/2x/4x, tạm dừng, tự dừng khi mở cửa sổ
- [x] Khách đến, hàng chờ, xếp phòng, hết giờ, tính tiền, dọn phòng, nhận nhóm tiếp
- [x] Sổ giao dịch chống ghi trùng
- [x] Điều kiện xong: 3 lượt liên tiếp, mỗi lượt đúng một hóa đơn, phòng sẵn sàng trở lại (có kiểm thử tự động)

**Làm sớm từ các giai đoạn sau** (vì nhỏ và giúp bản đầu chơi được)
- [x] GĐ2: sinh khách ngẫu nhiên, nhóm bỏ về, đóng cửa 24:00, lương + chi phí, tổng kết, sang ngày mới
- [x] GĐ4: mở Phòng 02, 03 bằng tiền
- [x] GĐ5: bốn nhóm khách với câu thoại, hài lòng và danh tiếng cơ bản

**Đợt 2 — Đồ họa và Lan can**
- [x] Bộ hình SVG nguyên bản: chủ quán, 8 kiểu khách, nhân viên phục vụ, 3 nhân viên Lan can, đồ vật
- [x] Mặt bằng nhìn từ trên xuống, nhân vật đi lại, bóng thoại, xe máy vỉa hè
- [x] Chủ quán do người chơi điều khiển, có hàng việc
- [x] Lan can cơ bản: tuyển, khách gọi, cử vào phòng, phí, tip, nghỉ, lương
- [x] Bản xuất web để chơi trên trình duyệt
- [x] Vẽ lại nhân vật lần 2: đầu to tròn, mắt long lanh, má hồng, tóc có vệt sáng, quần áo đổ bóng

**Đợt 3 — Thêm nội dung**
- [x] Lan can: 8 ứng viên (thêm áo dài, croptop, đầm dạ hội, áo khoác, nam ca sĩ), 3 vị trí, bảng tuyển dụng dạng thẻ có chân dung
- [x] 6 nhóm khách mới: sinh viên, hội bạn nhậu, hội chị em, cặp đôi, gia đình, hội Gen Z (12 hình mới)
- [ ] Chủ dự án duyệt tên nhân viên, tên nhóm và câu thoại

**Đợt 4 — Phần chơi giữa ca, 6 phòng, sân xe**
- [x] Bỏ nhóm sinh viên (còn 9 nhóm), mỗi nhóm có đặc điểm ảnh hưởng thật
- [x] 6 phòng (mở sẵn 2), bố cục hai dãy phòng + sảnh + sân
- [x] Chọn khách rõ ràng: viền sáng, thanh kiên nhẫn xanh/vàng/đỏ, phòng xếp được viền xanh kèm tiền dự kiến, lý do từ chối hiện ngay
- [x] Gọi món (6 mặt hàng, tồn kho, giữ chỗ, hủy thì trả kho), micro hỏng, phòng nóng, xin hát thêm
- [x] Hóa đơn vừa thu: phòng, món, dịch vụ, giảm giá
- [x] Sân xe: mất xe từ đêm 2, thuê bảo vệ
- [x] Mục tiêu mỗi đêm, lời nhận xét của khách, ba món nâng cấp ở bảng tổng kết

## Việc tiếp theo

**Từ góp ý chơi thử, chưa làm**
- [ ] Giá giờ thấp điểm/cao điểm, combo phòng + nước, chia hóa đơn
- [ ] Yêu cầu "không tìm thấy bài hát"; khách quen có phòng và đồ uống yêu thích; gia đình nhạy cảm với độ sạch
- [ ] Âm thanh ("Em ơi thêm đá!", vỗ tay), chi tiết phòng (tablet, tambourine), ngày mưa
- [ ] Mỗi đêm một câu chuyện riêng (ví dụ tổ chức sinh nhật)
- [ ] Lịch làm việc cho Lan can


**Giai đoạn 2 — hoàn tất**
- [ ] Dự báo lượng khách ở màn chuẩn bị
- [ ] Danh tiếng ảnh hưởng lượng khách
- [ ] Chơi tay trọn một đêm trên máy thật và cân bằng lại nhịp khách khi chỉ có một phòng

**Giai đoạn 3 — Hàng hóa và nhân viên**
- [ ] `data/products.json`, kho, đơn hàng PENDING → RESERVED → DELIVERED/CANCELLED
- [ ] Nhân viên phục vụ (đã có hình `waiter.svg`): hàng đợi công việc, năng lượng; đỡ việc dọn phòng cho chủ quán
- [ ] Sự cố thiết bị và sửa chữa (trạng thái BROKEN)

**Giai đoạn 4** — nâng cấp; Lan can: đào tạo, trang phục, khu nghỉ, sự kiện ranh giới · **Giai đoạn 5** — sự kiện, mục tiêu 7 đêm, phá sản, công cụ debug · **Giai đoạn 6** — lưu/tải, cài đặt, âm thanh, hướng dẫn lần đầu

## Lỗi và giới hạn đã biết

- Chưa có xác nhận khi về màn hình chính ngoài dòng cảnh báo trong menu (chưa có save để ghi đè).
- Thao tác chuột và phím thật chưa được kiểm tra tự động (xem `docs/TESTING.md`).
- Hoạt ảnh nhân vật còn đơn giản (nhún và lật hướng), nhóm khách hiện tối đa 3 hình kèm số người.
- Nhân vật đi theo đường thẳng qua hành lang, có thể đi xuyên bàn ghế.
- Nút "Tiếp tục", "Cài đặt", "Kho hàng", "Nhân viên", "Nâng cấp" đang bị khóa, có tooltip báo sẽ làm sau.

## Gợi ý việc có thể giao cho công cụ khác

| Việc | Phạm vi được sửa | Điều kiện xong |
|---|---|---|
| Rà soát logic tiền và trạng thái phòng | chỉ đọc `scripts/core`, `scripts/systems`; thêm ca vào `tests/run_tests.gd` | Bộ kiểm thử vẫn qua, nêu rõ ca mới |
| Đề xuất thoại cho 4 nhóm khách và 10 sự kiện | tệp mới `docs/content_draft.md` (không sửa `data/`) | Chủ dự án duyệt trước khi đưa vào `data/` |
