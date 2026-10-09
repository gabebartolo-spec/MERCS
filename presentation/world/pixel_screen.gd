class_name PixelScreen
extends RefCounted
## Whole-screen pixel mode (director, 2026-10-08; 01_ENGINE_DECISION.md "Rendering plan"):
## the 3D world renders into a logical SubViewport scaled up by a whole number with nearest
## filtering, so every texel of world and sprite is one logical pixel on screen.

const CONTAINER_NAME := &"PixelScreen"
const VIEWPORT_NAME := &"LogicalViewport"


## Moves world into a logical-size SubViewport under host, shown scale times larger. Sized
## from the arguments, not the window, so it is the same even headless.
static func wrap(host: Node, world: Node3D, logical: Vector2i, scale: int) -> SubViewport:
	var container := SubViewportContainer.new()
	container.name = CONTAINER_NAME
	container.position = Vector2.ZERO
	container.size = Vector2(logical * scale)
	container.stretch = true
	container.stretch_shrink = scale
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.name = VIEWPORT_NAME
	viewport.size = logical
	viewport.handle_input_locally = false
	host.add_child(container)
	container.add_child(viewport)
	world.reparent(viewport)
	return viewport


## The logical-viewport pixel under a window position (whole-screen mode).
static func to_logical(window_position: Vector2, scale: int) -> Vector2:
	return window_position / maxf(1.0, float(scale))
