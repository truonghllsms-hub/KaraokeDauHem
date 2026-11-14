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

## Chơi thử tự động để soi cân bằng

```bash
godot --headless --path . --script res://tests/playtest.gd -- 1 7
```

In kết quả từng đêm (phục vụ, bỏ về, thu chi, danh tiếng, sao, khách quen, mục tiêu). Không có đạt/trượt.

## Kết quả nhánh nội dung (14/11/2026)

| Kiểm tra | Kết quả |
|---|---|
| `tests/run_tests.gd` | 341 kiểm tra, 0 lỗi (thêm nhân viên, khách quen, lưu/tải, phòng VIP, sao, câu hát) |
| `ui_smoke.gd`, `ui_redesign.gd`, `ui_reference.gd` | Đều qua: giao diện hiện tại vẫn chạy với luật mới |
| `playtest.gd` 3 seed × 7 đêm | Không vi phạm bất biến; danh tiếng không còn chạm 100 sau 5 đêm; mục tiêu đêm lúc đạt lúc trượt |

## Giao diện cho đợt nội dung

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1024x1536 --script res://tests/ui_content.gd -- /tmp/anh
```

22 điều kiện: phòng chưa lắp thiết bị, bảng thiết bị/lợi ích/chi phí, lắp trừ tiền một lần, khóa VIP khi tầng 2 chưa mở,
nút mở cửa, lý do xếp phòng, câu hát ♪ trên đầu khách, nhân viên phục vụ đi lại, tổng kết có điểm sao, không nhân đôi
đánh giá, nút Tiếp tục tải đúng bản lưu. Lần chạy 14/11/2026: 0 lỗi; cùng lúc `run_tests` 352 kiểm tra, `party_rules`,
`two_floors`, `ui_smoke`, `ui_redesign`, `ui_reference`, `ui_characters`, `ui_fixed_sizes` đều 0 lỗi.

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

## Kiểm tra giao diện nhìn từ trên xuống

```bash
godot --path . --rendering-driver opengl3 --audio-driver Dummy --script res://tests/ui_redesign.gd
```

`ui_redesign.gd` kiểm tra 15 điều kiện: mười vùng phòng không chồng nhau, hai dãy đối diện, chỉ mở sẵn hai phòng, camera ban đầu, vùng cuộn, thanh điều hướng cố định, cửa sổ Nhân sự/Bảo vệ, nút mở khóa và lối ra của quầy. Đây là kiểm tra bố cục; không thay thế việc thử bằng chuột/vuốt trong trình duyệt.

Kết quả cho đợt thiết kế lại (13/11/2026, Godot 4.5.1):

- `run_tests.gd`: 192 kiểm tra, 0 lỗi.
- `ui_redesign.gd`: 15 điều kiện, 0 lỗi.
- `ui_smoke.gd`: chơi hai đêm qua giao diện, 0 lỗi; giao món, đổi micro, gia hạn, hóa đơn và thuê bảo vệ vẫn hoạt động.
- Chromium: kiểm tra màn hình 600×1000 và 1280×800, chọn Chơi mới, cuộn bản đồ bằng chuột, mở phòng khóa và mở Nhân sự bằng chuột. Thiết bị di động thật chưa được kiểm tra.

## Kiểm tra khớp mẫu đã duyệt

```bash
godot --path . --resolution 1024x1536 --rendering-driver opengl3 --audio-driver Dummy --script res://tests/ui_reference.gd
```

`ui_reference.gd` so sánh toàn bộ điểm ảnh màn hình chuẩn bị với `assets/reference/approved_ui.png`, rồi kiểm tra số tiền sau nhập kho, mở khóa phòng, giờ mô phỏng, tốc độ và nút Nhân sự. Ảnh nền là atlas đồ họa; các vùng bấm và số liệu vẫn là thành phần hoạt động trong game. Kiểm thử này chạy ở đúng tỷ lệ thiết kế 1024×1536; trên màn hình khác game giữ tỷ lệ và có lề.

Mở cửa bằng nút tạm dừng trên thanh trên cùng hoặc **Quán → MỞ CỬA ĐÓN KHÁCH**. Logo góc trên trái mở menu; phím tắt cũ vẫn dùng được. Không có nút nổi giữa sảnh hoặc dải công việc bổ sung ngoài mẫu.

## Giới hạn nhóm và kích thước nhân vật

- `tests/party_rules.gd`: 35 kiểm tra, gồm 500 lượt sinh nhóm trong phòng tăng sức chứa, từ chối nhóm quá 5 khách và kiểm tra mọi bố trí 1–5 khách cùng 0–5 nhân viên ở cả hai dãy. Khung người cố định 88×108, không chồng lấn.
- `tests/ui_fixed_sizes.gd`: dựng 5 khách và 5 nhân viên trong một phòng, xác nhận kích thước thực của sprite và kích thước khi chọn nhóm. Khách ngồi cao 94 px, nhân viên ngồi cao 104 px, không đổi theo số người.
- `tests/ui_reference.gd`: giữ nguyên điểm ảnh HUD và thanh điều hướng; mỗi tầng vừa vùng chơi, không cần cuộn dài.
- `tests/ui_characters.gd`: hoạt ảnh đi lại, hát, biểu cảm và hướng TV của hai dãy.

Chạy các kiểm tra giao diện ở độ phân giải thiết kế 1024×1536 với renderer OpenGL và audio Dummy. `ui_fixed_sizes.gd` ghi ảnh kiểm tra vào `user://five-guests-fixed.png` (hoặc đường dẫn truyền sau `--`).

## Hai tầng đã tích hợp

`tests/two_floors.gd` kiểm tra 4 phòng thường + 6 VIP, điều kiện mở tầng (4 phòng thường và 60 danh tiếng), không trừ tiền khi chặn mở VIP, giữ quyền lên tầng sau khi giảm danh tiếng, mở từng phòng VIP, nút chuyển tầng/cầu thang, đường đi liên tầng và việc ẩn khách/nhân viên/chủ quán ở tầng khác. Kịch bản ghi `user://floor1-live.png` và `user://floor2-live.png`. `ui_smoke.gd` tiếp tục tự chơi hai đêm và kiểm tra sổ thu chi.
