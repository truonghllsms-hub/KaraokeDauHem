# Nguồn và giấy phép tài sản

| Tài sản | Nguồn | Giấy phép |
|---|---|---|
| `assets/fonts/DejaVuSans.ttf`, `DejaVuSans-Bold.ttf` | DejaVu Fonts — https://dejavu-fonts.github.io | Giấy phép DejaVu Fonts (dựa trên Bitstream Vera, cho phép dùng và phân phối tự do) |

| `assets/sprites/*.svg` | Hình nguyên bản của dự án, sinh bằng `tools/make_sprites.py` | Thuộc dự án |

Chưa có âm thanh, nhạc hay hình ảnh bên ngoài. Hình nhân vật và đồ vật là thiết kế riêng, không lấy từ game hay nguồn nào khác.

Còn thiếu: âm thanh giao diện, tiếng khách đến, tiếng thanh toán, nhạc nền, tranh vẽ tay thay cho bộ SVG, hoạt ảnh đi bộ nhiều khung hình.

## Giao diện nhìn từ trên xuống

- `assets/topdown/room_painted.webp` và `lobby_painted.webp`: minh họa gốc tạo bằng OpenAI ImageGen cho dự án, chuyển sang WebP để giảm dung lượng bản web. Không chứa chữ giao diện hoặc nhân vật; trạng thái phòng do Godot hiển thị.
- Các SVG trong `assets/topdown/`: hình vector gốc cho bãi xe, xe máy, ghế nhựa, bảo vệ ngồi và biểu tượng điều hướng. `tools/make_topdown_assets.py` tạo các hình trang trí cơ bản; hai ảnh minh họa và `guard_seated.svg` được giữ riêng.
