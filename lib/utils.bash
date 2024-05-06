#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/mbutov/asdf-jetbrains"
TOOL_NAME="asdf-jetbrains"
TOOL_TEST="asdf-jetbrains --help"

fail() {
	echo -e "${TOOL_NAME}: $*"
	exit 1
}
