## Logs a message to console
extends BaseAction

func perform_action():
	DebugLogger.log_line("Mod loading successful. ActionDebugLog.gd script was overwritten")

func is_instant_action() -> bool:
	return true
