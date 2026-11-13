extends RefCounted
## Đồng hồ mô phỏng dùng chung. Mọi hệ thống chạy theo từng phút game nguyên,
## nên tạm dừng và đổi tốc độ không thể làm các bộ đếm lệch nhau.

const OPEN_HOUR: int = 18
const NIGHT_MINUTES: int = 360
## Số giây thực cho một phút game ở từng tốc độ.
const SECONDS_PER_MINUTE: Dictionary = {1: 2.0, 2: 1.0, 4: 0.5}
## Giới hạn số phút xử lý trong một khung hình để không bị dồn khi máy giật.
const MAX_STEPS_PER_ADVANCE: int = 8

var minute: int = 0
var speed: int = 1
var paused: bool = false

var _accum: float = 0.0
var _modal_locks: int = 0


func reset() -> void:
	minute = 0
	paused = false
	_accum = 0.0
	_modal_locks = 0


func set_speed(new_speed: int) -> void:
	if SECONDS_PER_MINUTE.has(new_speed):
		speed = new_speed


func toggle_pause() -> void:
	paused = not paused


## Cửa sổ sự kiện/menu gọi push_modal khi mở và pop_modal khi đóng.
## Tốc độ và trạng thái tạm dừng của người chơi được giữ nguyên.
func push_modal() -> void:
	_modal_locks += 1


func pop_modal() -> void:
	_modal_locks = maxi(0, _modal_locks - 1)


func is_running() -> bool:
	return not paused and _modal_locks == 0


## Nhận thời gian thực, trả về số phút game cần mô phỏng.
func advance(real_seconds: float) -> int:
	if not is_running():
		return 0
	var per_minute: float = SECONDS_PER_MINUTE[speed]
	_accum += real_seconds
	var steps: int = int(floor(_accum / per_minute))
	if steps > MAX_STEPS_PER_ADVANCE:
		steps = MAX_STEPS_PER_ADVANCE
		_accum = 0.0
	else:
		_accum -= steps * per_minute
	return steps


static func time_text(at_minute: int) -> String:
	@warning_ignore("integer_division")
	var hour: int = OPEN_HOUR + at_minute / 60
	return "%02d:%02d" % [hour, at_minute % 60]
