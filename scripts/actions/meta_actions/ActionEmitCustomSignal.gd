## Takes a CustomSignal defined by custom_signal_object_id and emits it with a given custom_signal_value value
## Typically you'll combine this with an action modifier such as ActionVariableCardsetModifier or
## ActionVariableCostModifier etc
## modifying the "custom_signal_value" action value.
extends BaseAction

func perform_action():
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	
	for action_interceptor_processor in action_interceptor_processors:
		var custom_signal_object_id: String = action_interceptor_processor.get_shadowed_action_values("custom_signal_object_id", "")
		if custom_signal_object_id == "":
			DebugLogger.log_error("No signal object id defined")
		else:
			# get the intercepted action value you'd like to attach to the signal
			var custom_signal_value: int = action_interceptor_processor.get_shadowed_action_values("custom_signal_value", 0)
			var custom_signal_values: Dictionary[String, Variant] = {
				"value_amount": custom_signal_value
			}
			Signals.emit_custom_signal(custom_signal_object_id, custom_signal_values)

func _to_string():
	return "Emit Custom Signal Action"
