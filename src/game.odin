package game

import k2 "../karl2d"
import "core:fmt"
import "core:math"
import "core:mem"

Game :: struct {
  alloc:          mem.Tracking_Allocator,
  desktop:        bool,
  dpi:            f32,
  t, dt:          f32, // Total passed time, delta time
  sprite_shader:  k2.Shader,
  crt_shader:     k2.Shader,
  shader_time:    k2.Shader_Constant_Location,
  texture:        k2.Texture,
  font:           k2.Font,
  render_texture: k2.Render_Texture,
  render_source:  Rect,
  render_dest:    Rect,
  camera:         k2.Camera,
  input:          Input,
}

SCREEN_WIDTH :: 256
SCREEN_HEIGHT :: 192
SCREEN_ZOOM :: 2

g: Game

Game_load :: proc() {
  if g.desktop {
    g.sprite_shader = k2.load_shader_from_bytes(
      #load("../assets/shader_desktop_vertex.glsl"),
      #load("../assets/shader_desktop_fragment.glsl"),
    )
    g.crt_shader = k2.load_shader_from_bytes(
      #load("../assets/shader_crt_desktop_vertex.glsl"),
      #load("../assets/shader_crt_desktop_fragment.glsl"),
    )
  } else {
    g.sprite_shader = k2.load_shader_from_bytes(
      #load("../assets/shader_webgl_vertex.glsl"),
      #load("../assets/shader_webgl_fragment.glsl"),
    )
    g.crt_shader = k2.load_shader_from_bytes(
      #load("../assets/shader_crt_webgl_vertex.glsl"),
      #load("../assets/shader_crt_webgl_fragment.glsl"),
    )
  }
  k2.set_shader_constant(g.crt_shader, g.crt_shader.constant_lookup["curve"], f32(0.033))
  k2.set_shader_constant(g.crt_shader, g.crt_shader.constant_lookup["blur"], f32(0.2))
  g.shader_time = g.crt_shader.constant_lookup["time"]

  g.texture = k2.load_texture_from_bytes(#load("../assets/dungeon-mode-sheet.png"))
  g.font = k2.load_font_from_bytes(#load("../assets/tiny5.ttf"))

  g.camera = k2.Camera {
    zoom = SCREEN_ZOOM * k2.get_window_scale(),
  }
}

Game_unload :: proc() {
  k2.destroy_render_texture(g.render_texture)
  k2.destroy_texture(g.texture)
  k2.destroy_font(g.font)
  k2.destroy_shader(g.sprite_shader)
  k2.destroy_shader(g.crt_shader)
}

Game_update :: proc() {
  k2.clear(k2.DARK_GRAY)

  {
    // Chracter test
    @(static) dbg_pos, dbg_acc: Vec2
    if g.input.movement == 0 {
      for i := 0; i < 10; i += 1 {
        dbg_acc -= dbg_acc * g.dt
      }
    } else {
      dbg_acc += g.input.movement * 5 * g.dt
    }

    dbg_pos += dbg_acc
    draw_sprite(.Character, dbg_pos, .LightPeach, .Brown, .DarkBlue)

    g.camera.target = dbg_pos - Vec2{SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2}
  }
}

Game_ui :: proc() {
  draw_text_outline("Hello, World!", {10 + math.sin(g.t * 4) * 10, 10})
  draw_text_outline(fmt.tprintf("Zoom: %.1f", g.camera.zoom), {10, 30})
  draw_text_outline(fmt.tprintf("Pointer: %.1f", g.input.mouse_world), {10, 40})
  draw_text_outline(fmt.tprintf("Pointer: %.1f", g.input.mouse_screen), {10, 50})

  if draw_button("I'm button :) !!!", {10, 10}, .TopRight) {
    p("Clicked top right")
  }
  if draw_button("UwU /?????", {10, 10}, .BottomLeft) {
    p("UWUWUWUWU")
  }
  if draw_button("Attack / Defend", {10, 10}, .BottomRight) {
    p("Clicked bottom right")
  }
}

