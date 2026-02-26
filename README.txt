GameBanana Mod Downloader (ALE Psych mod)

NOTE:
- Compatible on Android, Windows, macOS, and Linux.
- Uses built-in HTTP + ZIP handling (no curl/wget required).

How to use:
1) Select this mod in the ALE Psych Mods menu.
2) Go to Main Menu and press M.
3) Use T to type a search query, ENTER to apply.
4) Use arrows to select mods, ENTER to download and install.

Installed mods are extracted into: mods/<mod_name>/

Notes:
- This downloader currently prefers ZIP files.
- It tries to detect nested ZIP files and extract the best match.
- It creates pack.json automatically if missing.
- Platform support: Android, Windows, macOS, Linux.
- No external tools are required for normal download/extract flow.

Developer config:
- Edit mods/moddownloader/data.json to tweak strict ALE detection and cache cleanup behavior.
