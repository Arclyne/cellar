# Cellar

Cellar is a native macOS app that runs Windows software on your Mac through [Wine](https://www.winehq.org). Each **bottle** is an isolated Windows environment with its own `C:` drive, settings and installed programs.

Its first goal is running Sparx Systems **Enterprise Architect** on Apple silicon Macs.

## Features

- Create bottles with a chosen Windows version.
- Install software with **recipes**: JSON files that declare the Windows version, the components to install with Winetricks, the DLL overrides, and where the installed programs live.
- Launch installed programs with a double click.
- Run any `.msi` or `.exe` installer in an existing bottle, add programs by hand, open the `C:` drive in Finder and read each bottle's log.

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

1. Download the Enterprise Architect installer from Sparx Systems: `easetup.msi` (trial) or `easetupfull.msi` (registered).
2. In Cellar, choose **Install Software**, pick **Enterprise Architect**, choose the installer and click **Install**.
3. Cellar creates a Windows 10 bottle, installs MSXML 3, MSXML 4, MDAC 2.8 and Jet 4.0, sets `*msado15` to `native,builtin`, runs the installer and adds Enterprise Architect to the bottle.

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
  "winetricksVerbs": ["msxml3", "msxml4", "mdac28", "jet40"],
  "dllOverrides": { "*msado15": "native,builtin" },
  "installerFileExtensions": ["msi", "exe"],
  "programCandidates": [
    { "displayName": "Enterprise Architect", "windowsPath": "C:\\Program Files\\Sparx Systems\\EA\\EA.exe" }
  ],
  "documentFileExtensions": ["qea", "qeax", "eap", "eapx", "feap"]
}
```

## Architecture

| Folder | Responsibility |
| --- | --- |
| `Domain` | Value types: bottles, programs, recipes, installation stages and errors |
| `Storage` | Bottle persistence, directory layout and Windows ↔ macOS path conversion |
| `Process` | Running external commands and writing their output to the bottle log |
| `Wine` | Locating Wine and Winetricks, preparing prefixes, installers, launching programs |
| `Recipes` | Loading recipes and running a full installation |
| `Library` | `BottleLibrary`, the observable state behind the UI, and its dependency wiring |
| `Views` | SwiftUI screens |

Every service sits behind a small protocol and is wired in `LibraryDependencies.live()`, so each piece can be replaced or tested in isolation.
