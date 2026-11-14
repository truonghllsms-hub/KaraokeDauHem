# Tích hợp giao diện cho các tính năng nội dung

> **Trạng thái (nhánh `claude/integrate-content`):** đã nối lên giao diện hai tầng: nhãn "Chưa lắp thiết bị" và nút
> "Lắp thiết bị — …đ", lý do xếp phòng kèm giá dự kiến, huy hiệu điểm sao dưới thanh trên cùng (bấm xem nhận xét),
> câu hát ♪ và thoại trên đầu nhân vật, nhân viên phục vụ đi lại, tuyển ở Nhân sự → Phục vụ, tổng kết có điểm sao,
> tự lưu cuối đêm và nút Tiếp tục. Kiểm tra bằng `tests/ui_content.gd`. Biểu tượng ★ của danh tiếng trong thanh trên
> cùng vẫn giữ vì kiểm thử khớp tranh đã duyệt yêu cầu giữ nguyên điểm ảnh; huy hiệu sao luôn ghi "/5".

Nhánh nội dung chỉ sửa `data/`, `scripts/core/`, `scripts/systems/`, `tests/` và tài liệu. Mọi tính năng
dưới đây đã chạy trong mô phỏng và có kiểm thử; phần giao diện còn chờ nối. Các hàm và trường cũ vẫn giữ
nguyên, nên giao diện hiện tại vẫn chạy (đã kiểm tra bằng `ui_smoke`, `ui_redesign`, `ui_reference`).

Quy ước chung: hàm hành động trả về `""` khi thành công, ngược lại là lý do bằng tiếng Việt để hiện cho người chơi.

## 1. Phòng chưa lắp thiết bị và phòng VIP

Cả 6 phòng đã xây sẵn. Trạng thái `"LOCKED"` giờ nghĩa là **chưa lắp thiết bị** (giữ tên cũ để tương thích).
Phòng 01–04 là phòng thường, 05–06 là VIP (`room["tier"] == "vip"`).

| API | Dùng để |
|---|---|
| `sim.room_info(room_id) -> Dictionary` | Mọi thứ bảng Chi tiết cần: `tier_name`, `capacity`, `price_per_hour`, `equipped`, `status_text` ("Sẵn sàng" / "Chưa lắp thiết bị"), `equipment` (danh sách thiết bị sẽ lắp), `perks` (lợi ích), `equip_cost`, `missing_money`, `can_equip_now`, `equip_button_text` ("Lắp thiết bị — 12.000.000đ"), `upkeep_per_night`, `sound`, `soundproof` |
| `sim.equip_room(room_id) -> String` | Lắp thiết bị. Chỉ ở giai đoạn chuẩn bị; thiếu tiền thì lý do có số tiền còn thiếu. `unlock_room` là tên cũ, vẫn gọi được |

Việc giao diện cần làm:
- Thay "[KHÓA]", "CHƯA MỞ", nút "Mở phòng" bằng `room_info()["status_text"]` và `equip_button_text`.
- Phòng chưa lắp: vẽ phòng trống (không sofa, tivi); lắp xong mới vẽ nội thất. VIP vẽ nội thất cao cấp.
- Trong bảng Chi tiết: hiện `equipment`, `perks`, `equip_cost`, `upkeep_per_night`; nếu `missing_money > 0` thì ghi "Còn thiếu …".
- Ẩn hoặc khóa nút lắp khi `sim.state.phase != "PREP"` (hàm cũng tự từ chối).
- Sổ thu chi đã tự ghi "Lắp thiết bị phòng: …" (loại giao dịch `EQUIP_ROOM`).

## 2. Lý do không xếp được phòng

`sim.preview_assign(group_id, room_id)` có thêm hai trường (các trường cũ giữ nguyên):
- `block`: `""` | `"STATE"` | `"CAPACITY"` | `"TIME"` | `"PRICE"`
- `block_text`: nhãn ngắn, ví dụ "Chưa lắp thiết bị", "Thiếu chỗ: chỉ chứa 6 người", "Khách chê đắt: 350.000đ/giờ"

Khách mới chê giá khi giá vượt ngân sách quá 35%; phòng VIP được nới thêm 30%.
`preview_assign()["budget_per_hour"]` là ngân sách đã tính phần nới đó.

**Lỗi hiện tại cần sửa:** `venue_view.gd` (khoảng dòng 650) gán "Không kịp trước 24:00" cho mọi lý do không phải
trạng thái hay sức chứa, nên phòng bị chê giá sẽ hiện sai. Dùng `preview["block_text"]` thay cho đoạn đó.

## 3. Đánh giá sao (1–5)

Khác với danh tiếng (0–100, mức độ được biết đến). Mỗi nhóm đã thanh toán để lại đúng một đánh giá.

