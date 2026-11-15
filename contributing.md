# Contributing

Lint and format (versions of `shellcheck` and `shfmt` are in `.tool-versions`):

```shell
scripts/lint.bash
scripts/format.bash
```

Testing locally, the plugin name defines the product:

```shell
asdf plugin test <plugin-name> <plugin-url> [--asdf-tool-version <version>] [--asdf-plugin-gitref <git-ref>] [test-command*]

asdf plugin test gateway https://github.com/asdf-community/asdf-jetbrains.git "gateway --version"
```

A new product is a line in `PRODUCTS` in `lib/utils.bash` and a row in the README.
Product codes are listed by `https://data.services.jetbrains.com/products?fields=code,name`.

Tests are automatically run in GitHub Actions on push and PR.

Commit messages and PR titles follow [Conventional Commits](https://www.conventionalcommits.org):
releases are made by release-please from them.
