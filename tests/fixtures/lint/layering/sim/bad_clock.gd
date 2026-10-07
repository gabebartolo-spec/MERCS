extends RefCounted
# One planted violation per line, marked PLANT <RULE>. Gate item: clock in sim.

var time_left: int = 0


func started_at() -> int:
	return Time.get_ticks_msec()  # PLANT SIM-CLOCK


func wall_clock() -> int:
	return int(Time.get_unix_time_from_system())  # PLANT SIM-CLOCK


func os_micros() -> int:
	return OS.get_ticks_usec()  # PLANT SIM-CLOCK


func os_unix() -> int:
	return int(OS.get_unix_time())  # PLANT SIM-CLOCK


func os_system() -> int:
	return OS.get_system_time_msecs()  # PLANT SIM-CLOCK


func after_hash_string() -> String:
	return "item#1" + str(Time.get_ticks_msec())  # PLANT SIM-CLOCK
