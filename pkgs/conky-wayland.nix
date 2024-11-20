{ pkgs, ... }:
(pkgs.conky.override {
  waylandSupport = true;
  x11Support = false;
  luaSupport = true;
  luaCairoSupport = true;
  wirelessSupport = true;
  pulseSupport = true;
  curlSupport = true;
  journalSupport = true;
  nvidiaSupport = true;
  ncursesSupport = false;
}).overrideAttrs
  (old: {
    version = "1.21.8";
    src = old.src.overrideAttrs {
      hash = "sha256-bKWy/vWqHXqE3q8N3V6HV7/EKIOZ7CwTHgQ8btYkOvM=";
    };
    cmakeFlags = old.cmakeFlags ++ [ "-DBUILD_LUA_CAIRO_XLIB=ON" ];
  })
