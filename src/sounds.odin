package main

import rl "vendor:raylib"
import "core:math/rand"

sounds_play :: proc (sound_id: SoundID) {
    sound := GLOBAL_STATE.assets.sounds[sound_id]

    rl.PlaySound(sound)
}

sound_play_random :: proc (min_sound_id, max_sound_id: SoundID) {
    sound_id := int(min_sound_id) + rand.int_max(int(max_sound_id) + 1)

    sounds_play(SoundID(sound_id))
}
