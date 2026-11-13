# Thiết kế đã chốt (tóm tắt)

Đặc tả đầy đủ do chủ dự án cung cấp. Tài liệu này ghi những gì **đã được hiện thực** và các quyết định chi tiết nảy sinh khi làm. Số liệu nằm trong `data/*.json`.

## Vòng lặp một đêm

1. **Chuẩn bị (PREP)**: chỉnh giá phòng, mở phòng mới, bấm "Mở cửa đón khách".
2. **Kinh doanh (OPEN)**: 18:00–24:00. Khách đến quầy → người chơi xếp phòng → hết giờ khách thanh toán → phòng bẩn → dọn → sẵn sàng.
3. **Tổng kết (SUMMARY)**: trừ lương và chi phí vận hành, hiện báo cáo, sang đêm sau.

## Thời gian

- Mô phỏng chạy theo **từng phút game nguyên**. 1x = 2 giây/phút, 2x = 1 giây/phút, 4x = 0,5 giây/phút.
- Mọi hệ thống dùng chung một đồng hồ. Tạm dừng hoặc mở cửa sổ (menu, sổ thu chi, tổng kết) thì không phút nào trôi; đóng cửa sổ thì chạy lại đúng tốc độ cũ.
- Không sinh khách sau 23:00. Không nhận lượt kết thúc sau 24:00. Nhóm đang chờ mà không còn kịp giờ sẽ tự rời đi (không trừ danh tiếng).
- 24:00: kết thúc mọi lượt còn lại (tính tiền theo phút thực tế), khách chờ ra về, phòng được dọn kết ca, rồi mới tổng kết.

## Phòng

Trạng thái: `LOCKED → AVAILABLE → OCCUPIED → DIRTY → CLEANING → AVAILABLE` (`BROKEN` để dành).

- Không xếp khách vượt sức chứa, vào phòng bẩn/đang dọn/khóa, hoặc phòng đang có nhóm khác.
- Giá của một lượt được chốt lúc khách vào phòng. Giá chỉ chỉnh được ở giai đoạn chuẩn bị.
- Dọn phòng mất 8 phút game.

## Khách

Mười một nhóm trong `data/customers.json`, khác nhau về số người, giá mong đợi, kiên nhẫn, gu nhạc và tỉ lệ gọi Lan can:

| Nhóm | Số người | Giá mong đợi/giờ | Kiên nhẫn (phút) | Gọi Lan can |
|---|---|---|---|---|
| Bạn bè | 2–5 | 260.000đ | 18–30 | 15% |
| Sinh nhật | 4–5 | 380.000đ | 20–32 | 45% |
| Liên hoan công ty | 5 | 550.000đ | 12–22 | 50% |
| Khách quen bolero | 2–5 | 300.000đ | 22–36 | 35% |
| Hội bạn nhậu | 3–5 | 420.000đ | 10–18 | 60% |
| Hội chị em | 4–5 | 300.000đ | 18–30 | 30% |
| Cặp đôi | 2 | 240.000đ | 14–24 | 0% |
| Gia đình | 4–5 | 340.000đ | 20–34 | 0% |
| Hội Gen Z | 3–5 | 320.000đ | 12–22 | 20% |
| Hội anh em trung niên | 3–5 | 420.000đ | 10–18 | 75% |
| Hội nam trẻ trâu | 3–5 | 320.000đ | 12–22 | 65% |

Mỗi nhóm tối đa 5 khách; nhân viên giao lưu có chỗ riêng cạnh khách và không tính vào số khách. Kích thước nhân vật cố định, không thay đổi theo số người trong phòng.

- Trạng thái: `WAITING → IN_ROOM → CHECKOUT → LEAVING`, hoặc `LEFT_UNSERVED`.
- Thời lượng hát: 45/60/75/90 phút. Hàng chờ tối đa 4 nhóm; nhóm tới khi hàng đầy sẽ quay đi.
- Chỉ sinh nhóm có số người vừa với phòng lớn nhất đã mở.
- Nhịp khách tới dày hơn khi mở thêm phòng.

### Hài lòng (bắt đầu 70)

| Yếu tố | Tác động |
|---|---|
| Chờ quá 5 phút | -1 mỗi phút vượt, tối đa -20 |
| Giá phòng cao hơn giá mong đợi của nhóm | -10 |
| Giá phòng ≤ 80% giá mong đợi | +5 |
| Âm thanh trên cấp 1 | +5 mỗi cấp (chưa có nâng cấp) |

Mỗi thay đổi đều hiện lý do, ví dụ "Chờ 12 phút: -7 hài lòng".

### Danh tiếng (0–100, bắt đầu 40)

- Khi thanh toán: thay đổi = (hài lòng − 60) / 10, làm tròn, giới hạn ±3.
- Nhóm bỏ về vì chờ lâu: −1.

## Kinh tế

- Tiền là số nguyên VND, hiển thị `250.000đ`.
- Tiền phòng = giá giờ × số phút / 60, **làm tròn đến 1.000đ gần nhất (từ 500đ làm tròn lên)**.
- Tiền chỉ thay đổi qua sổ giao dịch (`EconomySystem.record`). Mỗi giao dịch có loại, số tiền, ID nguồn; cặp (loại, ID nguồn) chỉ ghi được một lần.
- Loại giao dịch hiện có: `OPENING`, `ROOM_FEE` (nguồn `group:<id>`), `UNLOCK_ROOM` (nguồn là ID phòng), `WAGES` và `OPERATING` (nguồn `day:<n>`).
- Vốn 15.000.000đ. Mỗi đêm: lương 300.000đ, vận hành 400.000đ.

