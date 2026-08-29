# uTransmission on Windows

The fork's UI changes live in two different clients. The macOS client (`macosx/`) is written in
AppKit; the Windows build runs the Qt client (`qt/`). Both have received the same three features —
a sidebar, a docked inspector and sequential download — but they are separate implementations.

This document is for testing the Windows build.

## Option 1: download a prebuilt binary (no compiler needed)

Every push to `main` builds the Qt client on Windows for x86, x64 and arm64 and uploads the result.

1. Open the [Actions tab](https://github.com/whiterabbit74/uTransmission/actions) of the repository.
2. Pick the most recent **Sanity** run on the `main` branch.
3. Scroll to **Artifacts** at the bottom of the run summary.
4. Download `binaries-windows-x64` for a plain folder of binaries, or `binaries-windows-x64-msi`
   for an installer.

Downloading artifacts requires being signed in to GitHub — an account is enough, no permissions on
the repository are needed.

The unpacked folder contains `transmission-qt.exe` next to the Qt DLLs it needs. Run it directly;
there is nothing to install.

## Option 2: build from source

### Prerequisites

* [Visual Studio 2022](https://visualstudio.microsoft.com/downloads/) (Community Edition is enough)
  with the *Desktop development with C++* workload, plus the ATL and MFC components, which the Qt
  client needs
* [CMake](https://cmake.org/download/), added to `PATH`
* [Git for Windows](https://git-scm.com/download/win)
* [vcpkg](https://github.com/microsoft/vcpkg#quick-start-windows)
* [Python](https://python.org/downloads)

### Dependencies

vcpkg installs x86 libraries by default, so ask for x64 explicitly:

```bat
vcpkg install curl zlib openssl --triplet=x64-windows
vcpkg install qtactiveqt qtsvg qttools --triplet=x64-windows
```

### Source

```bat
git clone https://github.com/whiterabbit74/uTransmission
cd uTransmission
git submodule update --init --recursive
```

The submodules are not optional; the build fails without them.

### Configure and build

```bat
cmake -B build -A x64 -DCMAKE_TOOLCHAIN_FILE="<path-to-vcpkg>\scripts\buildsystems\vcpkg.cmake" -DENABLE_QT=ON -DENABLE_GTK=OFF -DENABLE_MAC=OFF
cmake --build build --config RelWithDebInfo
```

The executable ends up in `build\qt\RelWithDebInfo\transmission-qt.exe`.

## Testing with a separate configuration

The fork deliberately keeps the upstream configuration directory, `%APPDATA%\transmission`, so that
existing settings and torrents survive. That also means it shares them with a stock Transmission Qt
installation. To test in isolation, point it somewhere else:

```bat
transmission-qt.exe --config-dir %TEMP%\utransmission-test
```

On the very first start with an empty configuration directory the client asks whether to run a local
session or connect to a remote one. Choose *Start Local Session*.

## What to look at

The three features this fork adds, and what correct behaviour looks like:

**Sidebar.** A list down the left side with `All`, `Active`, `Downloading`, `Seeding`, `Paused`,
`Finished`, `Verifying` and `Error`, each with a count of matching torrents. Clicking a row filters
the list. It shares its state with the `Show:` dropdown in the filter bar, so changing one must move
the other. `View → Sidebar` hides and shows it, and the divider between the sidebar and the list can
be dragged.

**Docked inspector.** The torrent details are docked along the bottom of the main window instead of
opening as a separate dialog, with the same `Information / Peers / Tracker / Files / Options` tabs.
It is open by default. `Torrent → Properties` toggles it, double-clicking a torrent opens it, the
divider above it can be dragged, and its contents scroll when the pane is made short. Selecting a
different torrent must update it; when the pane is hidden it should stop polling the session.

**Sequential download.** Two ways to reach it: `Torrent → Download Sequentially` for the selected
torrents, and the *Download pieces sequentially* checkbox in the inspector's `Options` tab. Both act
on the same setting, so toggling one must be reflected in the other. Enabling it makes the torrent
fetch pieces in order rather than rarest-first, which is what lets a partially downloaded video play
from the start. Worth verifying against the file's progress rather than just the checkbox state.

**Naming.** The window title and taskbar entry say `uTransmission`, and the executable carries the
fork's icon. Executable and configuration names are intentionally left alone.

## Known limitations

* The macOS sidebar also has a Tags section. The Qt client has no concept of tags or groups at all,
  so the Windows sidebar only filters by activity.
* Sidebar visibility, inspector visibility and the divider positions are not remembered between
  launches; every start uses the defaults.
* The new strings — `Sidebar`, `Download Sequentially`, `Download pieces sequentially` — are English
  only and not part of the translation catalogues.
