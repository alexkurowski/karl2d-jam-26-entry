package game

import k2 "../karl2d"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:strings"

SCREEN_WIDTH :: 160
SCREEN_HEIGHT :: 128
SCREEN_ZOOM :: 3
MAP_SIZE :: 12
STATE_TRANSITION_DURATION :: 0.133
CRT_CURVE :: 0.05
CRT_BLUR :: 0.2

Game :: struct {
  alloc:          mem.Tracking_Allocator,
  desktop:        bool,
  dpi:            f32,
  t, dt:          f32, // Total passed time, delta time
  sprite_shader:  k2.Shader,
  crt_shader:     k2.Shader,
  shader_time:    k2.Shader_Constant_Location,
  texture:        k2.Texture,
  render_texture: k2.Render_Texture,
  render_source:  Rect,
  render_dest:    Rect,
  font:           k2.Font,
  camera:         k2.Camera,
  state:          struct {
    current:    Game_State,
    next:       Game_State,
    transition: f32,
  },
  cursor:         Cursor,
  input:          Input,
  tiles:          [MAP_SIZE][MAP_SIZE]Tile,
  entities:       [dynamic; 256]Entity,
  room:           [dynamic; 4]Entity,
  player:         Player,
  menu:           struct {
    game_started:   bool,
    options:        bool,
    win_jump_t:     f32,
    gameover_blood: [8]i32,
  },
  message:        Message,
}

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
  k2.set_shader_constant(g.crt_shader, g.crt_shader.constant_lookup["curve"], f32(CRT_CURVE))
  k2.set_shader_constant(g.crt_shader, g.crt_shader.constant_lookup["blur"], f32(CRT_BLUR))
  g.shader_time = g.crt_shader.constant_lookup["time"]

  g.state.transition = -STATE_TRANSITION_DURATION
  g.texture = k2.load_texture_from_bytes(#load("../assets/dungeon-mode-sheet.png"))
  g.font = k2.load_font_from_bytes(#load("../assets/tiny5.ttf"))
}

Game_unload :: proc() {
  k2.destroy_render_texture(g.render_texture)
  k2.destroy_texture(g.texture)
  k2.destroy_font(g.font)
  k2.destroy_shader(g.sprite_shader)
  k2.destroy_shader(g.crt_shader)
}

Game_set_state :: proc(next_state: Game_State) {
  if g.state.current != next_state && g.state.next != next_state {
    g.state.next = next_state
    g.state.transition = STATE_TRANSITION_DURATION
  }
}

Game_start_new_game :: proc() {
  {
    // Reset player
    g.player = Player {
      hp = 20,
    }
  }
  {
    // Generate map
    for i := i32(0); i < MAP_SIZE; i += 1 {
      for j := i32(0); j < MAP_SIZE; j += 1 {
        r, rr: f32 = rand_f(), rand_f()
        kind: TileKind
        if r < 0.3 {
          kind = rr < 0.33 ? .Woods0 : rr < 0.66 ? .Woods1 : .Woods2
        } else {
          kind = rr < 0.33 ? .Grass0 : rr < 0.66 ? .Grass1 : .Grass2
        }

        g.tiles[i][j] = Tile {
          kind = kind,
        }
      }
    }
  }
  {
    // Place water tiles
    water_x, water_y := i32(rand_f(0, MAP_SIZE)), i32(rand_f(0, MAP_SIZE))
    g.tiles[water_x][water_y].kind = .Water0 // Place initial water tile

    water_tiles_count := i32(1)
    water_tiles_target := i32(rand_f(6, 16))

    // Flood fill some water tiles
    water_queue: [dynamic; 20]Grid2
    safeguard := 0
    for water_tiles_count < water_tiles_target {
      safeguard += 1
      if safeguard > 100 do break

      for i := i32(0); i < MAP_SIZE; i += 1 {
        for j := i32(0); j < MAP_SIZE; j += 1 {
          if Tile_is_water(i, j) {
            if i > 0 && !Tile_is_water(i - 1, j) && chance(0.5) {
              append(&water_queue, Grid2{i - 1, j})
            }
            if i < MAP_SIZE - 1 && !Tile_is_water(i + 1, j) && chance(0.5) {
              append(&water_queue, Grid2{i + 1, j})
            }
            if j > 0 && !Tile_is_water(i, j - 1) && chance(0.5) {
              append(&water_queue, Grid2{i, j - 1})
            }
            if j < MAP_SIZE - 1 && !Tile_is_water(i, j + 1) && chance(0.5) {
              append(&water_queue, Grid2{i, j + 1})
            }
          }
        }
      }

      for &q in water_queue {
        if Tile_is_water(q.x, q.y) do continue
        if water_tiles_count >= water_tiles_target do break
        r := rand_f()
        if r < 0.7 {
          g.tiles[q.x][q.y].kind = .Water0
        } else {
          g.tiles[q.x][q.y].kind = .Water1
        }
        water_tiles_count += 1
      }
    }

    for i := i32(0); i < MAP_SIZE; i += 1 {
      for j := i32(0); j < MAP_SIZE; j += 1 {
        if Tile_is_water(i, j) {
          Tile_reveal(i, j)
          g.tiles[i][j].clear = true
          if i > 0 && !Tile_is_water(i - 1, j) {
            g.tiles[i - 1][j].known = true
          }
          if i < MAP_SIZE - 1 && !Tile_is_water(i + 1, j) {
            g.tiles[i + 1][j].known = true
          }
          if j > 0 && !Tile_is_water(i, j - 1) {
            g.tiles[i][j - 1].known = true
          }
          if j < MAP_SIZE - 1 && !Tile_is_water(i, j + 1) {
            g.tiles[i][j + 1].known = true
          }
        }
      }
    }
  }
  {
    // Place player near water
    possible_positions: [dynamic; 32]Grid2
    for i := i32(0); i < MAP_SIZE; i += 1 {
      for j := i32(0); j < MAP_SIZE; j += 1 {
        if len(possible_positions) >= cap(possible_positions) do break
        if Tile_is_water(i, j) {
          if i > 0 && !Tile_is_water(i - 1, j) {
            if !Tile_is_border(i - 1, j) {
              append(&possible_positions, Grid2{i - 1, j})
            }
          }
          if i < MAP_SIZE - 1 && !Tile_is_water(i + 1, j) {
            if !Tile_is_border(i + 1, j) {
              append(&possible_positions, Grid2{i + 1, j})
            }
          }
          if j > 0 && !Tile_is_water(i, j - 1) {
            if !Tile_is_border(i, j - 1) {
              append(&possible_positions, Grid2{i, j - 1})
            }
          }
          if j < MAP_SIZE - 1 && !Tile_is_water(i, j + 1) {
            if !Tile_is_border(i, j + 1) {
              append(&possible_positions, Grid2{i, j + 1})
            }
          }
        }
      }
    }

    rand.shuffle(possible_positions[:])
    g.player.position = possible_positions[0]
    Tile_reveal(g.player.position.x, g.player.position.y)
    Tile_clear(g.player.position.x, g.player.position.y)
  }
  {
    // Place castle opposite of player
    a, b, c: Grid2
    px := g.player.position.x
    py := g.player.position.y
    mid := i32(MAP_SIZE / 2)
    if px < mid && py < mid {
      c = {MAP_SIZE - 2, MAP_SIZE - 2}
      b = c
      a = b - {3, 3}
    } else if px >= mid && py < mid {
      c = {1, MAP_SIZE - 2}
      a = c - {0, 3}
      b = c + {3, 0}
    } else if px < mid && py >= mid {
      c = {MAP_SIZE - 2, 1}
      a = c - {3, 0}
      b = c + {0, 3}
    } else if px >= mid && py >= mid {
      c = {1, 1}
      a = c
      b = c + {3, 3}
    }

    possible_positions: [dynamic; 16]Grid2
    for i := a.x; i <= b.x; i += 1 {
      for j := a.y; j <= b.y; j += 1 {
        if Tile_is_walkable(i, j) {
          append(&possible_positions, Grid2{i, j})
        }
      }
    }

    rand.shuffle(possible_positions[:])
    pos := possible_positions[0]
    g.tiles[pos.x][pos.y].kind = .Castle
    g.tiles[pos.x][pos.y].clear = true
  }
  {
    // Generate entities
    Entity_generate()
  }

  Game_set_state(.Map)
}

Game_start_new_room :: proc() {
  rand.shuffle(g.entities[:])

  clear(&g.room)
  append(&g.room, pop(&g.entities))
  append(&g.room, pop(&g.entities))
  append(&g.room, pop(&g.entities))
  append(&g.room, pop(&g.entities))

  if len(g.entities) <= 4 {
    Entity_generate()
  }

  Game_set_state(.Room)
}

Player :: struct {
  position:     Grid2,
  offset:       Vec2,
  hp:           i32,
  armor:        i32,
  weapon:       i32,
  loot:         i32,
  kills:        i32,
  shake_hp:     f32,
  shake_armor:  f32,
  shake_weapon: f32,
  shake_loot:   f32,
  had_armor:    bool,
  had_weapon:   bool,
  input_delay:  f32,
  room_delay:   f32,
  room_cleared: bool,
  fled_before:  bool,
}

Entity :: struct {
  kind:  EntityKind,
  value: i32,
  clear: bool,
}

EntityKind :: enum {
  Enemy1,
  Enemy2,
  Enemy3,
  Weapon,
  Heal,
  Armor,
  Loot,
}

Entity_generate :: proc() {
  clear(&g.entities)
  for n := 0; n < 4; n += 1 {
    top: i32 = n == 0 ? 14 : 10
    for i := i32(1); i <= top; i += 1 {
      if i < 8 {
        append(&g.entities, Entity{.Enemy1, i, false})
        append(&g.entities, Entity{.Enemy1, i, false})
        if n == 0 {
          append(&g.entities, Entity{.Enemy1, i, false})
          append(&g.entities, Entity{.Enemy1, i, false})
        }
      }
      if i >= 4 {
        append(&g.entities, Entity{.Enemy2, i, false})
        append(&g.entities, Entity{.Enemy2, i, false})
        append(&g.entities, Entity{.Enemy2, i, false})
      }
      if i >= 8 {
        append(&g.entities, Entity{.Enemy3, i, false})
        append(&g.entities, Entity{.Enemy3, i, false})
      }
      if i <= 10 {
        append(&g.entities, Entity{.Weapon, i, false})
        append(&g.entities, Entity{.Armor, i, false})
        append(&g.entities, Entity{.Armor, i, false})
        append(&g.entities, Entity{.Heal, i, false})
        append(&g.entities, Entity{.Heal, i, false})
      }
      append(&g.entities, Entity{.Loot, i, false})
      append(&g.entities, Entity{.Loot, i, false})
    }
  }
  rand.shuffle(g.entities[:])
}

Entity_interact :: proc(entity: ^Entity) {
  switch entity.kind {
  case .Enemy1, .Enemy2, .Enemy3:
    value := entity.value
    // Spend weapon
    if g.player.weapon > 0 {
      weapon_before := g.player.weapon
      g.player.weapon = math.max(g.player.weapon - value, 0)
      weapon_lost := weapon_before - g.player.weapon
      value -= weapon_lost
      g.player.shake_weapon = 0.5
    }
    if value <= 0 {
      // Message_show(fmt.tprintf("You slain enemy effortlessly"))
      g.player.kills += 1
      entity.clear = true
      return
    }
    // Spend armor
    if g.player.armor > 0 {
      armor_before := g.player.armor
      g.player.armor = math.max(g.player.armor - value, 0)
      armor_lost := armor_before - g.player.armor
      value -= armor_lost
      g.player.shake_armor = 0.5
    }
    if value <= 0 {
      // Message_show(fmt.tprintf("You slain enemy effortlessly"))
      g.player.kills += 1
      entity.clear = true
      return
    }
    // Spend hp
    hp_before := g.player.hp
    g.player.hp = math.max(g.player.hp - value, 0)
    hp_lost := hp_before - g.player.hp
    value -= hp_lost
    g.player.shake_hp = 0.5
    if value <= 0 {
      g.player.kills += 1
      entity.clear = true
    }
    // Check if player died
    if g.player.hp <= 0 {
      g.player.hp = 0
      Game_set_state(.Gameover)
    }

  case .Weapon:
    g.player.weapon += entity.value
    g.player.shake_weapon = 0.3
    g.player.had_weapon = true
    Message_show(fmt.tprintf("You found a weapon"))
    entity.clear = true

  case .Heal:
    hp_before := g.player.hp
    g.player.hp = math.min(g.player.hp + entity.value, 20)
    hp_gain := g.player.hp - hp_before
    g.player.shake_hp = 0.3
    if hp_gain == entity.value {
      Message_show(fmt.tprintf("You restored %v health", hp_gain))
    } else if hp_gain <= 0 {
      Message_show("You are already at full health")
    } else {
      Message_show(fmt.tprintf("You restored %v health", hp_gain))
    }
    entity.clear = true

  case .Armor:
    armor_before := g.player.armor
    g.player.armor = math.min(g.player.armor + entity.value, 20)
    armor_gain := g.player.armor - armor_before
    g.player.shake_armor = 0.3
    g.player.had_armor = true
    if armor_gain == entity.value {
      Message_show(fmt.tprintf("You got %v armor", armor_gain))
    } else if armor_gain <= 0 {
      Message_show("You can't wear any more armor")
    } else {
      Message_show(fmt.tprintf("You got %v armor", armor_gain))
    }
    entity.clear = true

  case .Loot:
    g.player.loot += entity.value
    g.player.shake_loot = 0.3
    Message_show(fmt.tprintf("You found $%v!", entity.value))
    entity.clear = true
  }
}

Tile :: struct {
  kind:  TileKind,
  known: bool,
  clear: bool,
}

BLANK_TILE: Tile

TileKind :: enum {
  None,
  Grass0,
  Grass1,
  Grass2,
  Woods0,
  Woods1,
  Woods2,
  Water0,
  Water1,
  Castle,
}

Tile_is_valid :: proc(x, y: i32) -> bool {
  return x >= 0 && x < MAP_SIZE && y >= 0 && y < MAP_SIZE
}

Tile_is_border :: proc(x, y: i32) -> bool {
  return x <= 0 || x >= MAP_SIZE - 1 || y <= 0 || y >= MAP_SIZE - 1
}

Tile_is_walkable :: proc(x, y: i32) -> bool {
  Tile_is_valid(x, y) or_return
  k := g.tiles[x][y].kind
  if k == .Grass0 ||
     k == .Grass1 ||
     k == .Grass2 ||
     k == .Woods0 ||
     k == .Woods1 ||
     k == .Woods2 ||
     k == .Castle {
    return true
  }
  return false
}

Tile_is_water :: proc(x, y: i32) -> bool {
  if Tile_is_valid(x, y) {
    k := g.tiles[x][y].kind
    return k == .Water0 || k == .Water1
  } else {
    return true
  }
}

Tile_reveal :: proc(x, y: i32) {
  for i := i32(-1); i <= 1; i += 1 {
    for j := i32(-1); j <= 1; j += 1 {
      if Tile_is_valid(x + i, y + j) {
        g.tiles[x + i][y + j].known = true
      }
    }
  }
}

Tile_clear :: proc(x, y: i32) {
  if Tile_is_valid(x, y) {
    g.tiles[x][y].clear = true
  }
}

Tile_draw :: proc(tile: Tile, pos: Grid2) {
  if !tile.known do return

  grass_bg: Sprite_Color = .DarkGreen
  if tile.clear {
    grass_bg = .Green
  }

  switch tile.kind {
  case .None:
  // NOP
  case .Grass0:
    draw_sprite({0, 0}, pos, .LightGreen, .LightGreen, .DarkGreen, grass_bg)
  case .Grass1:
    draw_sprite({0, 2}, pos, .LightGreen, .LightGreen, .DarkGreen, grass_bg)
  case .Grass2:
    draw_sprite({1, 2}, pos, .LightGreen, .LightGreen, .DarkGreen, grass_bg)
  case .Woods0:
    draw_sprite({2, 2}, pos, .LightGreen, .Brown, .Green, grass_bg)
  case .Woods1:
    draw_sprite({3, 2}, pos, .LightGreen, .Brown, .Green, grass_bg)
  case .Woods2:
    draw_sprite({4, 2}, pos, .LightGreen, .Brown, .Green, grass_bg)
  case .Water0:
    draw_sprite({0, 0}, pos, .DarkBlue, .DarkBlue, .DarkBlue, .DarkBlue)
  case .Water1:
    draw_sprite({13, 7}, pos, .LightBlue, .Blue, .DarkBlue, .DarkBlue)
  case .Castle:
    draw_sprite({11, 8}, pos, .LightBlue, .LightGray, .Gray, .DarkGreen)
  }

  // if !tile.clear {
  //   draw_sprite({9, 0}, pos, .DarkRed, .Red)
  // }
}

Game_State :: enum {
  Menu,
  Map,
  Room,
  Win,
  Gameover,
  Quit,
}

Cursor :: enum {
  Regular,
  Pointer,
  GoRight,
  GoLeft,
  GoUp,
  GoDown,
  Disabled,
}

Message :: struct {
  text: Maybe(string),
  time: f32,
}

Message_show :: proc(text: string, time: f32 = 3) {
  if g.message.text != nil {
    delete(g.message.text.?)
  }
  g.message.text = strings.clone(text)
  g.message.time = time
}

Game_update :: proc() {
  k2.clear({40, 40, 46, 255})
  k2.set_cursor_visible(
    g.input.mouse_screen.x < 0 ||
    g.input.mouse_grid.x >= 20 ||
    g.input.mouse_screen.y < 0 ||
    g.input.mouse_grid.y >= 16,
  )
  g.cursor = .Regular

  if k2.key_went_down(.Escape) {
    if g.state.current == .Map || g.state.current == .Win || g.state.current == .Gameover {
      Game_set_state(.Menu)
    }
    if g.state.current == .Menu && g.desktop {
      g.state.current = .Quit
    }
  }

  switch g.state.current {
  case .Menu:
    Game_Menu_update()
  case .Map:
    Game_Map_update()
  case .Room:
    Game_Room_update()
  case .Win:
    Game_Win_update()
  case .Gameover:
    Game_Gameover_update()
  case .Quit:
    return
  }
}

Game_state_transition :: proc() {
  t := g.state.transition

  if t <= -STATE_TRANSITION_DURATION do return

  t -= g.dt
  g.state.transition = t

  if t <= 0 && g.state.current != g.state.next {
    g.state.current = g.state.next

    switch g.state.current {
    case .Menu:
      Game_Menu_init()
    case .Map:
      Game_Map_init()
    case .Room:
      Game_Room_init()
    case .Win:
      Game_Win_init()
    case .Gameover:
      Game_Gameover_init()
    case .Quit:
    // NOP
    }
  }

  if t > 0 {
    // Fade out
    scaled_t := 1 - (t / STATE_TRANSITION_DURATION) // MAX_DURATION -> 0, 0 -> 1
    fade_alpha := u8(math.clamp(scaled_t, 0, 1) * 255)
    k2.draw_rect(g.render_dest, Color{0, 0, 0, fade_alpha})
  } else if t >= -STATE_TRANSITION_DURATION {
    // Fade in
    scaled_t := 1 - (t / -STATE_TRANSITION_DURATION) // 0 -> -MAX_DURATION, 1 -> 0
    fade_alpha := u8(clamp(scaled_t, 0, 1) * 255)
    k2.draw_rect(g.render_dest, Color{0, 0, 0, fade_alpha})
  }
}

Game_in_transition :: proc() -> bool {
  return g.state.transition > -STATE_TRANSITION_DURATION
}

//

Game_Menu_init :: proc() {
  if g.player.hp <= 0 {
    g.menu.game_started = false
  }
  g.menu.options = false
}

Game_Menu_update :: proc() {
  btn :: proc(label: string, pos: Grid2) -> bool {
    hovered := is_hovered_grid(pos, pos + {5, 0})
    clicked := hovered && g.input.mouse_click

    if hovered {
      draw_sprite({12, 1}, pos)
      draw_text_outline(label, pos + {1, 0})
    } else {
      draw_text_outline(label, pos)
    }

    return clicked
  }

  if !g.menu.options {
    if can_continue() {
      if btn("Continue", {2, 7}) {
        Game_set_state(.Map)
      }
    }

    if btn("Start", {2, 9}) {
      Game_start_new_game()
    }

    if btn("Options", {2, 11}) {
      g.menu.options = true
    }

    if g.desktop {
      if btn("Quit", {2, 13}) {
        g.state.current = .Quit
      }
    }
  } else {
    if btn("CRT effect", {2, 11}) {
      toggle_shader()
    }

    if btn("Back", {2, 13}) {
      g.menu.options = false
    }
  }
}

//

Game_Map_init :: proc() {
  g.menu.game_started = true
}

Game_Map_update :: proc() {
  {
    // Player movement
    move_player :: proc(dir: Grid2) {
      new_position := g.player.position + dir
      if Tile_is_walkable(new_position.x, new_position.y) {
        g.player.position = new_position
        g.player.offset -= Vec2{f32(dir.x), f32(dir.y)} * 8
        Tile_reveal(new_position.x, new_position.y)

        if !g.tiles[g.player.position.x][g.player.position.y].clear {
          g.player.input_delay = 0.66
        } else if g.tiles[g.player.position.x][g.player.position.y].kind == .Castle {
          g.player.input_delay = 0.99
          g.t = 0
        } else {
          g.player.input_delay = 0.13
          g.t = 0
        }
      }
    }

    g.player.offset = ease_exp(g.player.offset, 0, 8 * g.dt)

    if g.player.input_delay > 0 {
      g.player.input_delay -= g.dt

      if g.player.input_delay <= 0 && !g.tiles[g.player.position.x][g.player.position.y].clear {
        Game_start_new_room()
      }
      if g.player.input_delay <= 0 &&
         g.tiles[g.player.position.x][g.player.position.y].kind == .Castle {
        Game_set_state(.Win)
      }
    } else if !Game_in_transition() {
      if g.input.movement != 0 {
        // Keyboard input
        move_player({i32(g.input.movement.x), i32(g.input.movement.y)})
      } else {
        // Mouse input
        if is_hovered_grid({1, 1}, {MAP_SIZE + 2, MAP_SIZE + 2}) {
          mouse_grid := g.input.mouse_grid - {2, 2}
          if mouse_grid != g.player.position {
            diff := mouse_grid - g.player.position
            is_horizontal := math.abs(diff.x) >= math.abs(diff.y)

            if is_horizontal {
              if diff.x > 0 {
                g.cursor = .GoRight
              } else {
                g.cursor = .GoLeft
              }
            } else {
              if diff.y > 0 {
                g.cursor = .GoDown
              } else {
                g.cursor = .GoUp
              }
            }

            if g.input.mouse_click {
              if g.cursor == .GoRight {
                move_player({1, 0})
              } else if g.cursor == .GoLeft {
                move_player({-1, 0})
              } else if g.cursor == .GoDown {
                move_player({0, 1})
              } else if g.cursor == .GoUp {
                move_player({0, -1})
              }
            }
          }
        }
      }
    }
  }

  k2.draw_rect(Rect{4, 4, 19 * 8, 15 * 8}, to_color(.DarkGray))

  {
    // Draw map
    x, y :: 2, 2
    for i := i32(0); i < MAP_SIZE; i += 1 {
      for j := i32(0); j < MAP_SIZE; j += 1 {
        Tile_draw(g.tiles[i][j], {x + i, y + j})
      }
    }

    // Draw map border
    border_color :: proc() -> (Sprite_Color, Sprite_Color, Sprite_Color, Sprite_Color) {
      return .Brown, .Red, .Red, .DarkGray
    }
    for i := i32(0); i < MAP_SIZE; i += 1 {
      draw_sprite({2, 13}, {x - 1, y + i}, border_color())
      draw_sprite({0, 13}, {x + MAP_SIZE, y + i}, border_color())
      draw_sprite({1, 14}, {x + i, y - 1}, border_color())
      draw_sprite({1, 12}, {x + i, y + MAP_SIZE}, border_color())
    }
    draw_sprite({2, 14}, {x - 1, y - 1}, border_color())
    draw_sprite({0, 14}, {x + MAP_SIZE, y - 1}, border_color())
    draw_sprite({0, 12}, {x + MAP_SIZE, y + MAP_SIZE}, border_color())
    draw_sprite({2, 12}, {x - 1, y + MAP_SIZE}, border_color())

    // Draw player
    player_blink := math.cos(g.t * 5) < -0.85
    if !player_blink {
      // Head
      draw_sprite_offset(
        {1, 0},
        g.player.position + {x, y},
        g.player.offset - {0, 3},
        .Blue,
        .LightBlue,
        .DarkBlue,
        .DarkGray,
      )
      // Torso
      draw_sprite_offset(
        {13, 15},
        g.player.position + {x, y + 1},
        g.player.offset - {0, 4},
        .Blue,
        .LightBlue,
        .DarkBlue,
        .DarkGray,
      )
    }
  }

  draw_player_stats()
  draw_message()

  // DBG
  if k2.key_went_down(.R) {
    Game_start_new_game()
  }
  if k2.key_went_down(.M) {
    Game_set_state(.Win)
  }
  if k2.key_went_down(.N) {
    Game_set_state(.Gameover)
  }
}

//

Game_Room_init :: proc() {
  g.player.room_delay = 0
  g.player.room_cleared = false
}

Game_Room_update :: proc() {
  draw_entity_sprite :: proc(kind: EntityKind, value: i32, pos: Grid2) {
    spr: Grid2
    c0, c1, c2, c3: Sprite_Color = .Light, .Red, .Green, .Dark
    creature := false
    switch kind {
    case .Enemy1:
      spr = {12, 13}
      c0, c1, c2, c3 = .LightBlue, .Green, .Gray, .Dark
      creature = true
    case .Enemy2:
      spr = {13, 13}
      c0, c1, c2, c3 = .LightGreen, .DarkGreen, .Gray, .Dark
      creature = true
    case .Enemy3:
      spr = {14, 13}
      c0, c1, c2, c3 = .LightGray, .Gray, .Gray, .Dark
      creature = true
    case .Weapon:
      if value >= 6 {
        spr = {12, 8}
      } else {
        spr = {12, 9}
      }
    case .Heal:
      if value >= 6 {
        spr = {13, 8}
        c0, c1, c2, c3 = .Light, .Red, .DarkRed, .Dark
      } else {
        spr = {15, 9}
        c0, c1, c2, c3 = .Light, .Red, .DarkRed, .Dark
      }
    case .Armor:
      spr = {13, 9}
    case .Loot:
      if value >= 6 {
        spr = {12, 10}
        c0, c1, c2, c3 = .Light, .LightRed, .DarkRed, .Dark
      } else {
        spr = {13, 11}
        c0, c1, c2, c3 = .Light, .LightRed, .DarkRed, .Dark
      }
    }

    if creature {
      draw_sprite_offset(spr, pos, {0, -2}, c0, c1, c2, c3)
      draw_sprite_offset({13, 15}, pos + {0, 1}, {0, -2}, c0, c1, c2, c3)
    } else {
      draw_sprite(spr, pos, c0, c1, c2, c3)
    }
  }

  get_entity_name :: proc(kind: EntityKind, value: i32) -> string {
    switch kind {
    case .Enemy1:
      return "Toad"
    case .Enemy2:
      return "Goblin"
    case .Enemy3:
      return "Skeleton"
    case .Weapon:
      if value >= 6 {
        return "Battle axe"
      } else {
        return "Sword"
      }
    case .Heal:
      return "Potion"
    case .Armor:
      return "Shield"
    case .Loot:
      if value >= 6 {
        return "Treasure"
      } else {
        return "Coins"
      }
    }
    return "Error"
  }

  draw_entity :: proc(e: ^Entity, pos: Grid2) {
    draw_text_outline_centered(get_entity_name(e.kind, e.value), pos + {1, 3})
    draw_text_outline_centered(fmt.tprintf("%v", e.value), pos + {1, 4})

    hover := is_hovered_grid(pos + {-1, -1}, pos + {3, 4})

    {
      // Card background
      strong := e.value >= 10

      // Card colors
      colors :: proc(strong: bool) -> (Sprite_Color, Sprite_Color, Sprite_Color, Sprite_Color) {
        if strong {
          return .LightBrown, .Gray, .LightGray, .DarkRed
        } else {
          return .LightBrown, .Gray, .Gray, .DarkRed
        }
      }

      // Draw border corners
      draw_sprite({3, 10}, pos + {0, 0}, colors(strong))
      draw_sprite({5, 10}, pos + {2, 0}, colors(strong))
      draw_sprite({5, 12}, pos + {2, 2}, colors(strong))
      draw_sprite({3, 12}, pos + {0, 2}, colors(strong))
      // Draw border sides
      draw_sprite({3, 11}, pos + {0, 1}, colors(strong))
      draw_sprite({5, 11}, pos + {2, 1}, colors(strong))
      draw_sprite({4, 10}, pos + {1, 0}, colors(strong))
      draw_sprite({4, 12}, pos + {1, 2}, colors(strong))
      // Center
      draw_sprite({4, 11}, pos + {1, 1}, colors(strong))
    }

    if hover {
      draw_sprite_offset({14, 1}, pos + {1, 2}, {0, 2})
      g.cursor = .Pointer
    }
    // Draw entity sprite
    draw_entity_sprite(e.kind, e.value, pos + {1, 1})

    if hover && g.input.mouse_click {
      Entity_interact(e)
    }
  }

  g.player.room_cleared = count_enemies_in_room() <= 0

  k2.draw_rect(Rect{4, 4, 19 * 8, 15 * 8}, to_color(.DarkGray))

  {
    // Draw entities in the room
    positions := [4]Grid2{{3, 2}, {9, 2}, {3, 9}, {9, 9}}

    for i := 0; i < 4; i += 1 {
      if g.room[i].clear do continue
      draw_entity(&g.room[i], positions[i])
    }

    if count_entities_in_room() == 0 && g.player.room_delay <= 0 {
      g.player.room_delay = 0.3
    }
  }

  if g.player.room_delay > 0 {
    g.player.room_delay -= g.dt
    if g.player.room_delay <= 0 {
      g.player.fled_before = false
      g.tiles[g.player.position.x][g.player.position.y].clear = true
      Game_set_state(.Map)
    }
  }

  draw_player_stats()
  draw_message()

  if can_flee() && count_entities_in_room() > 0 {
    hover := is_hovered_grid({15, 11}, {18, 13})
    if hover {
      draw_sprite({12, 1}, {15, 12})
      draw_sprite({13, 1}, {18, 12})
    }
    if g.player.room_cleared {
      draw_text_outline_offset("Skip", {16, 12}, {-1, 0})
    } else {
      draw_text_outline_offset("Flee", {16, 12}, {-1, 0})
    }
    if hover && g.input.mouse_click {
      g.player.fled_before = count_enemies_in_room() > 0
      g.tiles[g.player.position.x][g.player.position.y].clear = true
      Game_set_state(.Map)
    }
  }

  if k2.key_went_down(.Q) {
    Game_set_state(.Map)
  }
}

//

Game_Win_init :: proc() {
  g.menu.game_started = false
  g.menu.win_jump_t = 0
}

Game_Win_update :: proc() {
  g.cursor = .Pointer

  {
    // You win text
    // 01234567890123456789
    //       YOU  WIN
    t := g.t
    ph := f32(0.1)
    s := f32(3)
    a := f32(4)

    draw_sprite_offset({9, 5}, {6, 4}, {0, math.sin(t * s) * a}, .LightBlue); t += ph
    draw_sprite_offset({15, 4}, {7, 4}, {0, math.sin(t * s) * a}, .LightBlue); t += ph
    draw_sprite_offset({5, 5}, {8, 4}, {0, math.sin(t * s) * a}, .LightBlue); t += ph

    draw_sprite_offset({7, 5}, {11, 4}, {0, math.sin(t * s) * a}, .LightBlue); t += ph
    draw_sprite_offset({9, 4}, {12, 4}, {0, math.sin(t * s) * a}, .LightBlue); t += ph
    draw_sprite_offset({14, 4}, {13, 4}, {0, math.sin(t * s) * a}, .LightBlue); t += ph
  }
  {
    y := math.sin(g.menu.win_jump_t * 8) * 4
    if y < 0 do y = 0

    offset: Vec2 = {4, 1}
    if is_hovered_grid({8, 6}, {10, 9}) || y > 0 {
      g.menu.win_jump_t += g.dt
      offset.y -= y
    }

    // Head
    draw_sprite_offset({1, 0}, {9, 7}, offset, .Blue, .LightBlue, .DarkBlue, .DarkGray)
    // Torso
    frame := int(math.round(g.t * 3)) % 4
    spr: Grid2 = {13, 15}
    if frame == 1 do spr = {12, 15}
    if frame == 2 do spr = {13, 15}
    if frame == 3 do spr = {14, 15}
    draw_sprite_offset(spr, {9, 8}, offset, .Blue, .LightBlue, .DarkBlue, .DarkGray)
  }
  {
    draw_sprite_offset({5, 1}, {8, 7}, {4, 2 + math.cos(g.t * 6) * 2}, .LightGreen)
    draw_sprite_offset({6, 1}, {11, 7}, {-4, 2 + math.sin(g.t * 6) * 2}, .LightGreen)
  }
  {
    draw_text_outline_centered(fmt.tprintf("Score: %v", g.player.loot), {9, 1})
    draw_text_outline_centered(
      "You safely reached the castle!",
      {9, 10},
      primary_color = .LightBlue,
    )
    draw_text_outline_centered(fmt.tprintf("You defeated %v enemies", g.player.kills), {9, 13})
    draw_text_outline_centered("Thank you for playing!", {9, 14})
  }

  if g.input.mouse_click {
    Game_set_state(.Menu)
  }
}

//

Game_Gameover_init :: proc() {
  g.menu.game_started = false
  for i := 0; i < 8; i += 1 {
    r := rand_f()
    if r < 0.5 {
      g.menu.gameover_blood[i] = 0
    } else if r > 0.9 {
      g.menu.gameover_blood[i] = 3
    } else {
      g.menu.gameover_blood[i] = chance(0.5) ? 1 : 2
    }
  }
}

Game_Gameover_update :: proc() {
  g.cursor = .Pointer

  {
    // Game over text
    // 01234567890123456789
    //      GAME  OVER
    y := math.sin(g.t * 2) * 2

    draw_sprite_offset({7, 4}, {5, 3}, {0, y}, .LightRed, c3 = .DarkRed)
    draw_sprite_offset({1, 4}, {6, 3}, {0, y}, .LightRed, c3 = .DarkRed)
    draw_sprite_offset({13, 4}, {7, 3}, {0, y}, .LightRed, c3 = .DarkRed)
    draw_sprite_offset({5, 4}, {8, 3}, {0, y}, .LightRed, c3 = .DarkRed)

    draw_sprite_offset({15, 4}, {11, 3}, {0, y}, .LightRed, c3 = .DarkRed)
    draw_sprite_offset({6, 5}, {12, 3}, {0, y}, .LightRed, c3 = .DarkRed)
    draw_sprite_offset({5, 4}, {13, 3}, {0, y}, .LightRed, c3 = .DarkRed)
    draw_sprite_offset({2, 5}, {14, 3}, {0, y}, .LightRed, c3 = .DarkRed)

    draw_blood :: proc(i: i32, pos: Grid2, offset: Vec2) {
      if i == 1 {
        draw_sprite_offset({10, 14}, pos, offset, .Red, .LightRed)
      } else if i == 2 {
        draw_sprite_offset({9, 14}, pos, offset, .Red, .LightRed)
      } else if i == 3 {
        draw_sprite_offset({10, 15}, pos, offset, .Red, .LightRed)
      }
    }
    draw_blood(g.menu.gameover_blood[0], {5, 4}, {0, y})
    draw_blood(g.menu.gameover_blood[1], {6, 4}, {0, y})
    draw_blood(g.menu.gameover_blood[2], {7, 4}, {0, y})
    draw_blood(g.menu.gameover_blood[3], {8, 4}, {0, y})

    draw_blood(g.menu.gameover_blood[4], {11, 4}, {0, y})
    draw_blood(g.menu.gameover_blood[5], {12, 4}, {0, y})
    draw_blood(g.menu.gameover_blood[6], {13, 4}, {0, y})
    draw_blood(g.menu.gameover_blood[7], {14, 4}, {0, y})
  }
  {
    draw_text_outline_centered(fmt.tprintf("Score: %v", g.player.loot), {9, 7})
    if g.player.kills == 1 {
      draw_text_outline_centered(fmt.tprintf("You defeated %v enemy", g.player.kills), {9, 11})
    } else {
      draw_text_outline_centered(fmt.tprintf("You defeated %v enemies", g.player.kills), {9, 11})
    }
    draw_text_outline_centered("You were slain", {9, 13})
    draw_text_outline_centered("Better luck next time!", {9, 14})
  }

  if g.input.mouse_click {
    Game_set_state(.Menu)
  }
}

//

Game_ui :: proc() {
}

//

can_continue :: proc() -> bool {
  return g.menu.game_started && g.player.hp > 0
}

can_flee :: proc() -> bool {
  return count_enemies_in_room() <= (g.player.fled_before ? 0 : 1)
}

count_enemies_in_room :: proc() -> i32 {
  result := i32(0)
  for i := 0; i < 4; i += 1 {
    if g.room[i].clear do continue
    k := g.room[i].kind
    if k == .Enemy1 || k == .Enemy2 || k == .Enemy3 {
      result += 1
    }
  }
  return result
}

count_entities_in_room :: proc() -> i32 {
  result := i32(0)
  for i := 0; i < 4; i += 1 {
    if g.room[i].clear do continue
    result += 1
  }
  return result
}

draw_player_stats :: proc() {
  shake :: proc(v: ^f32) -> Vec2 {
    if v^ <= 0 do return 0
    v^ -= g.dt * 0.5
    return Vec2{math.sin(v^ * 50) * 2, 0}
  }

  y := i32(2)

  // HP
  draw_sprite_offset({3, 0}, {16, y}, {-3, 0} + shake(&g.player.shake_hp))
  draw_text_outline_offset(
    fmt.tprintf("%v", g.player.hp),
    {17, y},
    {-1, 0} + shake(&g.player.shake_hp),
  )
  y += 2

  // Armor
  if g.player.had_armor {
    draw_sprite_offset({13, 9}, {16, y}, {-3, 0} + shake(&g.player.shake_armor))
    draw_text_outline_offset(
      fmt.tprintf("%v", g.player.armor),
      {17, y},
      {-1, 0} + shake(&g.player.shake_armor),
    )
    y += 2
  }

  // Weapon
  if g.player.had_weapon {
    draw_sprite_offset({12, 9}, {16, y}, {-3, 0} + shake(&g.player.shake_weapon))
    draw_text_outline_offset(
      fmt.tprintf("%v", g.player.weapon),
      {17, y},
      {-1, 0} + shake(&g.player.shake_weapon),
    )
    y += 2
  }

  // Loot
  draw_sprite_offset({14, 7}, {16, y}, {-3, 0} + shake(&g.player.shake_loot))
  draw_text_outline_offset(
    fmt.tprintf("%v", g.player.loot),
    {17, y},
    {-1, 0} + shake(&g.player.shake_loot),
  )
  y += 2
}

draw_message :: proc() {
  if g.message.time > 0 {
    g.message.time -= g.dt
    draw_text_outline(g.message.text.?, {1, 14})
  }
}
