package game

import k2 "../karl2d"
import "core:fmt"
import "core:math"
import "core:mem"

// Only called in desktop version
main :: proc() {
  g.desktop = true

  begin()
  for step() {}
  end()
}

init :: begin // Web build alias
begin :: proc() {
  mem.tracking_allocator_init(&g.alloc, context.allocator)
  context.allocator = mem.tracking_allocator(&g.alloc)

  k2.init(
    SCREEN_WIDTH * SCREEN_ZOOM,
    SCREEN_HEIGHT * SCREEN_ZOOM,
    "Reach the castle",
    options = {window_mode = .Windowed_Resizable, anti_alias = true},
  )
  k2.set_cursor_visible(false)

  Game_load()
}

end :: proc() {
  Game_unload()
  k2.shutdown()

  if len(g.alloc.allocation_map) > 0 {
    fmt.eprintf("=== %v allocations not freed: ===\n", len(g.alloc.allocation_map))
    for _, entry in g.alloc.allocation_map {
      fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
    }
  }

  mem.tracking_allocator_destroy(&g.alloc)
}

step :: proc(dt: f32 = 0) -> bool {
  k2.update() or_return
  if g.state.current == .Quit do return false
  if k2.key_went_down(.B) do toggle_shader()
  update_music()

  g.dpi = k2.get_window_scale()
  g.dt = dt == 0 ? k2.get_frame_time() : dt
  g.t += g.dt
  g.input = get_input()

  // k2.set_shader_constant(g.shader, g.shader_time, g.t)

  resize_render_texture()

  k2.set_camera(g.camera)
  k2.set_render_texture(g.render_texture)
  k2.set_shader(g.sprite_shader)
  Game_update()
  k2.set_shader(nil)

  k2.set_camera(k2.Camera{zoom = g.camera.zoom})
  Game_ui()

  k2.set_shader(g.sprite_shader)
  draw_cursor()

  k2.set_camera(nil)
  k2.set_render_texture(nil)
  k2.set_shader(nil)

  k2.set_shader(g.crt_shader)
  // k2.draw_texture(g.render_texture.texture, 0)
  k2.clear(k2.BLACK)
  k2.draw_texture_fit(g.render_texture.texture, g.render_source, g.render_dest)
  k2.set_shader(nil)
  Game_state_transition()
  k2.present()

  free_all(context.temp_allocator)

  return true
}

resize_render_texture :: proc() {
  original_size :: Vec2{SCREEN_WIDTH, SCREEN_HEIGHT}
  screen_size := k2.get_screen_size()
  factor := screen_size / original_size

  g.camera.zoom = math.min(factor.x, factor.y)

  // Fixed pixel ratio:
  // g.camera.zoom = math.floor(g.camera.zoom)
  // g.camera.offset = screen_size / 2 - original_size * g.camera.zoom / 2

  // g.render_origin = screen_size / 2 - original_size * g.camera.zoom / 2
  // g.render_origin.x = math.round(g.render_origin.x)
  // g.render_origin.y = math.round(g.render_origin.y)

  render_size := [2]int {
    int(math.floor(SCREEN_WIDTH * g.camera.zoom)),
    int(math.floor(SCREEN_HEIGHT * g.camera.zoom)),
  }

  g.render_source = Rect{0, 0, f32(render_size.x), f32(render_size.y)}
  g.render_dest = g.render_source
  g.render_dest.x = math.round(screen_size.x / 2 - original_size.x * g.camera.zoom / 2)
  g.render_dest.y = math.round(screen_size.y / 2 - original_size.y * g.camera.zoom / 2)

  should_update_render_texture :=
    g.render_texture.texture.width != render_size.x ||
    g.render_texture.texture.height != render_size.y

  if should_update_render_texture {
    if g.render_texture.texture.width != 0 {
      k2.destroy_render_texture(g.render_texture)
    }
    g.render_texture = k2.create_render_texture(render_size.x, render_size.y)
  }

  // render_rect := Rect {
  //   g.camera.offset.x,
  //   g.camera.offset.y,
  //   SCREEN_WIDTH * g.camera.zoom,
  //   SCREEN_HEIGHT * g.camera.zoom,
  // }
}

toggle_shader :: proc() {
  @(static) is_on := true

  if is_on {
    k2.set_shader_constant(g.crt_shader, g.crt_shader.constant_lookup["curve"], f32(0))
    k2.set_shader_constant(g.crt_shader, g.crt_shader.constant_lookup["blur"], f32(0))
    is_on = false
  } else {
    k2.set_shader_constant(g.crt_shader, g.crt_shader.constant_lookup["curve"], f32(CRT_CURVE))
    k2.set_shader_constant(g.crt_shader, g.crt_shader.constant_lookup["blur"], f32(CRT_BLUR))
    is_on = true
  }
}
