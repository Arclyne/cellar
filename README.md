# Cellar

Cellar is a native macOS app that runs Windows software on your Mac through [Wine](https://www.winehq.org). Each **bottle** is an isolated Windows environment with its own `C:` drive, settings and installed programs.

Its first goal is running Sparx Systems **Enterprise Architect** on Apple silicon Macs.

## Features

- Create bottles with a chosen Windows version.
- Install software with **recipes**: JSON files that declare the Windows version, the components to install with Winetricks, the DLL overrides, and where the installed programs live.
- Launch installed programs with a double click.
- Run any `.msi` or `.exe` installer in an existing bottle, add programs by hand, open the `C:` drive in Finder and read each bottle's log.
- Show each program with the icon embedded in its `.exe`.
- Open Enterprise Architect projects from Finder with a double click: `.qea` and `.qeax` open in Enterprise Architect 17, and `.feap` in either version. When more than one bottle can open a project, such as a `.feap` with both versions installed, Cellar asks which one to use.
- Find installed programs even when the installer picks a different folder, such as `EA Trial`.
- Create app shortcuts: right-click a program and choose **Create App Shortcut…** to add an app with the program's icon to `/Applications` (or `~/Applications`). Opening it launches the program through Cellar.

## Portable apps

Programs that ship as a folder with a ready-to-run `.exe` need no installer. Create an empty bottle, copy the folder into its `C:` drive with **Open C: Drive**, and register the `.exe` with **Add Program…**.

When the program needs a recipe's Windows components, such as a portable Enterprise Architect, choose **Install Recipe Components…** in the bottle actions and pick the recipe. Cellar installs its components and library overrides without running an installer, registers the program if it sits where the recipe expects it, and opens that recipe's documents with it.

## Requirements

- macOS 14 or later
- Xcode 16 or later
- [Homebrew](https://brew.sh)
- Wine, from the macOS builds published by [Gcenx](https://github.com/Gcenx/macOS_Wine_builds/releases). The Homebrew casks are no longer available, so install it by hand:

  ```sh
  cd ~/Downloads
  curl -LO https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.16/wine-devel-11.16-osx64.tar.xz
  tar -xf wine-devel-11.16-osx64.tar.xz
  mv "Wine Devel.app" /Applications/
  xattr -drs com.apple.quarantine "/Applications/Wine Devel.app"
  ```

  Cellar also finds `Wine Stable.app`, `Wine Staging.app` and `Wine Crossover.app` in `/Applications`, and `wine` in `/opt/homebrew/bin` or `/usr/local/bin`.

- Winetricks and cabextract, used by recipes to install Windows components:

  ```sh
  brew install winetricks cabextract
  ```

- Rosetta 2 on Apple silicon:

  ```sh
  softwareupdate --install-rosetta --agree-to-license
  ```

## Building

Open `Cellar.xcodeproj` in Xcode and run the **Cellar** scheme. The app is signed to run locally, so no developer team is needed.

## Installing Enterprise Architect

Cellar has a recipe for each supported version. Install each version in its own bottle; a bottle remembers its recipe, so each version only opens its own projects.

Recipes install MSXML 4 before MSXML 3: once the native MSXML 3 is in place, Wine's installer fails on MSXML 4. The native MSXML 3 also breaks Wine's built-in MSXML 6, so Enterprise Architect 15, which uses MSXML 6 at startup, installs the native MSXML 6 too.

Enterprise Architect 15 cannot open `.eap` or `.eapx` projects in Cellar: they need the Jet 4.0 database engine, which only installs in 32-bit Wine prefixes, and Wine on macOS only creates 64-bit ones. Convert them to `.feap` with **Project Transfer** in Enterprise Architect on Windows first.

| Recipe | Installer | Components |
| --- | --- | --- |
| **Enterprise Architect 17** (64-bit) | `easetup_x64.msi` or `easetupfull_x64.msi` | MSXML 4, MSXML 3 |
| **Enterprise Architect 15** (32-bit) | `easetup.msi` or `easetupfull.msi` | MSXML 4, MSXML 3, MSXML 6 |

1. Download the installer for your version from Sparx Systems.
2. In Cellar, choose **Install Software**, pick the recipe, choose the installer and click **Install**.
3. Cellar creates a Windows 10 bottle, installs the recipe's components, sets `*msado15` to `native,builtin`, runs the installer and adds Enterprise Architect to the bottle.

## Where bottles live

```
~/Library/Application Support/Cellar/Bottles/<bottle id>/
├── cellar-bottle.json
├── cellar.log
└── drive_c/
```

## Recipes

Recipes live in `Cellar/Recipes/Definitions` and must end in `.recipe.json`:

```json
{
  "id": "sparx-enterprise-architect",
  "displayName": "Enterprise Architect",
  "summary": "Sparx Systems modeling tool.",
  "windowsVersion": "win10",
  "winetricksVerbs": ["msxml4", "msxml3"],
  "dllOverrides": { "*msado15": "native,builtin" },
  "installerFileExtensions": ["msi", "exe"],
  "programCandidates": [
    { "displayName": "Enterprise Architect", "windowsPath": "C:\\Program Files\\Sparx Systems\\EA\\EA.exe" }
  ],
  "documentFileExtensions": ["qea", "qeax", "feap"]
}
```

## Architecture

| Folder | Responsibility |
| --- | --- |
| `Domain` | Value types: bottles, programs, recipes, installation stages and errors |
| `Storage` | Bottle persistence, directory layout and Windows ↔ macOS path conversion |
| `Process` | Running external commands and writing their output to the bottle log |
| `Wine` | Locating Wine and Winetricks, preparing prefixes, installers, launching programs |
| `Recipes` | Loading recipes, running a full installation and finding the program that opens a document |
| `Icons` | Reading icons from Windows executables |
| `Library` | `BottleLibrary`, the observable state behind the UI, and its dependency wiring |
| `Views` | SwiftUI screens |

Every service sits behind a small protocol and is wired in `LibraryDependencies.live()`, so each piece can be replaced or tested in isolation.
