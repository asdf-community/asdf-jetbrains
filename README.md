<div align="center">

# asdf-jetbrains [![Build](https://github.com/mbutov/asdf-jetbrains/actions/workflows/build.yml/badge.svg)](https://github.com/mbutov/asdf-jetbrains/actions/workflows/build.yml) [![Lint](https://github.com/mbutov/asdf-jetbrains/actions/workflows/lint.yml/badge.svg)](https://github.com/mbutov/asdf-jetbrains/actions/workflows/lint.yml)

[jetbrains](https://github.com/mbutov/asdf-jetbrains) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

# Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Contributing](#contributing)
- [License](#license)

# Dependencies

**TODO: adapt this section**

- `bash`, `curl`, `tar`, and [POSIX utilities](https://pubs.opengroup.org/onlinepubs/9699919799/idx/utilities.html).
- `SOME_ENV_VAR`: set this environment variable in your shell config to load the correct version of tool x.

# Install

Plugin:

```shell
asdf plugin add jetbrains
# or
asdf plugin add jetbrains https://github.com/mbutov/asdf-jetbrains.git
```

jetbrains:

```shell
# Show all installable versions
asdf list-all jetbrains

# Install specific version
asdf install jetbrains latest

# Set a version globally (on your ~/.tool-versions file)
asdf global jetbrains latest

# Now jetbrains commands are available
asdf-jetbrains --help
```

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/mbutov/asdf-jetbrains/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [Maxim Butov](https://github.com/mbutov/)
