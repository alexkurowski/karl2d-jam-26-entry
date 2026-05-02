#+private
package game

import k2 "../karl2d"

draw_text_outline :: proc(
  str: string,
  pos: Vec2,
  font_size: f32 = 10,
  primary_color: k2.Color = k2.WHITE,
  outline_color: k2.Color = k2.BLACK,
  font: k2.Font = g.font,
) {
  k2.draw_text(str, pos + {-1, -1}, font_size, outline_color, font)
  k2.draw_text(str, pos + {-1, 0}, font_size, outline_color, font)
  k2.draw_text(str, pos + {-1, 1}, font_size, outline_color, font)
  k2.draw_text(str, pos + {0, -1}, font_size, outline_color, font)
  k2.draw_text(str, pos + {0, 1}, font_size, outline_color, font)
  k2.draw_text(str, pos + {1, -1}, font_size, outline_color, font)
  k2.draw_text(str, pos + {1, 0}, font_size, outline_color, font)
  k2.draw_text(str, pos + {1, 1}, font_size, outline_color, font)
  k2.draw_text(str, pos, font_size, primary_color, font)
}

Button_Origin :: enum {
  TopLeft,
  TopRight,
  BottomLeft,
  BottomRight,
}

draw_button :: proc(label: string, pos: Vec2, origin: Button_Origin = .TopLeft) -> bool {
  pad :: Vec2{8, 4}
  font_size :: 10
  text_size := k2.measure_text(label, font_size, g.font)
  rect := Rect{0, 0, text_size.x + pad.x * 2, text_size.y + pad.y * 2}

  switch origin {
  case .TopLeft:
    rect.x = pos.x
    rect.y = pos.y
  case .TopRight:
    rect.x = SCREEN_WIDTH - pos.x - rect.w
    rect.y = pos.y
  case .BottomLeft:
    rect.x = pos.x
    rect.y = SCREEN_HEIGHT - pos.y - rect.h
  case .BottomRight:
    rect.x = SCREEN_WIDTH - pos.x - rect.w
    rect.y = SCREEN_HEIGHT - pos.y - rect.h
  }

  text_pos := Vec2{rect.x + pad.x - 1, rect.y + pad.y}

  hover := is_hovered(rect)
  click := is_clicked(rect)

  bg_color := k2.DARK_BLUE
  if hover do bg_color = k2.BLUE
  if click do bg_color = k2.LIGHT_BLUE

  border_color := k2.WHITE
  if hover do border_color = k2.BLACK
  if click do border_color = k2.RED

  k2.draw_rect(rect, bg_color)
  k2.draw_rect_outline(rect, 1, border_color)
  draw_text_outline(label, text_pos, font_size)

  return click
}

SpriteColor :: enum u8 {
  Black,
  DarkBlue,
  DarkPurple,
  DarkGreen,
  Brown,
  DarkGray,
  LightGray,
  White,
  Red,
  Orange,
  Yellow,
  Green,
  Blue,
  Lavender,
  Pink,
  LightPeach,
}

Sprite :: enum {
  Character,
  Sword,
  Enemy1,
  Enemy2,
  Enemy3,
  Grass0,
  Grass1,
  Grass2,
  Wall0,
  Wall1,
  Heart0,
  Heart1,
}

// odinfmt: disable
sprite_index := [Sprite]Rect {
  // X Y coords:     v        v         |  v        v
  .Character = Rect{ 1 * 8 +  1 * 1 + 1,   0 * 8 +  0 * 1 + 1, 8, 8},
  .Sword     = Rect{12 * 8 + 12 * 1 + 1,   9 * 8 +  9 * 1 + 1, 8, 8},
  .Enemy1    = Rect{13 * 8 + 13 * 1 + 1,  13 * 8 + 13 * 1 + 1, 8, 8},
  .Enemy2    = Rect{12 * 8 + 12 * 1 + 1,  13 * 8 + 13 * 1 + 1, 8, 8},
  .Enemy3    = Rect{14 * 8 + 14 * 1 + 1,  13 * 8 + 13 * 1 + 1, 8, 8},
  .Grass0    = Rect{ 0 * 8 +  0 * 1 + 1,   0 * 8 +  0 * 1 + 1, 8, 8},
  .Grass1    = Rect{ 0 * 8 +  0 * 1 + 1,   2 * 8 +  2 * 1 + 1, 8, 8},
  .Grass2    = Rect{ 1 * 8 +  1 * 1 + 1,   2 * 8 +  2 * 1 + 1, 8, 8},
  .Wall0     = Rect{ 0 * 8 +  0 * 1 + 1,   0 * 8 +  0 * 1 + 1, 8, 8},
  .Wall1     = Rect{ 0 * 8 +  0 * 1 + 1,  10 * 8 + 10 * 1 + 1, 8, 8},
  .Heart1    = Rect{ 3 * 8 +  3 * 1 + 1,   0 * 8 +  0 * 1 + 1, 8, 8},
  .Heart0    = Rect{ 3 * 8 +  3 * 1 + 1,   1 * 8 +  1 * 1 + 1, 8, 8},
}
// odinfmt: enable

draw_sprite :: proc(
  spr: Sprite,
  pos: Vec2,
  fg: SpriteColor = .White,
  mg: SpriteColor = .Red,
  bg: SpriteColor = .Black,
) {
  PAD :: 0.001
  SIZE :: 8 + PAD * 2
  dest := Rect{pos.x - PAD, pos.y - PAD, SIZE, SIZE}
  k2.draw_texture_fit(g.texture, sprite_index[spr], dest, tint = [4]u8{u8(fg), u8(mg), u8(bg), 1})
}

draw_ui_sprite :: proc(spr: Sprite, pos: Vec2, tint: [4]u8 = k2.WHITE) {
  k2.draw_texture_rect(g.texture, sprite_index[spr], pos, tint = tint)
}

