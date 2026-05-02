package game

import k2 "../karl2d"
import "core:math"
import "core:mem"

Game :: struct {
  alloc:           mem.Tracking_Allocator,
  desktop:         bool,
  dpi:             f32,
  t, dt:           f32, // Total passed time, delta time
  sprite_shader:   k2.Shader,
  crt_shader:      k2.Shader,
  shader_time:     k2.Shader_Constant_Location,
  texture:         k2.Texture,
  font:            k2.Font,
  render_texture:  k2.Render_Texture,
  render_source:   Rect,
  render_dest:     Rect,
  camera:          k2.Camera,
  input:           Input,
  tiles_blueprint: [MAP_SIZE][MAP_SIZE]BlueprintKind,
  tiles:           [MAP_SIZE][MAP_SIZE]Tile,
  entities:        [dynamic; 0xffff]Entity,
  player:          struct {
    hp: i32,
  },
  player_eid:      int,
  message:         Message,
}

SCREEN_WIDTH :: 256
SCREEN_HEIGHT :: 192
SCREEN_ZOOM :: 2
MAP_SIZE :: 256
CRT_CURVE :: 0.033
CRT_BLUR :: 0.2

g: Game

Entity :: struct {
  kind:     EntityKind,
  position: Grid2,
  offset:   Vec2,
}

EntityKind :: enum {
  Character,
  Enemy1,
  Enemy2,
  Enemy3,
  Sword,
}

BlueprintKind :: enum {
  Empty,
  Grass,
  Floor,
  Wall,
}

Entity_interact :: proc(player, entity: ^Entity, eid: int) {
  switch entity.kind {
  case .Character:
  // NOP
  case .Enemy1:
    unordered_remove(&g.entities, eid)
  case .Enemy2:
    unordered_remove(&g.entities, eid)
  case .Enemy3:
    unordered_remove(&g.entities, eid)
  case .Sword:
    // NOP
    unordered_remove(&g.entities, eid)
    Message_show("You got a sword!")
  }
}

Entity_draw :: proc(e: ^Entity) {
  ease_exp :: proc(x, y: Vec2, t: f32) -> Vec2 {
    return x + (y - x) * (1 - math.exp(-t))
  }

  position := Vec2{f32(e.position.x * 8), f32(e.position.y * 8)} + e.offset
  e.offset = ease_exp(e.offset, Vec2(0), 6 * g.dt)

  sprite: Sprite
  fg, mg, bg: SpriteColor

  switch e.kind {
  case .Character:
    sprite = .Character
    fg, mg, bg = .LightPeach, .Brown, .DarkBlue
  case .Enemy1:
    sprite = .Enemy1
    fg, mg, bg = .Green, .Brown, .DarkBlue
  case .Enemy2:
    sprite = .Enemy2
    fg, mg, bg = .Yellow, .Red, .DarkBlue
  case .Enemy3:
    sprite = .Enemy3
    fg, mg, bg = .LightGray, .DarkPurple, .DarkBlue
  case .Sword:
    sprite = .Sword
    fg, mg, bg = .Blue, .DarkGray, .Black
  }

  draw_sprite(sprite, position, fg, mg, bg)
}

Tile :: struct {
  kind: TileKind,
}

BLANK_TILE: Tile

TileKind :: enum {
  None,
  Grass0,
  Grass1,
  Grass2,
  Wall0,
  Wall1,
}

Tile_draw :: proc(tile: ^Tile, grid: Grid2) {
  switch tile.kind {
  case .None:
  // NOP
  case .Grass0:
    draw_sprite(.Grass0, Vec2{f32(grid.x * 8), f32(grid.y * 8)}, .Green, .DarkGreen, .DarkGreen)
  case .Grass1:
    draw_sprite(.Grass1, Vec2{f32(grid.x * 8), f32(grid.y * 8)}, .Green, .DarkGreen, .DarkGreen)
  case .Grass2:
    draw_sprite(.Grass2, Vec2{f32(grid.x * 8), f32(grid.y * 8)}, .Green, .DarkGreen, .DarkGreen)
  case .Wall0:
    draw_sprite(.Wall0, Vec2{f32(grid.x * 8), f32(grid.y * 8)}, .DarkGray, .LightGray, .White)
  case .Wall1:
    draw_sprite(.Wall1, Vec2{f32(grid.x * 8), f32(grid.y * 8)}, .DarkGray, .LightGray, .White)
  // NOP
  }
}

Tile_is_walkable :: proc(k: TileKind) -> bool {
  if k == .Grass0 || k == .Grass1 || k == .Grass2 {
    return true
  }
  return false
}

Message :: struct {
  text: string,
  time: f32,
}

