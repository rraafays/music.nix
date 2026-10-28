# music

Guitar recording, live performance, and DAW tooling: PipeWire (low latency), ToneLib GFX/Jam, Guitarix, Carla, REAPER, TuxGuitar, and related desktop audio apps.

NixOS only. Requires **`./common`** only. Import **`./common`** before this module. Set `common.username` (and usually `common.email` / `common.home.stateVersion` if you also use Home Manager elsewhere).

Minimal host (no `./user`, no `./system`):

```nix
imports = [ ./src/common ./src/music ];
common.username = "you";
services.music.enable = true;
system.stateVersion = "26.05";
```

The module sets `users.users.<common.username>.isNormalUser` to a default of `true` if unset, adds the `audio` group, enables PipeWire (Pulse disabled), `rtkit`, `@audio` realtime PAM limits, and `nixpkgs.config.allowUnfree` (ToneLib, REAPER).

| Option | Role |
| ------ | ---- |
| `services.music.enable` | Full stack below |
| `services.music.realtimeKernel` | PREEMPT_RT kernel when the channel provides it; else `preempt=full` + `threadirqs` |
| `services.music.sampleRate` | Default PipeWire rate (default 48000 Hz) |
| `services.music.quantum` | Default buffer in frames (default 256; lower = less latency) |

Repo: `github.com/rraafays/music.nix`. On the X230T host this is submodule **`src/music`**.

On a host that also imports `./system`, PipeWire is configured here; duplicate `services.pipewire.enable` in `system/` is harmless but optional to remove.

After rebuild, log out and back in so group membership applies. Increase `services.music.quantum` if you hear dropouts during live use.
