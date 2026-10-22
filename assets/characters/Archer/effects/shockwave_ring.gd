extends Node2D

func _draw() -> void:
	var wb = get_parent() as ArcherChargedWorkbench
	if not wb:
		return
	if wb.shockwave_alpha > 0.01 and wb.shockwave_radius > 1.0:
		# Multi-temperature forward shockwave arc/ring expanding from bow
		draw_arc(Vector2.ZERO, wb.shockwave_radius, -PI * 0.45, PI * 0.45, 36, Color(1.0, 1.0, 1.0, wb.shockwave_alpha), 4.0)
		draw_arc(Vector2.ZERO, wb.shockwave_radius * 0.88, -PI * 0.40, PI * 0.40, 28, Color(1.0, 0.88, 0.08, wb.shockwave_alpha * 0.85), 2.5)
		draw_arc(Vector2.ZERO, wb.shockwave_radius * 0.72, -PI * 0.35, PI * 0.35, 20, Color(0.86, 0.40, 0.0, wb.shockwave_alpha * 0.55), 1.8)
