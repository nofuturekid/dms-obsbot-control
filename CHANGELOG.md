# Changelog

All notable changes to this widget. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.8.0] - 2026-10-25

### Added

- Startup check: the plugin only activates when `obsbot4linux` is on PATH,
  otherwise DMS shows "obsbot4linux is required" with an install hint and the
  releases link. The camera itself is not required.
- Right click on the bar icon wakes or sleeps the camera, the same as the
  Awake switch. Left click still opens the popout.
- Hovering the bar icon shows a tooltip with the camera state, the line from
  the popout header: "Tiny 2 Lite · Awake · Static".
- Mouse wheel on the bar icon zooms by 0.1 per notch (1.0 to 4.0, while the
  camera is awake); middle click switches tracking between Static and the last
  other mode (Normal Tracking until one was used). Both can be switched off on
  the settings page.
- Control Center tile: the icon wakes or sleeps the camera, the subtitle shows
  the state. A 4 × 4 tile shows the tracking modes and speed, the detail page
  the whole Tracking card (also the tracked hand). Control Center runs its own
  instance of the widget, so it starts its own `obsbot4linux watch` while open.

### Changed

- The preview dot on the bar icon also shows in vertical bars.

## [0.7.1] - 2026-10-25

### Changed

- The popout header shows the plugin's name, OBSBOT Control, and puts the
  camera model in front of its state: "Tiny 2 Lite · Awake · Static".

## [0.7.0] - 2026-10-25

### Changed

- Camera access goes through `obsbot4linux` only: one `obsbot4linux watch`
  delivers every state change at once, also changes made from the CLI or by the
  camera itself. `tiny4linux-cli` and `v4l2-ctl` are no longer used.
- The cards are stacked in two independent columns, each as high as its
  content. Collapsible cards start closed, only one is open per column, and a
  closed card lists all its settings under the title.
- Selected chips are marked by colour only, so they keep their width.
- Settings can be changed while the camera sleeps; it applies them when it
  wakes. Only framing, zoom and field of view need it awake.
- The tracked hand (left / right) moved into the Tracking card, greyed out
  outside hand tracking.
- The zoom shows two decimals, so the field of view levels read 1.15× and 1.47×.
- The preview starts from the button in its frame; hovering the running video
  offers to stop it. The switch above the frame is gone.

### Added

- Camera, Sleep, Audio and Gestures cards for the Tiny 2 Lite settings: field
  of view, status LED, mirror, invert, auto-sleep, sleep background, noise
  reduction, pickup distance, automatic gain, microphone while asleep, gesture
  switches and zoom gesture ratio.
- Factory reset with an in-place two-click confirmation.
- Custom (manual) exposure with exposure time and gain.
- Live gimbal pose in the Framing card, also while AI tracking moves it; the
  arrows step from there. Fine steps of 1°.
- The popout scrolls once it outgrows the screen.

### Removed

- Desk and Whiteboard tracking (the Tiny 2 Lite has neither).
- The zone tracking switch, until the zone can be set up from the widget.

### Fixed

- HDR switch, exposure mode and gimbal centring now show and do what the camera
  does.

## [0.6.1] - 2026-10-23

### Changed

- Registry review: theme colours and tokens only, Qt Multimedia optional (the
  preview says so when it is missing), `qt6-multimedia` listed as a dependency.

## [0.6.0] - 2026-10-23

### Added

- First release: OBSBOT Tiny 2 Lite bar widget for DankMaterialShell with
  sleep / wake, AI tracking mode and speed, HDR, exposure, image adjustments,
  gimbal and zoom, and a live preview.
