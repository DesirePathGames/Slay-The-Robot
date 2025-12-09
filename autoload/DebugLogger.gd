## Helper service that provides basic logging functionality
extends Node

## [timestamp, message, severity]
var logged_lines: Array[Array] = []

enum Severities {STANDARD, WARNING, ERROR}

var IGNORE_STANDARD: bool = false
var IGNORE_WARNINGS: bool = false

func log_line(message: String, color: Color = Color.WHITE, severity: int = Severities.STANDARD) -> void:
	if IGNORE_STANDARD and severity == Severities.STANDARD:
		return
	print_rich("[color=#{0}]{1}[/color]".format([color.to_html(false), message]))
	_add_log(message, Severities.STANDARD)

func log_warning(message: String):
	if not IGNORE_WARNINGS:
		push_error(message)
		print_rich("[color=#{0}]{1}[/color]".format([Color.YELLOW.to_html(false), message]))
		_add_log(message + "at\n" + str(get_stack()), Severities.WARNING)

func log_error(message: String):
	push_error(message)
	print_rich("[color=#{0}]{1}[/color]".format([Color.RED.to_html(false), message]))
	_add_log(message + "at\n" + str(get_stack()), Severities.ERROR)

func _add_log(message: String, severity: int = Severities.STANDARD) -> void:
	logged_lines.append([
		Time.get_datetime_string_from_system(),
		message,
		severity
		])

## TODO Dumps logs to file
func dump_log(log_file_path: String) -> void:
	pass
	
