extends RefCounted
## Nơi duy nhất được phép thay đổi tiền. Mỗi giao dịch có loại, số tiền và ID nguồn;
## cặp (loại, ID nguồn) chỉ được ghi một lần để chống thu/chi trùng.

var _state
var _clock


func _init(state, clock) -> void:
	_state = state
	_clock = clock


func can_afford(amount: int) -> bool:
	return _state.money >= amount


## amount dương là thu, âm là chi. Trả về false nếu giao dịch đã được ghi trước đó.
func record(type: String, amount: int, source_id: String, note: String = "") -> bool:
	var key: String = type + "|" + source_id
	if _state.ledger_keys.has(key):
		return false
	_state.ledger_keys[key] = true
	_state.money += amount
	_state.ledger.append({
		"day": _state.day,
		"minute": _clock.minute,
		"type": type,
		"amount": amount,
		"source_id": source_id,
		"note": note,
		"balance_after": _state.money,
	})
	return true


## Tổng các giao dịch thuộc một loại trong một ngày.
func total_for_day(day: int, type: String) -> int:
	var total: int = 0
	for entry in _state.ledger:
		if entry["day"] == day and entry["type"] == type:
			total += entry["amount"]
	return total


## Đối soát: tổng sổ giao dịch phải bằng số dư.
func ledger_matches_balance() -> bool:
	var total: int = 0
	for entry in _state.ledger:
		total += entry["amount"]
	return total == _state.money
