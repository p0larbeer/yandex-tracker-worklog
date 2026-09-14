# Yandex Tracker Worklog

Desktop client for logging time in **Yandex Tracker** (week / day views).

Prebuilt binaries: [**Releases**](../../releases) (preferred) and [Actions](../../actions) Artifacts.

| Platform | File | How to run |
|---|---|---|
| **Windows** | `*-windows-x64.zip` | Unpack → run `yandex_tracker_worklog.exe` |
| **macOS** | `*-macos.zip` | Unpack → open `yandex_tracker_worklog.app` |
| **Linux** | `*.AppImage` | `chmod +x …AppImage` → run it |

## Windows

1. Download the Windows zip from [Releases](../../releases) (or Actions Artifacts).
2. Unpack the zip anywhere.
3. Double‑click `yandex_tracker_worklog.exe`  
   (or run it from PowerShell / cmd).

If SmartScreen warns on first launch: **More info** → **Run anyway** (unsigned build).

## macOS

1. Download the macOS zip from [Releases](../../releases) and unpack.
2. First launch (unsigned): **right‑click** `yandex_tracker_worklog.app` → **Open** → confirm.
3. Later you can open it as usual from Finder / Launchpad.

Requires a recent macOS (Apple Silicon or Intel, depending on the runner that built it).

## Linux (AppImage)

1. Download the AppImage from [Releases](../../releases).
2. Make it executable and start:

```bash
chmod +x yandex-tracker-worklog-*-linux-x64.AppImage
./yandex-tracker-worklog-*-linux-x64.AppImage
```

Works on most x86_64 desktops (GTK 3). No install step.

## Build locally (optional)

Requires [Flutter](https://docs.flutter.dev/get-started/install) **3.47.4** (see `.fvmrc`).

```bash
flutter pub get
flutter build windows --release   # Windows
flutter build macos --release     # macOS
flutter build linux --release     # Linux (folder bundle; CI also packs AppImage)
```

Do not commit OAuth tokens or org IDs. Tokens stay in the OS keychain on the user machine.

## License / usage

Internal / team distribution unless stated otherwise.
