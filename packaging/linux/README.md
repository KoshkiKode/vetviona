# Linux Packaging — Vetviona

All three formats share one set of desktop-integration files that live in
`flatpak/` (the single source of truth):

| File | Purpose |
|------|---------|
| `flatpak/com.koshkikode.Vetviona.desktop` | Launcher entry (`Exec=vetviona %f`, handles `.ged` and `.vetviona`) |
| `flatpak/com.koshkikode.Vetviona.metainfo.xml` | AppStream metadata (name, description, releases) |
| `flatpak/com.koshkikode.Vetviona.mime.xml` | shared-mime-info type for `*.vetviona` backups |

The GTK application id (`app/linux/CMakeLists.txt`), the Flatpak app-id, the
desktop file name and the icon name are all **`com.koshkikode.Vetviona`**; the
executable is `vetviona`. `app/test/platform/config_consistency_test.dart`
fails if any of these drift apart.

## Debian / Ubuntu (`.deb`)

```bash
packaging/linux/deb/build_deb.sh                        # builds Flutter, then packages
SKIP_FLUTTER_BUILD=1 packaging/linux/deb/build_deb.sh   # package an existing release bundle
```

Output: `packaging/linux/vetviona_<version>_amd64.deb`. Runtime dependencies are
declared in `deb/control` (GTK 3, libsecret, GStreamer). A Secret Service
provider (GNOME Keyring or KWallet), `xdg-desktop-portal`, Avahi and BlueZ are
*recommended*: the app still runs without them, but sign-in persistence,
file dialogs, RootLoop mDNS discovery and Bluetooth discovery need them.

## Flatpak

Uses the GNOME runtime (GTK 3 ships in it) and grants only what RootLoop needs:
network, BlueZ and Avahi over D-Bus, and the Secret Service. There is **no
filesystem permission** — GEDCOM/backup import and export use the file chooser
portal.

```bash
flatpak install flathub org.gnome.Platform//51 org.gnome.Sdk//51
(cd app && flutter build linux --release --dart-define=PAID=true)
flatpak-builder --user --install --force-clean flatpak-build \
  packaging/linux/flatpak/com.koshkikode.Vetviona.yml
flatpak run com.koshkikode.Vetviona
```

Re-check the runtime branch (`runtime-version` in the manifest and in the release
workflow) whenever GNOME publishes a new stable runtime.

## Snap

`snap/snapcraft.yaml` (core22 + gnome extension, strict confinement). The
`password-manager-service`, `avahi-observe` and `avahi-control` interfaces are
not auto-connected; connect them manually when testing locally:

```bash
snap connect vetviona:password-manager-service
snap connect vetviona:avahi-observe
snap connect vetviona:avahi-control
```

The release workflow stages the Flutter bundle into `app/snap-bundle/` and the
desktop entry/icon into `app/snap/gui/` before calling snapcraft. The snap is
published as `grade: devel` until it has been reviewed on a real desktop.
