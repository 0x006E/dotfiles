{ pkgs, fetchFromGitHub, ... }:
(pkgs.conky.override {
  waylandSupport = true;
  x11Support = true;
  luaSupport = true;
  luaCairoSupport = true;
  wirelessSupport = true;
  pulseSupport = true;
  curlSupport = true;
  journalSupport = true;
  nvidiaSupport = true;
  ncursesSupport = true;
}).overrideAttrs
  (old: rec {
    version = "1.21.8";
    src = fetchFromGitHub {
      owner = "brndnmtthws";
      repo = "conky";
      rev = "v${version}";
      hash = "sha256-bKWy/vWqHXqE3q8N3V6HV7/EKIOZ7CwTHgQ8btYkOvM=";
    };
    buildInputs = old.buildInputs ++ [ pkgs.gperf ];

    cmakeFlags = old.cmakeFlags ++ [ "-DBUILD_LUA_CAIRO_XLIB=ON" ];
  })
