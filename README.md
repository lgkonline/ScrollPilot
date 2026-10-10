# ScrollPilot

Use natural scrolling on your trackpad and traditional scrolling on your mouse.

macOS shows separate natural-scrolling controls for the mouse and trackpad in
System Settings, but both controls change the same system-wide setting. That
means you can't keep natural scrolling enabled for your trackpad while turning
it off for your mouse using macOS settings alone.

ScrollPilot works around this limitation. It sits in the menu bar and can
automatically switch the scrolling direction when you use a supported device:
natural scrolling for a trackpad, and traditional scrolling for a Magic Mouse.
That way, you can keep the gesture direction that feels right on each device.

## Features

- Automatically switch scrolling direction when using a trackpad or Magic Mouse.
- Toggle natural scrolling manually from the menu bar.
- Optionally launch ScrollPilot when you log in.

## Download

Download the `.app` from [Releases](https://github.com/lgkonline/ScrollPilot/releases).

## Input Monitoring permission

Automatic switching needs access to **System Settings → Privacy & Security →
Input Monitoring**. Enable automatic switching from the ScrollPilot menu to
request access, grant access in System Settings, and then restart ScrollPilot.

If an older or differently signed build is already listed but automatic
switching still does not work, quit ScrollPilot, remove the stale entry from
Input Monitoring, start the current build, and request access again. During
development, reset only ScrollPilot's Input Monitoring decision with:

```sh
tccutil reset ListenEvent io.lgk.ScrollPilot
```

## Marketing website

The static Astro + Bootstrap 6 site lives in [website/](website/). See its
[development and GitHub Pages instructions](website/README.md) to run it locally
or enable deployment.
