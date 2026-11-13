# Nguồn và giấy phép tài sản

| Tài sản | Nguồn | Giấy phép |
|---|---|---|
| `assets/fonts/DejaVuSans.ttf`, `DejaVuSans-Bold.ttf` | DejaVu Fonts — https://dejavu-fonts.github.io | Giấy phép DejaVu Fonts (dựa trên Bitstream Vera, cho phép dùng và phân phối tự do) |

| `assets/sprites/*.svg` | Hình nguyên bản của dự án, sinh bằng `tools/make_sprites.py` | Thuộc dự án |

Chưa có âm thanh hoặc nhạc bên ngoài. Hình nhân vật và đồ vật là thiết kế riêng, không lấy từ game hay nguồn nào khác.

Còn thiếu: âm thanh giao diện, tiếng khách đến, tiếng thanh toán, nhạc nền.

## Giao diện nhìn từ trên xuống

- `assets/topdown/room_painted.webp` và `lobby_painted.webp`: minh họa gốc tạo bằng OpenAI ImageGen cho dự án, chuyển sang WebP để giảm dung lượng bản web. Không chứa chữ giao diện hoặc nhân vật; trạng thái phòng do Godot hiển thị.
- Các SVG trong `assets/topdown/`: hình vector gốc cho bãi xe, xe máy, ghế nhựa, bảo vệ ngồi và biểu tượng điều hướng. `tools/make_topdown_assets.py` tạo các hình trang trí cơ bản; hai ảnh minh họa và `guard_seated.svg` được giữ riêng.

## Mẫu giao diện đã duyệt

- `assets/reference/approved_ui.png`: ảnh giao diện gốc đã được chủ dự án chọn và chỉnh trong cuộc trò chuyện. Game dùng ảnh này làm atlas cho các thành phần hiển thị, với vùng bấm, trạng thái và số liệu do Godot quản lý.
- `assets/fonts/Baloo2.ttf`: Baloo 2 (Google Fonts), giấy phép SIL Open Font License trong `Baloo2-OFL.txt`. Giao diện dùng biến thể đậm cho chữ và số động.

## Nhân vật theo mẫu A

- `assets/characters/*.webp`: minh họa gốc tạo bằng OpenAI ImageGen cho dự án từ các bảng nhân vật đã duyệt, lưu WebP không mất dữ liệu với nền trong suốt. Gồm chủ quán, hai phục vụ, bảo vệ, 11 nhân viên giao lưu trưởng thành và 24 kiểu khách. Các mẫu mới gồm ba nhân viên nam 27–35 tuổi cởi trần sáu múi, ba khách nam trung niên và ba khách nam trẻ 22–27 tuổi.
- Chín atlas chứa 78 vùng ảnh: đứng, ngồi hát, chủ quán nhìn bốn hướng và dọn phòng. `scripts/ui/character_art.gd` xác định vùng cắt và tái sử dụng cùng diện mạo trong cảnh chơi và thẻ tuyển dụng.
- Hai ảnh phục vụ được chuẩn bị cho hệ thống nhân viên sau này; không thêm cơ chế phục vụ tự động.

## Hoạt ảnh và biểu cảm

- `assets/characters/motion/*.webp`: minh họa gốc tạo bằng OpenAI ImageGen từ bộ nhân vật đã duyệt, lưu WebP không mất dữ liệu, nền trong suốt. Có 156 khung bước đi (chủ quán bốn hướng, 11 nhân viên giao lưu và 24 kiểu khách) cùng 105 hình biểu cảm.
- `scripts/ui/character_motion.gd` quản lý các khung; `tools/index_character_motion.py` chỉ phân tích alpha để tìm toàn bộ nhân vật, không thay đổi điểm ảnh. Công cụ cần Pillow, NumPy và SciPy khi lập lại chỉ mục, game không cần các thư viện này.
- Bước đi theo quãng đường di chuyển; tạm dừng cũng dừng hoạt ảnh. Các khung cùng hàng giữ chung kích thước và mốc chân. Biểu cảm gắn với kiên nhẫn, mức hài lòng, hát và nghỉ trong trạng thái mô phỏng hiện có.
- Godot nhập atlas nhân vật với chất lượng nén 80% để giảm dung lượng tải web; các ảnh WebP gốc trong kho mã vẫn giữ nguyên.
