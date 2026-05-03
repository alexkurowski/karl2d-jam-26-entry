#+private
package game

import k2 "../karl2d"

Sprite_Color :: enum u8 {
  // 0
  Light,
  LightRed,
  Red,
  DarkRed,
  // 1
  Dark,
  LightBrown,
  Brown,
  DarkGreen,
  // 2
  Green,
  LightGreen,
  LightBlue,
  Blue,
  // 3
  DarkBlue,
  DarkGray,
  Gray,
  LightGray,
}

draw_text_outline :: proc(
  str: string,
  pos: Grid2,
  font_size: f32 = 10,
  primary_color: Sprite_Color = .Light,
  outline_color: Sprite_Color = .Dark,
  font: k2.Font = g.font,
) {
  position := Vec2{f32(pos.x) * 8 + 1, f32(pos.y) * 8 - 1}
  primary_tint := to_color(primary_color)
  outline_tint := to_color(outline_color)
  k2.draw_text(str, position + {-1, -1}, font_size, outline_tint, font)
  k2.draw_text(str, position + {-1, 0}, font_size, outline_tint, font)
  k2.draw_text(str, position + {-1, 1}, font_size, outline_tint, font)
  k2.draw_text(str, position + {0, -1}, font_size, outline_tint, font)
  k2.draw_text(str, position + {0, 1}, font_size, outline_tint, font)
  k2.draw_text(str, position + {1, -1}, font_size, outline_tint, font)
  k2.draw_text(str, position + {1, 0}, font_size, outline_tint, font)
  k2.draw_text(str, position + {1, 1}, font_size, outline_tint, font)
  k2.draw_text(str, position, font_size, primary_tint, font)
}

draw_text_outline_offset :: proc(
  str: string,
  pos: Grid2,
  offset: Vec2,
  font_size: f32 = 10,
  primary_color: Sprite_Color = .Light,
  outline_color: Sprite_Color = .Dark,
  font: k2.Font = g.font,
) {
  position := Vec2{f32(pos.x) * 8 + 1, f32(pos.y) * 8 - 1}
  primary_tint := to_color(primary_color)
  outline_tint := to_color(outline_color)
  k2.draw_text(str, position + offset + {-1, -1}, font_size, outline_tint, font)
  k2.draw_text(str, position + offset + {-1, 0}, font_size, outline_tint, font)
  k2.draw_text(str, position + offset + {-1, 1}, font_size, outline_tint, font)
  k2.draw_text(str, position + offset + {0, -1}, font_size, outline_tint, font)
  k2.draw_text(str, position + offset + {0, 1}, font_size, outline_tint, font)
  k2.draw_text(str, position + offset + {1, -1}, font_size, outline_tint, font)
  k2.draw_text(str, position + offset + {1, 0}, font_size, outline_tint, font)
  k2.draw_text(str, position + offset + {1, 1}, font_size, outline_tint, font)
  k2.draw_text(str, position + offset, font_size, primary_tint, font)
}

draw_text_outline_centered :: proc(
  str: string,
  pos: Grid2,
  font_size: f32 = 10,
  primary_color: Sprite_Color = .Light,
  outline_color: Sprite_Color = .Dark,
  font: k2.Font = g.font,
) {
  str_size := k2.measure_text(str, font_size, font)
  offset := -Vec2{str_size.x / 2 - 3, 0}

  position := Vec2{f32(pos.x) * 8 + 1, f32(pos.y) * 8 - 1}
  primary_tint := to_color(primary_color)
  outline_tint := to_color(outline_color)
  k2.draw_text(str, position + offset + {-1, -1}, font_size, outline_tint, font)
  k2.draw_text(str, position + offset + {-1, 0}, font_size, outline_tint, font)
  k2.draw_text(str, position + offset + {-1, 1}, font_size, outline_tint, font)
  k2.draw_text(str, position + offset + {0, -1}, font_size, outline_tint, font)
  k2.draw_text(str, position + offset + {0, 1}, font_size, outline_tint, font)
  k2.draw_text(str, position + offset + {1, -1}, font_size, outline_tint, font)
  k2.draw_text(str, position + offset + {1, 0}, font_size, outline_tint, font)
  k2.draw_text(str, position + offset + {1, 1}, font_size, outline_tint, font)
  k2.draw_text(str, position + offset, font_size, primary_tint, font)
}

