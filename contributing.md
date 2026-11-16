# Contributing

Lint and format (versions of `shellcheck` and `shfmt` are in `.tool-versions`):

```shell
scripts/lint.bash
scripts/format.bash
```

Offline tests (bats, curl is replaced with release lists from `tests/fixtures`):

```shell
bats tests
```

Testing the real installation, the plugin name defines the product:

```shell
mkdir -p "${ASDF_DATA_DIR:-$HOME/.asdf}/plugins"
cp -R . "${ASDF_DATA_DIR:-$HOME/.asdf}/plugins/gateway"
asdf install gateway latest
```

`asdf plugin test` of asdf 0.16 and later does not run a test command, the build runs it itself,
see `.github/workflows/build.yml`.

A new product is a line in `PRODUCTS` in `lib/utils.bash` and a row in the README.
Product codes are listed by `https://data.services.jetbrains.com/products?fields=code,name`.

Tests are automatically run in GitHub Actions on push and PR.

Commit messages and PR titles follow [Conventional Commits](https://www.conventionalcommits.org):
releases are made by release-please from them.
