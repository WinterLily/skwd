#!/bin/bash
# Merges [color] section from skwd-colors into ~/.config/cava/config, then reloads cava
COLORS_FILE="$HOME/.config/cava/themes/noctalia"
CAVA_CONFIG="$HOME/.config/cava/config"

[ -f "$COLORS_FILE" ] || exit 0

# Create cava config if missing
mkdir -p "$(dirname "$CAVA_CONFIG")"
[ -f "$CAVA_CONFIG" ] || touch "$CAVA_CONFIG"

# Remove existing [color] section (everything from [color] to next section or EOF)
python3 - <<PYEOF
import re, os

config_path = os.path.expanduser("$CAVA_CONFIG")
colors_path = os.path.expanduser("$COLORS_FILE")

with open(config_path, 'r') as f:
    content = f.read()

# Strip existing [color] section
content = re.sub(r'\[color\].*?(?=\n\[|\Z)', '', content, flags=re.DOTALL).rstrip()

with open(colors_path, 'r') as f:
    colors = f.read().strip()

with open(config_path, 'w') as f:
    if content:
        f.write(content + '\n\n')
    f.write(colors + '\n')
PYEOF

pkill -USR1 cava 2>/dev/null || true