// Button_Origin :: enum {
//   TopLeft,
//   TopRight,
//   BottomLeft,
//   BottomRight,
// }

// draw_button :: proc(label: string, pos: Vec2, origin: Button_Origin = .TopLeft) -> bool {
//   pad :: Vec2{8, 4}
//   font_size :: 10
//   text_size := k2.measure_text(label, font_size, g.font)
//   rect := Rect{0, 0, text_size.x + pad.x * 2, text_size.y + pad.y * 2}

//   switch origin {
//   case .TopLeft:
//     rect.x = pos.x
//     rect.y = pos.y
//   case .TopRight:
//     rect.x = SCREEN_WIDTH - pos.x - rect.w
//     rect.y = pos.y
//   case .BottomLeft:
//     rect.x = pos.x
//     rect.y = SCREEN_HEIGHT - pos.y - rect.h
//   case .BottomRight:
//     rect.x = SCREEN_WIDTH - pos.x - rect.w
//     rect.y = SCREEN_HEIGHT - pos.y - rect.h
//   }

//   text_pos := Vec2{rect.x + pad.x - 1, rect.y + pad.y}

//   hover := is_hovered(rect)
//   click := is_clicked(rect)

//   bg_color := k2.DARK_BLUE
//   if hover do bg_color = k2.BLUE
//   if click do bg_color = k2.LIGHT_BLUE

//   border_color := k2.WHITE
//   if hover do border_color = k2.BLACK
//   if click do border_color = k2.RED

//   k2.draw_rect(rect, bg_color)
//   k2.draw_rect_outline(rect, 1, border_color)
//   draw_text_outline(label, text_pos, font_size)

//   return click
// }

to_color :: proc(c: Sprite_Color) -> [4]u8 {
  return [4]u8{u8(c), u8(c), u8(c), u8(c)}
}

draw_sprite_offset :: proc(
  spr: Grid2,
  pos: Grid2,
  offset: Vec2,
  c0: Sprite_Color = .Light,
  c1: Sprite_Color = .Red,
  c2: Sprite_Color = .Green,
  c3: Sprite_Color = .Dark,
) {
  source :: proc(x, y: i32) -> Rect {
    GAP :: 1
    SIZE :: 8
    return Rect{GAP + f32(x) * SIZE + f32(x) * GAP, GAP + f32(y) * SIZE + f32(y) * GAP, SIZE, SIZE}
  }
  dest :: proc(x, y: i32, off: Vec2 = 0) -> Rect {
    PAD :: 0.001
    SIZE :: 8
    DRAW_SIZE :: 8 + PAD * 2
    return Rect{f32(x) * SIZE - PAD + off.x, f32(y) * SIZE - PAD + off.y, DRAW_SIZE, DRAW_SIZE}
  }
  k2.draw_texture_fit(
    g.texture,
    source(spr.x, spr.y),
    dest(pos.x, pos.y, offset),
    tint = [4]u8{u8(c0), u8(c1), u8(c2), u8(c3)},
  )
}

draw_sprite :: proc(
  spr: Grid2,
  pos: Grid2,
  c0: Sprite_Color = .Light,
  c1: Sprite_Color = .Brown,
  c2: Sprite_Color = .DarkRed,
  c3: Sprite_Color = .DarkGray,
) {
  draw_sprite_offset(spr, pos, 0, c0, c1, c2, c3)
}

draw_cursor :: proc() {
  spr: Grid2
  switch g.cursor {
  case .Regular:
    spr = Grid2{11, 0}
  case .Pointer:
    spr = Grid2{11, 1}
  case .GoRight:
    spr = Grid2{12, 0}
  case .GoLeft:
    spr = Grid2{13, 0}
  case .GoUp:
    spr = Grid2{14, 0}
  case .GoDown:
    spr = Grid2{15, 0}
  case .Disabled:
    spr = Grid2{11, 2}
  }

  draw_sprite_offset(
    spr,
    {0, 0},
    g.input.mouse_screen - Vec2{1, 1},
    .Light,
    .Brown,
    .DarkRed,
    .DarkGray,
  )
}
