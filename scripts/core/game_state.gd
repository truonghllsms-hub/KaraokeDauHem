extends RefCounted
## Trạng thái phiên chơi. Chỉ chứa dữ liệu thuần (số, chuỗi, Array, Dictionary)
## để sau này tuần tự hóa thành save. Không lưu Node ở đây.

const SCHEMA_VERSION: int = 1

## Giai đoạn trong ngày: PREP (chuẩn bị), OPEN (kinh doanh), SUMMARY (tổng kết).
var phase: String = "PREP"
var day: int = 1
var money: int = 0
var reputation: int = 40

var floor2_unlocked: bool = false

var rooms: Array = []
## Các nhóm khách đang có mặt (WAITING hoặc IN_ROOM).
var groups: Array = []
## Nhân viên Lan can đã tuyển.
var hosts: Array = []
var next_group_id: int = 1
var next_arrival_minute: int = 0

## Sổ giao dịch. Tiền chỉ thay đổi qua EconomySystem.record().
var ledger: Array = []
var ledger_keys: Dictionary = {}

## Thống kê của đêm hiện tại và kết quả các đêm trước.
var night: Dictionary = {}
var history: Array = []

## Kho hàng {id: số lượng}, nâng cấp {id: cấp}, bảo vệ sân xe.
var stock: Dictionary = {}
var upgrades: Dictionary = {}
var guard_hired: bool = false
var next_request_id: int = 1
var purchase_counter: int = 0
var last_bill: Dictionary = {}

var messages: Array = []
var rng_seed: int = 0
