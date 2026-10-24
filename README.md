# dms-obsbot-control

DankMaterialShell bar widget for the OBSBOT Tiny 2 Lite webcam.

![Popout with the preview off](assets/screenshot.png)

Only the **Tiny 2 Lite** is supported: the widget finds the camera by its
`/dev/v4l/by-id` name and controls it through obsbot4linux. Other OBSBOT models
are not detected.

The popout follows layout 2a from the Claude Design study: two columns at
760 px in every state, so it never jumps. Left: Preview, Framing, Picture
(HDR + exposure). Right: Tracking and Image adjustments. Each section is a card.

- header: status line with a spinner while a command is in flight, Awake switch
- preview frame (16:9, Qt Multimedia at 720p): live picture while the preview
  runs (no other app can use the camera meanwhile; it stops when the popout
  closes), otherwise a hint with one action: Start preview, Wake camera, or
  Retry when the camera or obsbot4linux can't be reached
- AI tracking mode and speed
- framing: pan/tilt d-pad and center, zoom; a manual move switches tracking to
  Static
- HDR, exposure Global/Face (remembered, the camera does not report it)
- image adjustments: brightness, contrast, saturation, sharpness, backlight
  compensation, reset to defaults
- bar icon: videocam (accent) awake, videocam_off asleep, a dot while the
  preview holds the camera, hidden while unplugged

Settings page: a tracking mode applied whenever the camera wakes up.

Camera access goes through `obsbot4linux` (not published yet):
the widget keeps one `obsbot4linux watch` running, gets every state change as an event
(also changes made from the CLI or by the camera itself) and sends commands on
its stdin. Desk and Whiteboard tracking are not available with obsbot4linux. The bar pill is hidden while no OBSBOT Tiny 2 Lite
is plugged in.

## Install

Needs `obsbot4linux` on PATH. The live preview
also needs `qt6-multimedia`; without it the preview frame says so and every
other control still works.

From the DMS plugin browser, or manually:

```sh
git clone https://github.com/nofuturekid/dms-obsbot-control.git \
    ~/.config/DankMaterialShell/plugins/obsbotControl
dms ipc call plugins enable obsbotControl
```

Then add the `obsbotControl` widget to a bar in DMS settings.
After changing QML, run `dms restart` (`plugins reload` keeps cached components).

## Update

```sh
dms plugins update obsbotControl
dms restart
```

## Development

The code was written with Claude Code (AI) and reviewed and tested on a
Tiny 2 Lite.

## License

GPL-3.0-or-later, see [LICENSE](LICENSE).
