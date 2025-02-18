class_name GdUnitArgumentMatchers
extends GdUnitStaticDictionary

const TYPE_ANY = TYPE_MAX + 100


func _init():
	for build_in_type in GdObjects.all_types():
		GdUnitStaticDictionary.add_value(build_in_type, AnyBuildInTypeArgumentMatcher.new(build_in_type))
	GdUnitStaticDictionary.add_value(TYPE_ANY, AnyArgumentMatcher.new())


static func to_matcher(arguments :Array, auto_deep_check_mode := false) -> ChainedArgumentMatcher:
	var matchers := Array()
	for arg in arguments:
		# argument is already a matcher
		if arg is GdUnitArgumentMatcher:
			matchers.append(arg)
		else:
			# pass argument into equals matcher
			matchers.append(EqualsArgumentMatcher.new(arg, auto_deep_check_mode))
	return ChainedArgumentMatcher.new(matchers)


static func any() -> GdUnitArgumentMatcher:
	return get_value(TYPE_ANY)


static func by_type(type :int) -> GdUnitArgumentMatcher:
	return get_value(type)


static func any_class(clazz) -> GdUnitArgumentMatcher:
	return AnyClazzArgumentMatcher.new(clazz)
