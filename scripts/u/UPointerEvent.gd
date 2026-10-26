class_name UPointerEvent
extends RefCounted

var position := Vector2.ZERO
var delta := Vector2.ZERO
var pressPosition := Vector2.ZERO
var scrollDelta := Vector2.ZERO
var button := 0
var clickCount := 0
var clickTime := 0.0
var pointerEnter
var pointerPress
var rawPointerPress
var lastPress
var pointerDrag
var pointerClick
var dragging := false
var eligibleForClick := false
var useDragThreshold := true
var used := false
var pointerCurrentRaycast := {"gameObject": null}
var pointerPressRaycast := {"gameObject": null}
var hovered: Array = []

func Use() -> void:
	used = true

func Reset() -> void:
	used = false

func IsPointerMoving() -> bool:
	return delta.length_squared() > 0.0
