import os
import glob
import re

for f in glob.glob("modules/**/*.nix", recursive=True) + glob.glob("rices/**/*.nix", recursive=True):
    with open(f, "r") as file:
        content = file.read()
    
    # Replace nixos.always = { ... }: {
    content = re.sub(r'nixos\.always\s*=\s*\{[^}]*\}:\s*\{', r'nixos.always = { myconfig, ... }: { pkgs, config, lib, ... }: {', content)
    # Replace home.always = { ... }: {
    content = re.sub(r'home\.always\s*=\s*\{[^}]*\}:\s*\{', r'home.always = { myconfig, ... }: { pkgs, config, lib, ... }: {', content)
    
    # Handle the specific niri.nix case where the brace is not immediately after the colon
    content = re.sub(r'home\.always\s*=\s*\{[^}]*\}:\s*\n\s*with lib;', r'home.always = { myconfig, ... }: { pkgs, config, lib, ... }:\n    with lib;', content)

    with open(f, "w") as file:
        file.write(content)
