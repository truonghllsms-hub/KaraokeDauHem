# Kiểm thử

## Kiểm thử logic (tự động, không cần màn hình)

```bash
godot --headless --path . --script res://tests/run_tests.gd
```

Kết thúc bằng dòng `N kiểm tra, 0 lỗi.` và mã thoát 0. Nếu trong kết quả có dòng `SCRIPT ERROR` thì coi là hỏng, kể cả khi số lỗi là 0.

Phạm vi:
- Định dạng và làm tròn tiền, tiền phòng theo phút
- Đồng hồ: ba tốc độ, tạm dừng, tự dừng khi mở cửa sổ và chạy lại đúng tốc độ
- Lan can: tuyển, giới hạn vị trí, phân công trùng, thu phí một lần, không gia hạn, tip, về sớm không thu, lương
- Ba lượt khách liên tiếp: mỗi lượt một hóa đơn, chặn ghi trùng, phòng quay về sẵn sàng
- Quy tắc xếp phòng: sức chứa, phòng khóa/bẩn/đang dọn/có khách
- Hết kiên nhẫn, chỉnh giá, mở phòng, thiếu tiền
- Giờ đóng cửa: không nhận lượt quá 24:00, chi phí cuối đêm trừ đúng một lần, sang đêm 2
- Bot tự chơi 3 đêm × 3 seed, kiểm tra bất biến ở từng phút; cùng seed cho cùng diễn biến

## Chạy thử giao diện (tự động, cần màn hình hoặc xvfb)

```bash
godot --path . --script res://tests/ui_smoke.gd -- /đường/dẫn/thư_mục_ảnh
```

Trên máy không có màn hình:

```bash
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --script res://tests/ui_smoke.gd -- /tmp/anh
```

Kịch bản mở màn hình chính, vào game, tự chơi trọn một đêm bằng đúng các thao tác của người chơi (chọn khách, bấm phòng, cử Lan can), và chụp 10 ảnh. Nó **không** giả lập cú bấm chuột hay phím thật.

## Kịch bản chơi thử bằng tay

1. "Chơi mới" → "Kho hàng" xem tồn → "MỞ CỬA ĐÓN KHÁCH" → phím `3` tua tới khi có khách.
2. Bấm nhóm khách: phải thấy viền sáng, chữ "ĐANG CHỌN", dòng "Chọn phòng cho nhóm…", phòng xếp được viền xanh.
3. Bấm phòng chưa mở hoặc thiếu chỗ: lý do hiện ngay. Bấm phòng viền xanh: chủ quán dẫn khách vào.
4. Khi phòng hiện nhãn: vàng → bấm để giao món; đỏ → bấm để đổi micro; cam/xanh → bấm để chọn.
5. Khách về: xem "HÓA ĐƠN VỪA THU", rồi bấm phòng bẩn để dọn.
6. Hết đêm 1: đọc tổng kết, thử mua một nâng cấp. Đêm 2: thử không thuê bảo vệ để thấy mất xe.

## Kết quả gần nhất (13/11/2026, Godot 4.5.1 stable, Linux)

| Kiểm tra | Kết quả |
|---|---|
| `tests/run_tests.gd` | 192 kiểm tra, 0 lỗi |
| `tests/ui_smoke.gd` (xvfb) | Tự chơi 2 đêm bằng thao tác của người chơi, 16 kiểm tra, 0 lỗi, chạy 3 lần; đã xem ảnh chụp |
| Bản web trên Chromium (chuột và phím thật) | Chơi mới → Mở cửa → chọn nhóm → bấm phòng → mở Kho hàng: đúng, không lỗi console |

Chưa xác minh:
- Bằng chuột thật: giao món, đổi micro, cửa sổ lựa chọn, Lan can, bảo vệ (mới qua kịch bản gọi hàm)
- Tooltip và phím `Esc`
- Chạy trên Windows/macOS và ở kích thước cửa sổ khác 1280×720
- Cảm giác chơi và cân bằng khi người thật chơi trọn một đêm