Message_show :: proc(text: string, time: f32 = 3) {
  g.message = Message{text, time}
}

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
  k2.set_shader_constant(g.crt_shader, g.crt_shader.constant_lookup["curve"], f32(CRT_CURVE))
  k2.set_shader_constant(g.crt_shader, g.crt_shader.constant_lookup["blur"], f32(CRT_BLUR))
  g.shader_time = g.crt_shader.constant_lookup["time"]

  g.texture = k2.load_texture_from_bytes(#load("../assets/dungeon-mode-sheet.png"))
  g.font = k2.load_font_from_bytes(#load("../assets/tiny5.ttf"))

  g.camera = k2.Camera {
    zoom = SCREEN_ZOOM * k2.get_window_scale(),
  }

  {
    // Generate map
    blueprint := &g.tiles_blueprint

    for i := 0; i < MAP_SIZE; i += 1 {
      for j := 0; j < MAP_SIZE; j += 1 {
        blueprint[i][j] = rand_f() < 0.1 ? .Wall : .Grass
      }
    }

    for i := 0; i < MAP_SIZE; i += 1 {
      for j := 0; j < MAP_SIZE; j += 1 {
        r := rand_f()
        b := blueprint[i][j]

        kind: TileKind
        switch blueprint[i][j] {
        case .Empty:
        case .Grass:
          kind = r < 0.7 ? .Grass0 : r < 0.85 ? .Grass1 : .Grass2
        case .Floor:
        case .Wall:
          if j == MAP_SIZE - 1 || blueprint[i][j + 1] != .Wall {
            kind = .Wall1
          } else {
            kind = .Wall0
          }
        }

        g.tiles[i][j] = Tile {
          kind = kind,
        }
      }
    }
  }

  append(&g.entities, Entity{kind = .Character})
  g.player.hp = 3
  g.player_eid = 0

  append(&g.entities, Entity{kind = .Sword, position = {3, 3}})
  append(&g.entities, Entity{kind = .Enemy1, position = {4, 5}})
  append(&g.entities, Entity{kind = .Enemy2, position = {5, 5}})
  append(&g.entities, Entity{kind = .Enemy3, position = {6, 5}})
}

Game_unload :: proc() {
  k2.destroy_render_texture(g.render_texture)
  k2.destroy_texture(g.texture)
  k2.destroy_font(g.font)
  k2.destroy_shader(g.sprite_shader)
  k2.destroy_shader(g.crt_shader)
}

Game_update :: proc() {
  get_tile :: proc(pos: Grid2) -> ^Tile {
    if pos.x < 0 || pos.y < 0 || pos.x >= MAP_SIZE || pos.y >= MAP_SIZE do return &BLANK_TILE
    return &g.tiles[pos.x][pos.y]
  }

  k2.clear(k2.DARK_GRAY)

  player := &g.entities[g.player_eid]

  {
    // Draw map
    pos := player.position
    for i := i32(-18); i < 18; i += 1 {
      for j := i32(-14); j < 14; j += 1 {
        grid := pos + Grid2{i, j}
        tile := get_tile(grid)
        Tile_draw(tile, grid)
      }
    }
  }

  player_movement: {
    // Player movement
    ACCELERATION :: 75
    DECELERATION :: 20
    MAX_SPEED :: 100

    @(static) input_timeout := f32(0)
    if input_timeout > 0 {
      input_timeout -= g.dt
      break player_movement
    }

    mx := i32(g.input.movement.x)
    my := i32(g.input.movement.y)
    if mx == 0 && my == 0 {
      break player_movement
    }

    new_position := player.position + Grid2{mx, my}
    new_tile := get_tile(new_position)
    if Tile_is_walkable(new_tile.kind) {
      player.position = new_position
      player.offset -= Vec2{f32(mx) * 8, f32(my) * 8}
      input_timeout = 0.13
    }
  }

  {
    // Camera follow player
    g.camera.target =
      Vec2{f32(player.position.x * 8), f32(player.position.y * 8)} +
      player.offset -
      Vec2{SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2}
  }

  {
    // Draw entities
    #reverse for &entity, id in g.entities {
      Entity_draw(&entity)

      if id != g.player_eid {
        if entity.position == player.position {
          Entity_interact(player, &entity, id)
        }
      }
    }
  }
}

Game_ui :: proc() {
  {
    // Draw health
    health_sprite :: proc(n: i32) -> Sprite {
      return g.player.hp >= n ? .Heart1 : .Heart0
    }
    for i := i32(1); i <= math.max(g.player.hp, i32(3)); i += 1 {
      draw_ui_sprite(health_sprite(i), {f32(i * 8 + (i - 1) * 2), 8})
    }
  }

  if g.message.time > 0 {
    g.message.time -= g.dt
    draw_text_outline(g.message.text, {8, 16})
  }

  // draw_text_outline(fmt.tprintf("Zoom: %.1f", g.camera.zoom), {10, 30})
  // draw_text_outline(fmt.tprintf("Pointer: %.1f", g.input.mouse_world), {10, 40})
  // draw_text_outline(fmt.tprintf("Pointer: %.1f", g.input.mouse_screen), {10, 50})

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

