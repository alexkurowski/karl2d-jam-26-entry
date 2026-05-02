#+private
package game

import k2 "../karl2d"
import "core:fmt"
import "core:math"
import "core:math/rand"

Vec2 :: [2]f32
Grid2 :: [2]i32
Rect :: k2.Rect
Color :: k2.Color

Input :: struct {
  movement:     Vec2,
  primary:      bool,
  secondary:    bool,
  mouse_world:  Vec2,
  mouse_screen: Vec2,
  mouse_grid:   Grid2,
  mouse_click:  bool,
}

get_input :: proc() -> Input {
  i: Input

  mouse_position := k2.get_mouse_position() - Vec2{g.render_dest.x, g.render_dest.y}
  i.mouse_world = k2.screen_to_world(mouse_position, g.camera)
  i.mouse_screen = k2.screen_to_world(mouse_position, k2.Camera{zoom = g.camera.zoom})
  i.mouse_grid = Grid2{i32(i.mouse_screen.x / 8), i32(i.mouse_screen.y / 8)}

  if Game_in_transition() {
    return i
  }

  if k2.key_is_held(.Left) || k2.key_is_held(.A) do i.movement.x = -1
  if k2.key_is_held(.Right) || k2.key_is_held(.D) do i.movement.x = +1
  if k2.key_is_held(.Up) || k2.key_is_held(.W) do i.movement.y = -1
  if k2.key_is_held(.Down) || k2.key_is_held(.S) do i.movement.y = +1

  if i.movement.x != 0 && i.movement.y != 0 {
    // Disable diagonal movement
    if chance(0.5) {
      i.movement.x = 0
    } else {
      i.movement.y = 0
    }
  }

  if k2.key_is_held(.X) || k2.key_is_held(.J) do i.primary = true
  if k2.key_is_held(.Z) || k2.key_is_held(.K) do i.secondary = true

  i.mouse_click = k2.mouse_button_went_down(.Left)

  return i
}

is_hovered :: proc(rect: Rect) -> bool {
  return k2.point_in_rect(g.input.mouse_screen, rect)
}

is_hovered_grid :: proc(a, b: Grid2) -> bool {
  x := g.input.mouse_grid.x
  y := g.input.mouse_grid.y
  return x >= a.x && x <= b.x && y >= a.y && y <= b.y
}

is_clicked :: proc(rect: Rect) -> bool {
  return k2.point_in_rect(g.input.mouse_screen, rect) && k2.mouse_button_went_down(.Left)
}

is_clicked_grid :: proc(a, b: Grid2) -> bool {
  x := g.input.mouse_grid.x
  y := g.input.mouse_grid.y
  return x >= a.x && x <= b.x && y >= a.y && y <= b.y && k2.mouse_button_went_down(.Left)
}

rand_f :: proc(min: f32 = 0, max: f32 = 1) -> f32 {
  return rand.float32_range(min, max)
}

chance :: proc(value: f32) -> bool {
  return rand_f() < value
}

ease_exp :: proc(x, y: Vec2, t: f32) -> Vec2 {
  return x + (y - x) * (1 - math.exp(-t))
}

scale :: proc(value, from_min, from_max, to_min, to_max: f32) -> f32 {
  if value < from_min do return to_min
  if value > from_max do return to_max
  return (value - from_min) / (from_max - from_min) * (to_max - to_min) + to_min
}

p :: proc(value: any, name := #caller_expression(value)) {
  fmt.printf("%v = %#v\n", name, value)
}

pp :: proc(prefix: string, v: any) {
  fmt.printf(">>> %s: %#v\n", prefix, v)
}

