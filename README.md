# KARAOKE ĐẦU HẺM

Game quản lý quán karaoke đầu hẻm ở Việt Nam. Chơi đơn, offline, 2D nhìn từ trên xuống, giao diện tiếng Việt.

Trạng thái: **bản dựng sớm, chơi được trọn nhiều đêm**. Xem `docs/TASKS.md`.

![Màn hình kinh doanh](docs/screenshots/04_dang_hat.png)

## Yêu cầu

- Godot **4.5.1 stable** (bản thường, không cần .NET). Renderer Compatibility, thiết kế 1280 × 720.

## Cách chạy

1. Mở Godot → **Import** → chọn `project.godot` → bấm **F5**.

Bản chạy trên trình duyệt (cần export templates 4.5.1; preset "Web" có sẵn):

```bash
godot --headless --path . --export-release "Web" build/web/index.html
```

```bash
python3 -m http.server 8060 --directory build/web
```

Đẩy bản web lên Vercel: `python3 tools/deploy_vercel.py` (cần biến `VERCEL_TOKEN`).

## Điều khiển

| Thao tác | Cách làm |
|---|---|
| Tạm dừng / tốc độ / menu | `Space` · `1` `2` `3` · `Esc` |
| Xếp phòng | Bấm nhóm khách ở chỗ chờ → bấm phòng **viền xanh** (trên phòng có tiền dự kiến và cảnh báo vượt ngân sách) |
| Giao món, đổi micro | Bấm phòng có nhãn vàng (gọi món) hoặc đỏ (micro hỏng): chủ quán đi làm |
| Phòng nóng, xin hát thêm | Bấm phòng có nhãn cam/xanh: hiện lựa chọn |
| Dọn phòng | Bấm phòng bẩn |
| Lan can | Nút "Lan can" để tuyển; khi khách gọi: bấm nhân viên → bấm phòng |
| Kho hàng, Bảo vệ, Nâng cấp | Các nút ở thanh dưới |
| Mở phòng mới, chỉnh giá | Bấm phòng → bảng Chi tiết (chỉnh giá chỉ trước giờ mở cửa) |

Chủ quán làm từng việc một (tối đa 5 việc chờ) — chọn việc nào trước là phần chơi chính.

## Tính năng hiện có

- Sáu phòng hát (mở sẵn 2), sảnh lễ tân, góc Lan can, sân có bãi xe, chỗ chờ và chốt bảo vệ.
- Chín nhóm khách có đặc điểm ảnh hưởng thật (số lần gọi món, hay xin hát thêm, kỹ micro, ngân sách).
- Trong lúc khách hát: gọi món (6 mặt hàng, có tồn kho), micro trục trặc, phòng nóng, xin hát thêm 30 phút.
- Hóa đơn minh bạch: tiền phòng theo phút, từng món, phí Lan can, giảm giá xin lỗi; làm tròn 1.000đ.
- Mất xe từ đêm 2 nếu không thuê bảo vệ: đền tiền và mất danh tiếng.
- Lan can: 8 nhân viên giao lưu âm nhạc, tuyển tối đa 3.
- Mỗi đêm có mục tiêu; tổng kết có thu chi, lời nhận xét của khách và ba món đầu tư.
- Ba nâng cấp: dàn loa, micro dự phòng, xe đẩy phục vụ.

## Hạn chế hiện tại

- Chưa có: lưu/tải, âm thanh, nhân viên phục vụ, giá giờ cao điểm và combo, sự kiện theo mùa, mục tiêu 7 đêm, phá sản.
- Hình là SVG sinh bằng mã (`tools/make_sprites.py`); hoạt ảnh mới là nhún nhảy và lật hướng.
- Cân bằng mới ở mức sơ bộ.

## Cấu trúc

```
data/            Dữ liệu cân bằng (JSON)
scripts/core/    Trạng thái, đồng hồ, bộ điều phối mô phỏng
scripts/systems/ Phòng, khách, kinh tế, Lan can, phục vụ (gọi món/sự cố)
scripts/ui/      Màn mặt bằng, nhân vật, bảng điều khiển
assets/sprites/  Hình SVG nguyên bản
tests/           Kiểm thử headless và kịch bản tự chơi qua giao diện
docs/            Thiết kế, công việc, kiểm thử
```
