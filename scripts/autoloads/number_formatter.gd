extends Node

const SUFFIXES = ["", "k", "M", "B", "T", "aa", "ab", "ac", "ad", "ae", "af", "ag", "ah", "ai", "aj", "ak", "al", "am", "an", "ao", "ap", "aq", "ar", "as", "at", "au", "av", "aw", "ax", "ay", "az"]

static func format_value(value: float, precision: int = 2) -> String:
	var abs_value = abs(value)
	if abs_value < 1000.0:
		return ("%." + str(precision) + "f") % value
		
	var tier = int(floor(log(abs_value) / log(1000.0)))
	
	if tier >= SUFFIXES.size():
		return ("%." + str(precision) + "e") % value
		
	var suffix = SUFFIXES[tier]
	var scaled_value = value / (1000.0 ** tier)
	
	return ("%." + str(precision) + "f") % scaled_value + suffix
