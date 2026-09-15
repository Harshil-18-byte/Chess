import os
import re

lib_dir = r"j:\Dev\PROJECTS\Chess\lib"

replacements = {
    r"Colors\.white70": "BoardThemes.mutedSilver",
    r"Colors\.white30": "BoardThemes.neutralGray",
    r"Colors\.white24": "BoardThemes.midSlate",
    r"Colors\.white": "BoardThemes.pureWhite",
    r"Colors\.black54": "BoardThemes.midSlate",
    r"Colors\.black45": "BoardThemes.darkCharcoal",
    r"Colors\.black87": "BoardThemes.deepVoid",
    r"Colors\.black": "BoardThemes.pitchBlack",
    r"Colors\.redAccent": "BoardThemes.dangerAlert",
    r"Colors\.red": "BoardThemes.dangerAlert",
    r"Color\(0xFFEA580C\)": "BoardThemes.brandEmber",
    r"Colors\.grey\.shade400": "BoardThemes.mutedSilver",
    r"BoardThemes\.textMuted": "BoardThemes.mutedSilver",
}

for root, _, files in os.walk(lib_dir):
    for f in files:
        if f.endswith(".dart"):
            path = os.path.join(root, f)
            with open(path, "r", encoding="utf-8") as file:
                content = file.read()
            
            new_content = content
            for pattern, repl in replacements.items():
                new_content = re.sub(pattern, repl, new_content)
                
            if new_content != content:
                with open(path, "w", encoding="utf-8") as file:
                    file.write(new_content)
                print(f"Updated {f}")
