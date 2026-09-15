# Common menu API and Menu Studio

Include `simplicity/menu.hpp` and link CMake target `simplicity_menu`. The common
header exposes Menu/MenuItem, showMenu, nativeMenusAvailable, and TouchMenu without
OS headers. Actions, toggles, radio groups, disabled items and nested menus share
one model. Menu Studio in demos/menu_demo.cpp demonstrates that model.

Desktop backends use AppKit on macOS, Win32 on Windows and GTK3 on Linux. The Linux
backend currently requires X11 or XWayland. Static SDL symbols are hidden from
GTK to avoid Unix tray symbol interposition. Mobile uses SDL-drawn TouchMenu;
`--touch-menu` previews that interface on desktop. The mobile text renderer is
basic ASCII and long menus do not scroll; accessibility integration remains future
work. The matte overlay has not yet been migrated into this API.

See [developer setup](developer-setup.md). Run `scripts/menu_demo.sh run host`
to open Menu Studio; use M/Return/right-click or the menu button. Palette choices,
guide toggling and disabled export demonstrate native state handling.

## Validation recorded September 2026

| Platform | Evidence | Remaining |
|---|---|---|
| macOS host | Five CTest tests, native menu construction/state/dispatch; manual menu interaction | Fresh developer installation |
| Fedora ARM | Five CTest tests and native GTK test under Xvfb | Fresh UTM installation; prior guest was Parallels |
| Windows x64 | Cross-compilation of demo and tests | Native runtime and clean setup |
| iPhone simulator | Menu self-tests and interactive menu checks | Fresh Xcode installation |
| Android phone emulator | Menu self-tests | Fresh SDK installation; manual visual check |

`test_menu --native` checks actual platform widgets; CTest checks shared behavior
and a headless demo smoke run. Mobile self-tests print MENU_SELF_TEST=PASS/FAIL.
Automated tests are not a claim of manual testing on every OS/version.
