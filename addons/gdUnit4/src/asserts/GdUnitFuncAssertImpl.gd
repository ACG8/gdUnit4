class_name GdUnitFuncAssertImpl
extends GdUnitFuncAssert

signal value_provided(value)

const DEFAULT_TIMEOUT := 2000

var _current_value_provider :ValueProvider
var _current_error_message :String = ""
var _custom_failure_message :String = ""
var _line_number := -1
var _expect_fail := false
var _is_failed := false
var _timeout := DEFAULT_TIMEOUT
var _expect_result :int
var _interrupted := false


func _init(instance :Object, func_name :String, args := Array(), expect_result := EXPECT_SUCCESS):
	_line_number = GdUnitAssertImpl._get_line_number()
	_expect_result = expect_result
	GdAssertReports.reset_last_error_line_number()
	# we expect the test will fail
	if expect_result == EXPECT_FAIL:
		_expect_fail = true
	# verify at first the function name exists
	if not instance.has_method(func_name):
		report_error("The function '%s' do not exists checked instance '%s'." % [func_name, instance])
	else:
		_current_value_provider = CallBackValueProvider.new(instance, func_name, args)


func report_success() -> GdUnitAssert:
	return GdAssertReports.report_success(self)


func report_error(error_message :String) -> GdUnitAssert:
	if _custom_failure_message == "":
		return GdAssertReports.report_error(error_message, self, _line_number)
	return GdAssertReports.report_error(_custom_failure_message, self, _line_number)


func send_report(report :GdUnitReport)-> void:
	GdUnitSignals.instance().gdunit_report.emit(report)


# -------- Base Assert wrapping ------------------------------------------------
func has_failure_message(expected: String) -> GdUnitFuncAssert:
	var current_error := GdUnitAssertImpl._normalize_bbcode(_current_error_message)
	if current_error != expected:
		_expect_fail = false
		var diffs := GdDiffTool.string_diff(current_error, expected)
		var current := GdAssertMessages._colored_array_div(diffs[1])
		_custom_failure_message = ""
		report_error(GdAssertMessages.error_not_same_error(current, expected))
	return self


func starts_with_failure_message(expected: String) -> GdUnitFuncAssert:
	var current_error := GdUnitAssertImpl._normalize_bbcode(_current_error_message)
	if not current_error.begins_with(expected):
		_expect_fail = false
		var diffs := GdDiffTool.string_diff(current_error, expected)
		var current := GdAssertMessages._colored_array_div(diffs[1])
		_custom_failure_message = ""
		report_error(GdAssertMessages.error_not_same_error(current, expected))
	return self


func override_failure_message(message :String) -> GdUnitFuncAssert:
	_custom_failure_message = message
	return self


func wait_until(timeout := 2000) -> GdUnitFuncAssert:
	if timeout <= 0:
		push_warning("Invalid timeout param, alloed timeouts must be grater than 0. Use default timeout instead")
		_timeout = DEFAULT_TIMEOUT
	else:
		_timeout = timeout
	return self


func is_null() -> GdUnitFuncAssert:
	return await _validate_callback(func is_null(c, _e): return c == null)


func is_not_null() -> GdUnitFuncAssert:
	return await _validate_callback(func is_not_null(c, _e): return c != null)


func is_false() -> GdUnitFuncAssert:
	return await _validate_callback(func is_false(c, _e): return c == false)


func is_true() -> GdUnitFuncAssert:
	return await _validate_callback(func is_true(c, _e): return c == true)


func is_equal(expected) -> GdUnitFuncAssert:
	return await _validate_callback(func is_equal(c, e): return GdObjects.equals(c, e), expected)


func is_not_equal(expected) -> GdUnitFuncAssert:
	return await _validate_callback(func is_not_equal(c, e): return not GdObjects.equals(c, e), expected)


func _validate_callback(predicate :Callable, expected = null) -> GdUnitFuncAssert:
	# if initial failed?
	if _is_failed:
		#await Engine.get_main_loop().process_frame
		return self
	var time_scale = Engine.get_time_scale()
	var timer := Timer.new()
	timer.set_name("gdunit_interrupt_timer_%d" % timer.get_instance_id())
	Engine.get_main_loop().root.add_child(timer)
	timer.add_to_group("GdUnitTimers")
	timer.timeout.connect(func do_interrupt():
		_interrupted = true
		value_provided.emit(null)
		, CONNECT_REFERENCE_COUNTED)
	timer.set_one_shot(true)
	timer.start((_timeout/1000.0)*time_scale)
	var sleep := Timer.new()
	sleep.set_name("gdunit_sleep_timer_%d" % sleep.get_instance_id() )
	Engine.get_main_loop().root.add_child(sleep)
	
	while true:
		next_current_value()
		var current = await value_provided
		if _interrupted:
			break
		var is_success = predicate.call(current, expected)
		if _expect_result != EXPECT_FAIL and is_success:
			break
		sleep.start(0.05)
		await sleep.timeout
	
	sleep.stop()
	sleep.queue_free()
	
	await Engine.get_main_loop().process_frame
	dispose()
	if _interrupted:
		# https://github.com/godotengine/godot/issues/73052
		#var predicate_name = predicate.get_method()
		var predicate_name = str(predicate).split('(')[0]
		report_error(GdAssertMessages.error_interrupted(predicate_name, expected, LocalTime.elapsed(_timeout)))
	else:
		report_success()
	return self


@warning_ignore("redundant_await")
func next_current_value():
	var current = await _current_value_provider.get_value()
	call_deferred("emit_signal", "value_provided", current)


# it is important to free all references/connections to prevent orphan nodes
func dispose():
	GdUnitTools.release_connections(self)
	_current_value_provider.dispose()
	_current_value_provider = null
