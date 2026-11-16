#!/usr/bin/env bash

# Both linters run, the script fails if any of them does.
status=0

shellcheck --shell=bash --external-sources bin/* lib/* scripts/* tests/*.bats || status=1

shfmt --language-dialect bash --diff bin/* lib/* scripts/* || status=1
shfmt --language-dialect bats --diff tests/*.bats || status=1

exit "$status"
