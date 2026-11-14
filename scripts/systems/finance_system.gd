extends RefCounted
## Vay ngân hàng và phá sản.
## - Hạn mức vay = credit_base + credit_equipment_percent% giá trị thiết bị đã lắp (trừ hai phòng có sẵn).
## - Mỗi cuối đêm tự trả lãi (loan_rate_permille_per_night trên dư nợ) và ít nhất loan_min_principal_percent% gốc.
## - Số dư âm sau quyết toán cuối đêm là nợ quá hạn; âm liền bankrupt_after_negative_nights đêm thì phá sản.

const Money = preload("res://scripts/core/money.gd")

var _state
var _data: Dictionary
var _economy
var _notify: Callable


func _init(state, data: Dictionary, economy, notify: Callable) -> void:
	_state = state
	_data = data
	_economy = economy
	_notify = notify


func equipment_value() -> int:
	var total: int = 0
	for room in _state.rooms:
		if room["state"] != "LOCKED":
			total += room["unlock_cost"]
	return total


func credit_limit() -> int:
	var balance: Dictionary = _data["balance"]
	@warning_ignore("integer_division")
	return balance["credit_base"] + equipment_value() * balance["credit_equipment_percent"] / 100


func available_credit() -> int:
	return maxi(0, credit_limit() - _state.loan_principal)


## Số tiền phải trả ở cuối đêm tới với dư nợ hiện tại: {"interest", "principal", "total"}.
func next_payment() -> Dictionary:
	var balance: Dictionary = _data["balance"]
	@warning_ignore("integer_division")
	var interest: int = Money.round_to_thousand(_state.loan_principal * balance["loan_rate_permille_per_night"] / 1000)
	@warning_ignore("integer_division")
	var principal: int = mini(_state.loan_principal, Money.round_to_thousand(_state.loan_principal * balance["loan_min_principal_percent"] / 100))
	return {"interest": interest, "principal": principal, "total": interest + principal}


func take_loan(amount: int) -> String:
	if _state.bankrupt:
		return "Quán đã phá sản."
	if _state.phase == "OPEN":
		return "Chỉ vay được trước giờ mở cửa hoặc sau khi tổng kết."
	if amount <= 0:
		return "Số tiền vay không hợp lệ."
	if amount > available_credit():
		return "Vượt hạn mức: ngân hàng chỉ cho vay thêm tối đa %s." % Money.format(available_credit())
	_state.loan_counter += 1
	_economy.record("LOAN", amount, "loan:%d" % _state.loan_counter, "Vay ngân hàng")
	_state.loan_principal += amount
	var due: Dictionary = next_payment()
	_notify.call("Vay %s. Dư nợ %s; cuối đêm tự trả %s (lãi %s + gốc %s)." % [Money.format(amount), Money.format(_state.loan_principal), Money.format(due["total"]), Money.format(due["interest"]), Money.format(due["principal"])], "info")
	return ""


func repay(amount: int) -> String:
	if _state.phase == "OPEN":
		return "Chỉ trả nợ được trước giờ mở cửa hoặc sau khi tổng kết."
	if _state.loan_principal <= 0:
		return "Quán không còn nợ."
	amount = mini(amount, _state.loan_principal)
	if amount <= 0 or not _economy.can_afford(amount):
		return "Không đủ tiền để trả %s." % Money.format(amount)
	_state.loan_counter += 1
	_economy.record("LOAN_REPAY", -amount, "repay:%d" % _state.loan_counter, "Trả nợ gốc")
	_state.loan_principal -= amount
	_notify.call("Đã trả %s tiền gốc. Dư nợ còn %s." % [Money.format(amount), Money.format(_state.loan_principal)], "good")
	return ""


## Gọi khi quyết toán cuối đêm, sau lương và chi phí. Trả về {"interest", "principal"} đã trả.
func settle_night(day: int) -> Dictionary:
	var paid: Dictionary = {"interest": 0, "principal": 0}
	if _state.loan_principal > 0:
		var due: Dictionary = next_payment()
		_economy.record("LOAN_INTEREST", -due["interest"], "interest:%d" % day, "Lãi vay ngân hàng")
		_economy.record("LOAN_REPAY", -due["principal"], "installment:%d" % day, "Trả góp nợ gốc")
		_state.loan_principal -= due["principal"]
		paid = due
	return paid


## Kiểm tra sau quyết toán: âm tiền thì cảnh báo, âm liền nhiều đêm thì phá sản. Trả về true nếu vừa phá sản.
func check_solvency() -> bool:
	if _state.money >= 0:
		_state.negative_nights = 0
		return false
	_state.negative_nights += 1
	var limit: int = _data["balance"]["bankrupt_after_negative_nights"]
	if _state.negative_nights >= limit:
		_state.bankrupt = true
		_notify.call("PHÁ SẢN: số dư âm %d đêm liền, ngân hàng thu hồi quán." % limit, "bad")
		return true
	_notify.call("CẢNH BÁO: số dư đang âm %s. Nếu hết đêm mai vẫn âm, quán sẽ phá sản. Có thể vay thêm hoặc cắt chi phí." % Money.format(-_state.money), "bad")
	return false
