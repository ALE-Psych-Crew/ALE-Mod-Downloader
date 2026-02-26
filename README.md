# ALE Psych Mod Downloader

> [!NOTE]
> Compatible on Android, Windows, macOS, and Linux.
> This mod now uses built-in HTTP + ZIP handling, so `curl`/`wget` are not required.

GameBanana mod downloader for **ALE Psych**.

This mod adds an in-game browser so players can search, preview, and install ALE Psych mods directly from the main menu.

## For Players (Simple Guide)

### What this does

- Opens a GameBanana mod browser inside ALE Psych.
- Lets you search mods, view details, and download/install in a few clicks.
- Installs mods into `mods/<mod_name>/` automatically.

### How to open it

1. Enable/select this mod in the ALE Psych Mods menu.
2. Go to the Main Menu.
3. Press `M` (or tap the on-screen `M` button on mobile) to open **GameBanana Mod Downloader**.

### Basic controls

- `T` - type search query
- `ENTER` - apply search / open selected mod details / confirm download
- `ESC` - cancel search, close details, or go back
- `UP` / `DOWN` - move selection
- `LEFT` / `RIGHT` - change page
- `Mouse Wheel` - scroll results
- `Click thumbnail` - open mod details
- `R` - reload current list
- `C` - open GameBanana category page in browser

### Android/mobile controls

- On mobile, on-screen buttons are created automatically:
  - `A` = accept/open/download
  - `B` = back/close
  - `L/U/R/D` = page/selection navigation
  - `T` = search mode, `R` = reload, `C` = category page
- Button layout is tuned for the engine's 1280x720 (16:9) landscape baseline and scales with resolution.
- Touching thumbnails and detail buttons also works.

### Install result

- The downloader extracts and installs to: `mods/<sanitized-mod-name>/`
- If `pack.json` is missing, it creates one automatically.
- It also writes `mod_url.txt` in the installed mod folder.

## Safety and Filtering

- Prioritizes ZIP downloads from GameBanana file options.
- Performs structure checks to make sure archives look like ALE Psych mods.
- Rejects legacy/non-ALE layouts by default (configurable in `data.json`).
- Detects nested ZIPs and tries to pick the best mod root automatically.

## Platform Compatibility

- Android: supported.
- Windows: supported.
- macOS: supported.
- Linux: supported.

The downloader now uses built-in HTTP and ZIP handling, so it does not require platform shell commands to fetch and extract mods.

## For Modders/Developers

### Project layout

- `scripts/states/MainMenuState.hx` - adds the `M` key entry point and menu hint.
- `scripts/states/ModDownloaderState.hx` - full downloader UI, networking, filtering, install pipeline.
- `data.json` - runtime behavior/config flags.

### Config (`data.json`)

```json
{
  "developerMode": true,
  "strictAleDetection": true,
  "allowLegacyPsychMods": false,
  "deleteTempOnExit": true,
  "deleteCacheOnExit": true
}
```

- `strictAleDetection`: requires ALE-style markers (like `data/data.json` and `scripts/states`/`scripts/substates`).
- `allowLegacyPsychMods`: allow old Psych-style folders (`custom_events`, `custom_notetypes`, `custom_chars`).
- `deleteTempOnExit`: removes temporary extraction/download job files.
- `deleteCacheOnExit`: removes cached thumbnails on exit.

### API usage (GameBanana)

- Mod listing and search via API v11 endpoints.
- Detail fallback includes HTML metadata parsing if profile API data is incomplete.
- Download flow:
  1. Fetch `DownloadPage`
  2. Pick best ZIP candidate
  3. Validate raw file list structure
  4. Download archive in background
  5. Extract, detect best root, install into `mods/`

### External tools used at runtime

- None required for normal operation.
- Optional fallback: if built-in ZIP extraction fails for a specific archive, the downloader can try `unzip` when available.

## Troubleshooting

- **No mods shown**: check internet connection and GameBanana availability.
- **Download failed**: check internet access and that the game can reach GameBanana.
- **Mod rejected as non-ALE**: set `allowLegacyPsychMods` to `true` (or disable strict mode) if you intentionally want legacy formats.
- **Preview images missing**: this is usually temporary network/cache behavior; reload with `R`.

## Notes

- This mod is built for ALE Psych mod category content.
- Some GameBanana uploads may still be malformed or mislabeled; filtering is strict on purpose to reduce bad installs.
