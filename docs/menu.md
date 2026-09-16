# Common menu API and Menu Studio

Include `simplicity/menu.hpp` and link CMake target `simplicity_menu`. The common
header exposes Menu/MenuItem, showMenu, nativeMenusAvailable, and TouchMenu without
OS headers. Actions, toggles, radio groups, disabled items and nested menus share
one model. Menu Studio in demos/menu_demo.cpp demonstrates that model.

macOS uses AppKit. iPhone uses SDL-drawn TouchMenu; `--touch-menu` previews
that interface on macOS. The mobile text renderer is basic ASCII and long menus
do not scroll; accessibility integration remains future work. The matte overlay
has not yet been migrated into this API. WebKit and Electron host menu adapters are planned around the shared C++ core.

See [developer setup](developer-setup.md). Run `scripts/menu_demo.sh run host`
to open Menu Studio; use M/Return/right-click or the menu button. Palette choices,
guide toggling and disabled export demonstrate native state handling.

## Validation recorded September 2026

| Platform | Evidence | Remaining |
|---|---|---|
| macOS host | Five CTest tests, native menu construction/state/dispatch; manual menu interaction | Fresh developer installation |
| iPhone simulator | Menu self-tests and interactive menu checks | Fresh Xcode installation |

`test_menu --native` checks actual platform widgets; CTest checks shared behavior
and a headless demo smoke run. Mobile self-tests print MENU_SELF_TEST=PASS/FAIL.
Automated tests are not a claim of manual testing on every OS/version.
