#+private
package game

import k2 "../karl2d"

Sound_Kind :: enum {
  None,
  Click,
  Kill,
  Hurt,
  Flee,
  Gulp,
  Pick,
  Coin,
  Step,
  Step0,
  Step1,
  Step2,
  Step3,
  Step4,
  Gameover,
}

Music_Kind :: enum {
  Menu,
  Map,
  Room,
  Win,
}

play_sound :: proc(k: Sound_Kind) {
  if g.disable_sounds do return

  kind := k
  if kind == .Step {
    r := rand_f()
    if r < 0.2 do kind = .Step0
    if r < 0.4 do kind = .Step1
    if r < 0.6 do kind = .Step2
    if r < 0.8 do kind = .Step3
    if r < 1 do kind = .Step4
  }

  k2.play_sound(g.sounds[kind])
}

is_sounds_enabled :: proc() -> bool {
  return !g.disable_sounds
}

toggle_sounds :: proc() {
  g.disable_sounds = !g.disable_sounds
  if g.disable_sounds {
    k2.stop_audio_stream(g.musics[g.current_music])
  } else {
    k2.play_audio_stream(g.musics[.Menu])
    g.current_music = .Menu
  }
}

play_music :: proc(k: Music_Kind) {
  if g.disable_sounds do return
  if g.current_music == k do return

  stop_music()
  k2.play_audio_stream(g.musics[k])
  k2.update_audio_stream(g.musics[k])
  g.current_music = k
}

update_music :: proc() {
  if g.disable_sounds do return
  k2.update_audio_stream(g.musics[g.current_music])
}

stop_music :: proc() {
  k2.stop_audio_stream(g.musics[g.current_music])
}
