import os
import glob
import re

for f in glob.glob("modules/**/*.nix", recursive=True):
    with open(f, "r") as file:
        content = file.read()
    
    # Remove inputs from the inner nixos/home functions
    content = content.replace("{ pkgs, config, lib, inputs, ... }", "{ pkgs, config, lib, ... }")
    content = content.replace("{ pkgs, config, lib, pkgs-unstable, inputs, ... }", "{ pkgs, config, lib, pkgs-unstable, ... }")
    
    # Add inputs to the top-level function arguments if not present
    top_level = content.split("delib.module")[0]
    if "inputs" not in top_level:
        content = re.sub(r'\{\s*delib\s*,', '{ delib, inputs,', content)

    with open(f, "w") as file:
        file.write(content)
