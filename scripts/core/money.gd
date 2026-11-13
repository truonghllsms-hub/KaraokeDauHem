extends RefCounted
## Tiện ích tiền tệ. Mọi số tiền là số nguyên VND.


## Quy tắc làm tròn duy nhất của game: đến 1.000đ gần nhất, từ 500đ trở lên thì làm tròn lên.
static func round_to_thousand(amount: int) -> int:
	@warning_ignore("integer_division")
	return ((amount + 500) / 1000) * 1000


## Tiền phòng tính theo số phút sử dụng thực tế.
static func room_fee(price_per_hour: int, minutes: int) -> int:
	if minutes <= 0:
		return 0
	@warning_ignore("integer_division")
	return round_to_thousand(price_per_hour * minutes / 60)


## Hiển thị dạng 250.000đ.
static func format(amount: int) -> String:
	var digits: String = str(absi(amount))
	var out: String = ""
	while digits.length() > 3:
		out = "." + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	out = digits + out
	if amount < 0:
		out = "-" + out
	return out + "đ"
