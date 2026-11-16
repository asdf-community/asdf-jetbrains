# asdf-jetbrains [![Build](https://github.com/asdf-community/asdf-jetbrains/actions/workflows/build.yml/badge.svg)](https://github.com/asdf-community/asdf-jetbrains/actions/workflows/build.yml) [![Lint](https://github.com/asdf-community/asdf-jetbrains/actions/workflows/lint.yml/badge.svg)](https://github.com/asdf-community/asdf-jetbrains/actions/workflows/lint.yml)

[JetBrains IDEs](https://www.jetbrains.com/ides/) and [Toolbox App](https://www.jetbrains.com/toolbox-app/) plugin for the [asdf version manager](https://asdf-vm.com), also works with [mise](https://mise.jdx.dev).

# Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Products](#products)
  - [Toolbox App](#toolbox-app)
- [Configuration](#configuration)
- [Upgrading from earlier versions](#upgrading-from-earlier-versions)
- [Contributing](#contributing)
- [License](#license)

# Dependencies

- `bash`, `curl`, [`jq`](https://jqlang.org).
- Linux (x86_64, ARM64): `tar`, `sha256sum`.
- macOS (Intel, Apple silicon): `hdiutil`, `ditto`, `shasum`, all part of macOS.

# Install

The plugin name defines the JetBrains product, see [Products](#products).
The same plugin can be added several times under different names.

```shell
# Add the plugin for IntelliJ IDEA
asdf plugin add idea https://github.com/asdf-community/asdf-jetbrains.git

# Show all installable versions
asdf list all idea

# Install the latest version, or the latest 2025.2.x
asdf install idea latest
asdf install idea latest:2025.2

# Set a version for the user (~/.tool-versions)
asdf set -u idea latest

# Now the 'idea' command is available
idea .
```

With mise:

```shell
mise plugins install idea https://github.com/asdf-community/asdf-jetbrains.git
mise use -g idea@latest
```

Downloads are verified with the SHA-256 checksum published by JetBrains.
On macOS the application bundle from the `.dmg` is installed into the asdf directory, not into `/Applications`.

Check [asdf](https://asdf-vm.com/guide/getting-started.html) documentation for more instructions on how to
install & manage versions.

# Products

| Plugin name | Product                                                  |
|-------------|----------------------------------------------------------|
| `clion`     | CLion                                                    |
| `datagrip`  | DataGrip                                                 |
| `dataspell` | DataSpell                                                |
| `gateway`   | Gateway                                                  |
| `goland`    | GoLand                                                   |
| `idea`      | IntelliJ IDEA                                            |
| `ideac`     | IntelliJ IDEA Community Edition, discontinued after 2025.3 |
| `mps`       | MPS                                                      |
| `phpstorm`  | PhpStorm                                                 |
| `pycharm`   | PyCharm                                                  |
| `pycharmc`  | PyCharm Community Edition, discontinued after 2025.3     |
| `rider`     | Rider                                                    |
| `rubymine`  | RubyMine                                                 |
| `rustrover` | RustRover                                                |
| `toolbox`   | Toolbox App, see [Toolbox App](#toolbox-app)               |
| `webstorm`  | WebStorm                                                 |

The name can also be prefixed with `jetbrains-`, e.g. `jetbrains-goland`; the command is `goland` anyway.
The command is the plugin name, except Toolbox App: `jetbrains-toolbox`.

The Community Editions have no releases after 2025.3, JetBrains merged them into IntelliJ IDEA and PyCharm:
use `idea` and `pycharm` for newer versions.

Only stable releases are listed, EAP builds are not.
IDE versions before 2016 used another numbering (IntelliJ IDEA 15.0.6) and are not listed.

## Toolbox App

```shell
asdf plugin add toolbox https://github.com/asdf-community/asdf-jetbrains.git
asdf install toolbox latest
asdf set -u toolbox latest
jetbrains-toolbox
```

Toolbox App runs from the asdf installation directory and keeps its data and the IDEs it installs
in `~/.local/share/JetBrains` on Linux.
On the first start it adds an autostart entry pointing to the installed version: start the new version
after `asdf install toolbox <version>`, before uninstalling the old one.

# Configuration

| Variable                       | Meaning                                                                                          |
|--------------------------------|--------------------------------------------------------------------------------------------------|
| `ASDF_JETBRAINS_SKIP_CHECKSUM` | Any non-empty value skips SHA-256 verification                                                   |
| `ASDF_JETBRAINS_CACHE_TTL`     | Seconds to keep release lists in `${XDG_CACHE_HOME:-~/.cache}/asdf-jetbrains`, 3600 by default, `0` disables |

Release lists are cached because asdf asks for them on every `asdf latest`, `asdf list all` and `asdf install`.
A new release shows up within an hour.

The downloaded files are moved into the installation, not copied, so `asdf install --keep-download`
keeps an empty download directory.

# Upgrading from earlier versions

Before 1.1.0, `asdf plugin update` and `mise plugins update` made the plugin fail with `Unknown product name`.
Updating to 1.1.0 or later fixes it, installed versions stay.
If the plugin already fails, run the update once more; do not remove the plugin, removal deletes installed versions.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/asdf-community/asdf-jetbrains/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [Maxim Butov](https://github.com/mbutov/)