## Trong lúc khách hát

Mỗi nhóm phát sinh vài nhu cầu (số lần tùy loại nhóm); mỗi phòng chỉ có một yêu cầu mở, có hạn chót.

| Yêu cầu | Người chơi làm gì | Kịp | Quá hạn |
|---|---|---|---|
| Gọi món (hạn 14') | Bấm phòng: chủ quán lấy ở quầy rồi mang tới | Món vào hóa đơn, +2 (≤5 phút: +4) | Hủy đơn, trả hàng về kho, −5 |
| Micro hỏng (10') | Bấm phòng: chủ quán tới đổi | ≤5 phút: +1 | −8 (nhóm kỹ micro: −16) và giảm 10% tiền phòng |
| Phòng nóng (12') | Chọn: tăng điều hòa (−20.000đ, +3) hoặc xin thông cảm (−4) | | −4 |
| Xin hát thêm (8') | Chọn: đồng ý (+30 phút, +4) hoặc từ chối (−1) | | Không sao |

Kho hết món khách gọi: −3 ngay. Hàng được giữ chỗ lúc khách gọi nên không bán trùng.

## Sân xe và bảo vệ

Từ đêm 2, mỗi nhóm ra về có 8% nguy cơ mất xe (có bảo vệ: 0,8%). Mất xe: đền 1.000.000đ, −3 danh tiếng, khách hết hài lòng. Bảo vệ 350.000đ/đêm.

## Mục tiêu đêm và tổng kết

Mục tiêu: phục vụ ít nhất (3 + số đêm, tối đa 10) nhóm và không quá 5 nhóm bỏ về; đạt thì +2 danh tiếng. Tổng kết gồm thu, chi (nhập hàng chỉ thống kê lại, không trừ lần hai), ba lời nhận xét của khách và ba món nâng cấp.

## Lan can

"Điểm tựa cho những giọng ca chênh vênh." Nhân viên tiếp khách trò chuyện, song ca, khuấy động không khí. Tất cả là người trưởng thành; hình vẽ theo kiểu dạ tiệc sành điệu, không có nội dung tình dục hay cưỡng ép.

- Tuyển: 1.500.000đ/người, tối đa 3 vị trí, lương 250.000–350.000đ/đêm. Tám ứng viên trong `data/hosts.json` (bảy nữ, một nam ca sĩ phòng trà), mỗi người có điểm giao tiếp, song ca và gu nhạc riêng.
- Một phần nhóm khách (tỉ lệ theo loại nhóm) sẽ gọi Lan can sau 5 phút vào phòng — chỉ khi quán đã có nhân viên và còn đủ thời gian.
- Người chơi cử một nhân viên đang rảnh vào phòng đang gọi. Mỗi phòng tối đa một người, mỗi người một phòng.
- Phiên cố định 30 phút, không tự gia hạn. Xong phiên: +hài lòng = giao tiếp + song ca (+3 nếu hợp gu nhạc), phí 200.000đ vào hóa đơn phòng.
- **Hoàn phí:** phí chỉ được ghi khi phiên hoàn tất. Khách rời phòng giữa phiên thì không thu.
- Gọi mà 20 phút không ai tới: −3 hài lòng.
- Tip ngẫu nhiên theo mức hài lòng, thuộc về nhân viên, không vào sổ của quán.
- Mỗi phiên tốn 30 năng lượng; dưới 30 thì nghỉ 20 phút rồi hồi đầy.
- Chưa làm: đào tạo, trang phục, khu nghỉ, sự kiện ranh giới (khách cư xử không phù hợp).

## Người chơi điều khiển chủ quán

- Người chơi không sửa trạng thái trực tiếp: mỗi cú bấm tạo một **việc** cho chủ quán (dẫn khách, dọn phòng, đi tới). Chủ quán đi tới nơi rồi mới gọi hành động của mô phỏng, nên quy tắc vẫn chỉ nằm trong `Simulation`.
- Hàng việc tối đa 5; dọn phòng giữ chân chủ quán cho tới khi xong (8 phút game).
- Cử Lan can và mở phòng không cần chủ quán đi tới.
- Hình ảnh đi lại chạy theo tốc độ game và dừng khi tạm dừng.

## Kiến trúc

- `Simulation` (scripts/core/simulation.gd) là cửa ngõ duy nhất: giao diện và kiểm thử đều gọi cùng các hàm (`open_doors`, `assign_group`, `clean_room`, `unlock_room`, `change_price`, `next_day`). Hàm trả về `""` khi thành công hoặc lý do bằng tiếng Việt.
- `GameState` chỉ chứa dữ liệu thuần (Dictionary/Array/số/chuỗi), tham chiếu bằng ID, sẵn sàng để lưu.
- Không dùng Autoload, không dùng `class_name`; các script nạp nhau bằng `preload`.
- Ngẫu nhiên có seed; seed hiện trong nhật ký quán khi bắt đầu.
