@tool
class_name UClip
extends RefCounted

var path: String = ""
var _stream: AudioStream

var name: String:
	get:
		return path.get_file().get_basename()

var stream: AudioStream:
	get:
		if _stream == null and path != "":
			_stream = load(path)
		return _stream

var length: float:
	get:
		var s := stream
		return s.get_length() if s != null else 0.0
