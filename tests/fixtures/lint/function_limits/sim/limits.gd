extends RefCounted
## Function limits fixture: 40 lines and complexity 12 pass, 41 and 13 fail.

func forty_lines() -> int:
	var total: int = 0
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	return total


func forty_one_lines() -> int:  # PLANT FUNC-LINES
	var total: int = 0
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	total += 1
	return total


func complexity_twelve() -> int:
	var total: int = 0
	# if and or elif while in a comment do not count
	var note: String = "if x and y or z"
	if total > 0:
		total += 1
	if total > 1:
		total += 1
	if total > 2:
		total += 1
	if total > 3:
		total += 1
	if total > 4:
		total += 1
	if total > 5:
		total += 1
	if total > 6:
		total += 1
	if total > 7:
		total += 1
	if total > 8:
		total += 1
	if total > 9:
		total += 1
	if total > 10:
		total += 1
	return total


func complexity_thirteen() -> int:  # PLANT FUNC-COMPLEXITY
	var total: int = 0
	# if and or elif while in a comment do not count
	var note: String = "if x and y or z"
	if total > 0:
		total += 1
	if total > 1:
		total += 1
	if total > 2:
		total += 1
	if total > 3:
		total += 1
	if total > 4:
		total += 1
	if total > 5:
		total += 1
	if total > 6:
		total += 1
	if total > 7:
		total += 1
	if total > 8:
		total += 1
	if total > 9:
		total += 1
	if total > 10:
		total += 1
	if total > 11:
		total += 1
	return total


func mixed_fourteen() -> int:  # PLANT FUNC-COMPLEXITY
	var total: int = 0
	for i: int in 3:
		while total < i and total >= 0 or total == 9:
			total += 1
	match total:
		0:
			total = 1
		1, 2:
			total = 2
		3:
			total = 3
		_:
			total = 4
	var x: int = 1 if total > 0 else 2
	if total > 1 && total < 5 || total == 7:
		total += 1
	elif total == 8:
		total -= 1
	return total + x
