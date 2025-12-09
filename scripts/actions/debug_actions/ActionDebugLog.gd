## Logs a message to console
extends BaseAction

func perform_action():
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action([null])
	
	for action_interceptor_processor in action_interceptor_processors:
		var log_message: String = action_interceptor_processor.get_shadowed_action_values("log_message", "")
		var log_message_color_html: String = action_interceptor_processor.get_shadowed_action_values("log_message_color_html", Color.WHITE.to_html(true))
		var log_color: Color = Color(log_message_color_html, false)
		var log_severity: int = action_interceptor_processor.get_shadowed_action_values("log_severity", DebugLogger.Severities.STANDARD)
		DebugLogger.log_line(log_message, log_color, log_severity)

func is_instant_action() -> bool:
	return true