| API | Trả về |
|---|---|
| `sim.rating_text()` | "★ 4,3/5 · 28 đánh giá" hoặc "Chưa có đánh giá" — đặt trên thanh trên cùng |
| `sim.rating_x10()` | Điểm × 10 (43 = 4,3 sao); 0 khi chưa có |
| `sim.recent_reviews(limit)` | Nhận xét mới nhất trước: `{day, who, room_name, stars, satisfaction, text}` — cho bảng mở ra khi bấm vào điểm sao |
| `bill["stars"]` | Số sao của nhóm vừa thanh toán (tín hiệu `bill_paid`) |
| Bảng tổng kết | `night_reviews`, `night_rating_text`, `rating_before_x10`, `rating_after_x10`, `rating_text`; mỗi phần tử `comments` có thêm `stars` |

**Lưu ý:** thanh trên cùng đang hiện danh tiếng là "★ 40/100". Nên đổi ký hiệu của danh tiếng (ví dụ "Danh tiếng 40")
để ★ chỉ dùng cho đánh giá sao. Mở lại bảng tổng kết thì đọc `sim.last_summary()`; không được ghi đánh giá lần nữa.

## 4. Câu hát và thoại trong phòng

Tín hiệu `sim.line_spoken(event)` phát mỗi khi có câu mới (khoảng 15–25 phút game mỗi phòng). Các trường chính:

| Trường | Ý nghĩa |
|---|---|
| `kind` | `SONG` (câu hát, đã có ♪ ở hai đầu) · `BANTER` (đối đáp) · `REACTION` (phản ứng sự cố) · `LANCAN` (câu riêng của nhân viên) |
| `room_id`, `group_id` | Phòng và nhóm |
| `text`, `speaker_index` | Câu nói và người nói: vị trí trong nhóm (0..2, trùng thứ tự hình của nhóm); `-1` là nhân viên Lan can (`host_id`) |
| `reply_text`, `reply_speaker_index`, `reply_host_id` | Câu đáp hoặc câu hát nối (rỗng nếu không có) |
| `song_title`, `mood`, `speaker_age` | Tên bài, sắc thái, lứa tuổi người hát |

Việc giao diện cần làm:
- Hiện bong bóng trên đầu đúng nhân vật trong **3–5 giây thực**, tính bằng đồng hồ thực và dừng khi tạm dừng (`sim.clock.is_running()`).
- Có `reply_text` thì hiện câu đáp sau câu đầu khoảng 1,5 giây.
- Câu hát (`SONG`) kèm nốt nhạc hoặc động tác hát; câu trò chuyện dùng bong bóng thường.
- Bong bóng cảnh báo (gọi món, micro hỏng, gọi Lan can) luôn nằm trên và che câu trang trí.
- Hoặc gọi `sim.ambience.current_line(room_id, now)` mỗi khung hình thay cho việc nghe tín hiệu.

Thoại trang trí không đổi hài lòng, tiền hay bản lưu, và dùng bộ ngẫu nhiên riêng nên không làm lệch diễn biến.

## 5. Nhân viên phục vụ

`sim.state.staff`: `{id, name, speed, wage, about, energy, tasks_done, task}`. `task` rỗng là đang rảnh, ngược lại
`{kind: CLEAN|DELIVER|FIX|REST, room_id, phase: TRAVEL|WORK, start, end}`.

| API | Dùng để |
|---|---|
| `sim.hire_staff(staff_id)` | Tuyển (phí 800.000đ, tối đa 3 người) |
| `sim.staff.candidates()` | Ứng viên chưa tuyển (cho cửa sổ Nhân sự) |
| `sim.prioritize_job(room_id)` | Người chơi chỉ định phòng cần lo trước |

Gợi ý hiển thị: vẽ nhân viên đi từ quầy tới `task.room_id` trong khoảng `start`…`end` phút game; thanh năng lượng; nhãn "Đang nghỉ".

## 6. Khách quen

Nhóm khách quen có `group["regular_id"] != ""`, `regular_name`, `favorite_room_id`, `favorite_product_id`;
`type_name` đã có hậu tố "(khách quen)" và `trait` ghi phòng quen, món quen. Danh sách ở `sim.state.regulars`;
`sim.regulars.describe(regular)` cho câu mô tả ngắn. Gợi ý: biểu tượng tim trên nhóm; viền phòng quen khi đang chọn nhóm.

## 7. Lưu và tải

| API | Dùng để |
|---|---|
| `sim.autosave_path = SaveManager.DEFAULT_PATH` | Bật tự lưu sau mỗi tổng kết đêm |
| `sim.save_game()` | Lưu tay (chỉ ở giai đoạn chuẩn bị hoặc sau tổng kết) |
| `SaveManager.has_save()` | Bật nút "Tiếp tục" ở màn hình chính |
| `Simulation.create_from_save(data)` | `{ok, sim, error, used_backup, notice}`: `ok` sai thì hiện `error`; `notice` khác rỗng thì báo đã dùng bản sao lưu |
| Tín hiệu `game_saved(path, error)` | Hiện "Đã lưu lúc …" hoặc lỗi |

Chơi mới khi đã có bản lưu: hỏi xác nhận trước khi ghi đè. Không tự xóa tệp lưu hỏng.
