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
- Optionally remap page-navigation gestures to Option + Left/Right while Windows App is active.
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

## Navigation gesture remapping

Enable **Remap navigation gestures to ⌥← / ⌥→ in Windows App** in the menu
to send Option + Left for a left navigation swipe and Option + Right for a right
navigation swipe only while Windows App is in the foreground.
The app is identified by its bundle ID, `com.microsoft.rdc.macos`, even if its
filename is `Microsoft Remote Desktop.app`. This applies to the entire app,
including its connection overview. In other apps, navigation gestures retain
their native behavior.
The option is off by default, persists across launches, and works independently
of automatic scrolling-direction switching.

Grant ScrollPilot access under **System Settings → Privacy & Security →
Accessibility** when prompted, then choose **Reload setting** in the menu.
An enabled checkmark records your preference; a separate status line appears
if the remapper cannot run. Turn the option off to restore native navigation.

Configure **Swipe between pages** in macOS mouse/trackpad settings to generate
discrete navigation swipes (for Magic Mouse, **Swipe with two fingers**).
On a trackpad, use **Swipe with three fingers** or the three-finger variant of
**Swipe with two or three fingers**. Two-finger trackpad scrolling can be
interpreted as page navigation by individual apps, but those scroll events are
not remapped. Ordinary horizontal/vertical scrolling, zoom, rotation, and
swipes between full-screen apps are unaffected.

The decoder uses private Quartz navigation-gesture fields also described in
[WebKit's CoreGraphics test definitions](https://github.com/WebKit/WebKit/blob/main/Tools/TestRunnerShared/spi/CoreGraphicsTestSPI.h).
Compatibility needs checking after macOS updates. Unknown gesture types,
directions, and phases pass through unchanged.

### Development checks

Run `bash Tests/run.sh` for the Swift Testing suite. It compiles the gesture
sources in a temporary package and does not send input to other applications.
Build the app in Xcode as well.

For hardware validation, check both swipe directions in the remote session,
one navigation per swipe, native navigation in other apps and when disabled, both natural-scroll
settings, and switching between mouse and trackpad. Also check restart,
revoked Accessibility access, and independent automatic-scroll switching.

## Marketing website

The static Astro + custom CSS site lives in [website/](website/). See its
[development and GitHub Pages instructions](website/README.md) to run it locally
or enable deployment.
