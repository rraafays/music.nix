{
  config,
  pkgs,
  lib,
  ...
}:

let
  user = config.common.username;
  cfg = config.services.music;
  rtPackages = builtins.tryEval pkgs.linuxPackages-rt_latest;
  guitarixPkg = pkgs.guitarix.override {
    enableOptimization = true;
  };
in
{
  options.services.music = {
    enable = lib.mkEnableOption "guitar recording and live performance (PipeWire tuning and apps)";

    realtimeKernel = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        When the channel ships `linuxPackages-rt_latest`, use it for PREEMPT_RT.
        Otherwise the module still applies `preempt=full` and `threadirqs` via
        `boot.kernelParams` if this option is enabled.
      '';
    };

    sampleRate = lib.mkOption {
      type = lib.types.int;
      default = 48000;
      description = "PipeWire default sample rate (Hz).";
    };

    quantum = lib.mkOption {
      type = lib.types.int;
      default = 256;
      description = ''
        PipeWire default buffer size in frames. Lower values reduce latency at the
        cost of CPU load and xrun risk; raise if you hear dropouts.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    boot.kernelPackages = lib.mkIf (cfg.realtimeKernel && rtPackages.success) (
      lib.mkForce rtPackages.value
    );

    boot.kernelParams = lib.mkAfter (
      [ "threadirqs" ] ++ lib.optional cfg.realtimeKernel "preempt=full"
    );

    powerManagement.cpuFreqGovernor = lib.mkOverride 50 "performance";

    security = {
      rtkit.enable = true;
      pam.loginLimits = [
        {
          domain = "@audio";
          item = "rtprio";
          type = "-";
          value = "95";
        }
        {
          domain = "@audio";
          item = "memlock";
          type = "-";
          value = "unlimited";
        }
      ];
    };

    services.pulseaudio.enable = false;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      extraConfig.pipewire."90-music-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = cfg.sampleRate;
          "default.clock.quantum" = cfg.quantum;
          "default.clock.min-quantum" = 32;
          "default.clock.max-quantum" = 2048;
        };
      };
      extraConfig.pipewire-pulse."90-music-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = cfg.sampleRate;
          "default.clock.quantum" = cfg.quantum;
        };
        "pulse.properties" = {
          "pulse.min.req" = "32/${toString cfg.sampleRate}";
          "pulse.default.req" = "${toString cfg.quantum}/${toString cfg.sampleRate}";
          "pulse.min.quantum" = "32/${toString cfg.sampleRate}";
          "pulse.max.quantum" = "2048/${toString cfg.sampleRate}";
        };
      };
      extraConfig.jack."90-music-low-latency" = {
        "jack.properties" = {
          "node.latency" = "32/${toString cfg.sampleRate}";
          "node.rate" = "1/${toString cfg.sampleRate}";
        };
      };
    };

    users.users.${user} = {
      isNormalUser = lib.mkDefault true;
      extraGroups = lib.mkAfter [ "audio" ];
      packages = with pkgs; [
        carla
        gnomeExtensions.audio-switch-shortcuts
        gnome-sound-recorder
        guitarixPkg
        pwvucontrol
        reaper
        tonelib-gfx
        tonelib-jam
        tuxguitar
      ];
    };

    warnings = lib.optional (cfg.realtimeKernel && !rtPackages.success) ''
      services.music.realtimeKernel is enabled but this nixpkgs revision does not
      provide linuxPackages-rt_latest; only kernel command-line tuning is applied.
    '';
  };
}
