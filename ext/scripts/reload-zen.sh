#!/bin/bash
# Writes @import lines for noctalia zen-browser CSS into all Zen profile chrome dirs.
# Replaces any existing content in userChrome/userContent with just the @import line,
# preserving any lines that don't reference our cache path.
CSS_CHROME="$HOME/.cache/noctalia/zen-browser/zen-userChrome.css"
CSS_CONTENT="$HOME/.cache/noctalia/zen-browser/zen-userContent.css"
LINE_CHROME="@import \"$CSS_CHROME\";"
LINE_CONTENT="@import \"$CSS_CONTENT\";"

find "$HOME/.zen" -mindepth 2 -maxdepth 2 -type d -name chrome -print0 | while IFS= read -r -d "" dir; do
    USER_CHROME="$dir/userChrome.css"
    USER_CONTENT="$dir/userContent.css"
    mkdir -p "$dir"

    # Replace file with only the @import line (clears old directly-embedded theme CSS)
    printf "%s\n" "$LINE_CHROME" > "$USER_CHROME"
    printf "%s\n" "$LINE_CONTENT" > "$USER_CONTENT"
done
