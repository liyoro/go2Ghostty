# go2Ghostty

go2Ghostty is a tiny macOS toolbar helper inspired by Go2Shell. Put the built app in Finder's toolbar, click it from a Finder window, and it opens Ghostty at that folder.

## Build

```sh
./script/build_release.sh
```

The packaged app is copied to:

```text
../Release/go2Ghostty.app
```

## Notes

- The app is an agent app (`LSUIElement=true`), so it does not appear in the Dock.
- The app icon is generated during packaging from `script/generate_icon.swift` and bundled as `Resources/AppIcon.icns`.
- On first use, macOS may ask for Automation permission to read Finder's current folder.
- If Ghostty is already running, go2Ghostty opens a new Ghostty tab by sending `Cmd+T` and pasting a `cd` command. macOS may ask for Accessibility permission for this.
- If Accessibility is not granted, it falls back to opening Ghostty with `--working-directory`, which may open a new window depending on Ghostty's behavior.
