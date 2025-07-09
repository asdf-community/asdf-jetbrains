# asdf-jetbrains [![Build](https://github.com/asdf-community/asdf-jetbrains/actions/workflows/build.yml/badge.svg)](https://github.com/asdf-community/asdf-jetbrains/actions/workflows/build.yml) [![Lint](https://github.com/asdf-community/asdf-jetbrains/actions/workflows/lint.yml/badge.svg)](https://github.com/asdf-community/asdf-jetbrains/actions/workflows/lint.yml)

[jetbrains](https://github.com/asdf-community/asdf-jetbrains) plugin for the [asdf version manager](https://asdf-vm.com).

# Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Contributing](#contributing)
- [License](#license)

# Dependencies

- `bash`, `curl`, `tar`, and [POSIX utilities](https://pubs.opengroup.org/onlinepubs/9699919799/idx/utilities.html).
- `jq` - commandline JSON processor

# Install

## Plugin:

```shell
asdf plugin add <jetbrains product> https://github.com/asdf-community/asdf-jetbrains.git
```
JetBrains products:

* clion      - CLion
* datagrip   - DataGrip
* dataspell  - DataSpell
* gateway    - Gateway
* goland     - GoLand
* idea       - IntelliJ IDEA Ultimate
* ideac      - IntelliJ IDEA Community Edition
* mps        - MPS
* phpstorm   - PhpStorm
* pycharm    - PyCharm Professional Edition
* pycharmc   - PyCharm Community Edition
* rider      - Rider
* rideru     - Rider for Unreal Engine
* rubymine   - RubyMine
* webstorm   - WebStorm

The product name can also be prefixed with `jetbrains-`, e.g. `jetbrains-ideac`, `jetbrains-goland`, etc.

Example for JetBrains IDEA Community Edition:

```shell
# Install plugin for JetBrains IDEA Community Edition
asdf plugin add ideac https://github.com/asdf-community/asdf-jetbrains.git

# Show all installable versions of JetBrains IDEA Community Edition
asdf list-all ideac

# Install specific version
asdf install ideac latest

# Set a version globally (on your ~/.tool-versions file)
asdf global ideac latest

# Now 'ideac' command is available
ideac
```

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/asdf-community/asdf-jetbrains/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [Maxim Butov](https://github.com/mbutov/)
