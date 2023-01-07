# add this file to /etc/nixos/configuration.nix: imports
{ config, pkgs, ... }:

let
  # mkpasswd -m sha-512
  passwd = "$6$Iehu.x9i7eiceV.q$X4INuNrrxGvdK546sxdt3IV9yHr90/Mxo7wuIzdowoN..jFSFjX8gHaXchfBxV4pOYM4h38pPJOeuI1X/5fon/";

  unstable = import <nixos-unstable> { };
in
{
  imports = [
    ./sys/cli.nix
  ] ++ (if (builtins.getEnv "DISPLAY") != ""
  then [
    ./sys/gui.nix
  ] else [ ]);

  nix.settings.substituters = [
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
    "https://cache.nixos.org/"
  ];

  time.timeZone = "Asia/Shanghai";
  time.hardwareClockInLocalTime = true;

  programs.zsh.enable = true;

  virtualisation.docker.enable = true;

  networking.proxy.default = "http://127.0.0.1:8889";
  networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # virt manager 是一个图形化的 virsh ，用于创建和管理虚拟机
  # https://nixos.wiki/wiki/Virt-manager
  virtualisation.libvirtd.enable = true;
  programs.dconf.enable = true;
  environment.systemPackages = with pkgs; [
    virtmanager
    vim
    git
    wget
    zsh
    unstable.tailscale
  ];
  services.tailscale.enable = true;

  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";

    # make sure tailscale is running before trying to connect to tailscale
    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];

    # set this service as a oneshot job
    serviceConfig.Type = "oneshot";

    # have the job run this shell script
    script = with pkgs; ''
      # wait for tailscaled to settle
      sleep 2

      # check if we are already authenticated to tailscale
      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ $status = "Running" ]; then # if so, then do nothing
        exit 0
      fi

      # otherwise authenticate with tailscale
      ${tailscale}/bin/tailscale up -authkey $(cat /home/martins3/.tailscale-credentials)
    '';
  };

  networking.firewall.checkReversePath = "loose";

  networking.firewall = {
    # enable the firewall
    # @todo 为什么允许了端口还是不可以
    enable = false;

    # always allow traffic from your Tailscale network
    trustedInterfaces = [ "tailscale0" ];

    # allow the Tailscale UDP port through the firewall
    allowedUDPPorts = [ config.services.tailscale.port ];

    # allow you to SSH in over the public internet
    allowedTCPPorts = [
      22 # ssh
      5201 # iperf
      8889 # clash
      8384 # syncthing
    ];
  };

  # @tod 完整的思考下如何处理 wifi 吧
  # networking.bridges.br0.interfaces = [ "wlo1" "enp4s0" ];

  users.mutableUsers = false;
  users.users.root.hashedPassword = passwd;
  users.users.martins3 = {
    isNormalUser = true;
    shell = pkgs.zsh;
    home = "/home/martins3";
    extraGroups = [ "wheel" "docker" "libvirtd" ];
    hashedPassword = passwd;
  };

  boot = {
    crashDump.enable = true;
    kernelPackages = pkgs.linuxPackages_latest;
    # nixos 的 /tmp 不是 tmpfs 的，但是我希望重启之后，/tmp 被清空
    cleanTmpDir = true;
  };

  boot.kernelParams = [
    # "transparent_hugepage=always"
    "transparent_hugepage=never"
    # https://gist.github.com/rizalp/ff74fd9ededb076e6102fc0b636bd52b
    # @todo 太随机了
    "noibpb"
    "nopti"
    "nospectre_v2"
    "nospectre_v1"
    "l1tf=off"
    "nospec_store_bypass_disable"
    "no_stf_barrier"
    "mds=off"
    "tsx=on"
    "tsx_async_abort=off"
    "mitigations=off"
  ];

  # @todo 这个设置没有任何用
  # 这里的讨论看了下，也是没用的
  # https://www.reddit.com/r/NixOS/comments/wjskae/how_can_i_change_grub_theme_from_the/
  boot.loader.grub.theme = pkgs.nixos-grub2-theme;

  services.openssh.enable = true;

  # 默认是 cgroup v2
  # systemd.enableUnifiedCgroupHierarchy = false; # cgroup v1

  services.syncthing = {
    enable = true;
    systemService = true;
    # relay.enable = true;
    user = "martins3";
    dataDir = "/home/martins3";
    overrideDevices = false;
    overrideFolders = false;
    guiAddress = "0.0.0.0:8384";
  };

  documentation.enable = true;

  # 检查方法 sudo journalctl -u earlyoom | grep sending
  services.earlyoom = {
    enable = true;
  };

  services.jenkins = {
    enable = true;
  };

  systemd.user.services.kernel = {
    enable = true;
    unitConfig = { };
    serviceConfig = {
      # User = "martins3";
      Type = "forking";
      # RemainAfterExit = true;
      ExecStart = "/home/martins3/.nix-profile/bin/tmux new-session -d -s kernel '/run/current-system/sw/bin/bash /home/martins3/.dotfiles/scripts/systemd/sync-kernel.sh'";
      Restart = "no";
    };
  };

  # systemctl --user list-timers --all
  systemd.user.timers.kernel = {
    enable = false;
    timerConfig = { OnCalendar = "*-*-* 4:00:00"; };
    wantedBy = [ "timers.target" ];
  };

  systemd.user.services.qemu = {
    enable = true;
    unitConfig = { };
    serviceConfig = {
      Type = "forking";
      ExecStart = "/home/martins3/.nix-profile/bin/tmux new-session -d -s qemu '/run/current-system/sw/bin/bash /home/martins3/.dotfiles/scripts/systemd/sync-qemu.sh'";
      Restart = "no";
    };
  };

  systemd.user.timers.qemu = {
    enable = false;
    timerConfig = { OnCalendar = "*-*-* 4:30:00"; };
    wantedBy = [ "timers.target" ];
  };

  systemd.user.services.httpd = {
    enable = true;
    description = "export home dir to LAN";
    serviceConfig = {
      WorkingDirectory = "/home/martins3/";
      Type = "simple";
      ExecStart = "/home/martins3/.nix-profile/bin/python -m http.server";
      Restart = "no";
    };
    wantedBy = [ "timers.target" ];
  };

  systemd.user.services.kernel_doc = {
    enable = true;
    description = "export kernel doc at 127.0.0.1:3434";
    serviceConfig = {
      WorkingDirectory = "/home/martins3/core/linux/Documentation/output";
      Type = "simple";
      ExecStart = "/home/martins3/.nix-profile/bin/python -m http.server 3434";
      Restart = "no";
    };
    wantedBy = [ "timers.target" ];
  };

  systemd.services.hugepage = {
    enable = true;
    description = "make user process access hugepage";
    serviceConfig = {
      Type = "simple";
      ExecStart = "/run/current-system/sw/bin/chmod o+w /dev/hugepages/";
      Restart = "no";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.iscsid = {
    enable = true;
  };
  nix.settings.experimental-features = "nix-command flakes";
  # 因为使用的最新内核，打开这个会导致更新过于频繁
  system.autoUpgrade.enable = false;

  nixpkgs.config.allowUnfree = true;
  programs.steam.enable = true;
}
