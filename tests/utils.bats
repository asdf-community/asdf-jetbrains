#!/usr/bin/env bats

# Offline tests: curl serves the release lists in fixtures/, uname reports UNAME_S and UNAME_M.
# bats runs each test in a subshell, the stubs are called by the sourced code.
# shellcheck disable=SC2030,SC2031,SC2329

setup() {
	PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
	FIXTURES="$BATS_TEST_DIRNAME/fixtures"
	export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
	CURL_LOG="$BATS_TEST_TMPDIR/curl.log"
	touch "$CURL_LOG"
	UNAME_S=Linux
	UNAME_M=x86_64
}

uname() {
	case "$1" in
	-s) echo "$UNAME_S" ;;
	-m) echo "$UNAME_M" ;;
	esac
}

curl() {
	local url="${*: -1}"
	echo "$url" >>"$CURL_LOG"
	case "$url" in
	*"code=IIU&"*) cat "$FIXTURES/IIU.json" ;;
	*"code=TBA&"*) cat "$FIXTURES/TBA.json" ;;
	*) return 22 ;;
	esac
}

# The plugin directory name defines the product.
plugin_path() {
	ln -sfn "$PLUGIN_DIR" "$BATS_TEST_TMPDIR/$1"
	echo "$BATS_TEST_TMPDIR/$1"
}

load_plugin() {
	# shellcheck source=lib/utils.bash
	source "$(plugin_path "$1")/lib/utils.bash"
}

@test "the plugin name defines the product" {
	load_plugin idea
	[ "$TOOL_NAME $JETBRAINS_PRODUCT_CODE $LAUNCHER $COMMAND" = "idea IIU idea idea" ]
}

@test "the prefixes jetbrains- and asdf-test- are ignored" {
	load_plugin jetbrains-goland
	[ "$TOOL_NAME $JETBRAINS_PRODUCT_CODE" = "goland GO" ]
	load_plugin asdf-test-ideac
	[ "$TOOL_NAME $JETBRAINS_PRODUCT_CODE $LAUNCHER $COMMAND" = "ideac IIC idea ideac" ]
}

@test "Toolbox App has the command jetbrains-toolbox" {
	load_plugin toolbox
	[ "$JETBRAINS_PRODUCT_CODE $COMMAND" = "TBA jetbrains-toolbox" ]
}

@test "an unknown product fails with the list of products" {
	run bash -c "source '$(plugin_path foo)/lib/utils.bash'"
	[ "$status" -eq 1 ]
	[[ "$output" == *'Unknown JetBrains product: "foo"'* ]]
	[[ "$output" == *"rustrover"* ]]
}

@test "the registry name jetbrains explains how to add a product" {
	run bash -c "source '$(plugin_path jetbrains)/lib/utils.bash'"
	[ "$status" -eq 1 ]
	[[ "$output" == *"asdf plugin add idea https://github.com/asdf-community/asdf-jetbrains.git"* ]]
	[[ "$output" == *"rustrover"* ]]
}

@test "a discontinued product fails with an explanation" {
	run bash -c "source '$(plugin_path aqua)/lib/utils.bash'"
	[ "$status" -eq 1 ]
	[[ "$output" == *"was discontinued"* ]]
}

@test "platform maps OS and architecture to the download key" {
	load_plugin idea
	[ "$(UNAME_S=Linux UNAME_M=x86_64 platform)" = linux ]
	[ "$(UNAME_S=Linux UNAME_M=aarch64 platform)" = linuxARM64 ]
	[ "$(UNAME_S=Darwin UNAME_M=x86_64 platform)" = mac ]
	[ "$(UNAME_S=Darwin UNAME_M=arm64 platform)" = macM1 ]
	UNAME_S=FreeBSD run platform
	[ "$status" -eq 1 ]
}

@test "list_all_versions lists yearly versions with a download for the platform" {
	load_plugin idea
	run list_all_versions
	[ "$(echo "$output" | sort_versions | xargs echo)" = "2025.2 2025.2.6.1 2026.2.5 2026.3" ]
}

@test "list_all_versions lists all Toolbox App versions" {
	load_plugin toolbox
	run list_all_versions
	[ "$(echo "$output" | sort_versions | xargs echo)" = "1.2 1.20 2.5.4 3.9.1" ]
}

@test "list_all_versions skips versions without a download for the platform" {
	load_plugin toolbox
	UNAME_S=Linux UNAME_M=aarch64
	run list_all_versions
	[ "$(echo "$output" | sort_versions | xargs echo)" = "2.5.4 3.9.1" ]
}

@test "latest_version matches whole version components" {
	load_plugin idea
	[ "$(latest_version "")" = "2026.3" ]
	[ "$(latest_version 2026)" = "2026.3" ]
	[ "$(latest_version 2025.2)" = "2025.2.6.1" ]
	load_plugin toolbox
	[ "$(latest_version 1.2)" = "1.2" ]
	[ "$(latest_version 1)" = "1.20" ]
}

@test "release lists are cached per product and platform" {
	load_plugin idea
	list_all_versions >/dev/null
	list_all_versions >/dev/null
	[ "$(wc -l <"$CURL_LOG")" -eq 1 ]
	UNAME_M=aarch64
	list_all_versions >/dev/null
	[ "$(wc -l <"$CURL_LOG")" -eq 2 ]
}

@test "release lists are not cached with CACHE_TTL=0" {
	load_plugin idea
	CACHE_TTL=0
	list_all_versions >/dev/null
	list_all_versions >/dev/null
	[ "$(wc -l <"$CURL_LOG")" -eq 2 ]
}

@test "an invalid response is not cached" {
	load_plugin idea
	curl() { echo '{"IIU": ['; }
	run list_releases
	[ "$status" -ne 0 ]
	[ -z "$(ls -A "$CACHE_DIR")" ]
}

@test "download_release fails clearly for a version without a download" {
	load_plugin idea
	run download_release 2020.3 "$BATS_TEST_TMPDIR/download"
	[ "$status" -eq 1 ]
	[[ "$output" == *"idea 2020.3 is not available for linux"* ]]
}

@test "verify_checksum checks SHA-256" {
	load_plugin idea
	local file="$BATS_TEST_TMPDIR/idea.tar.gz" published
	echo data >"$file"
	published=$(sha256sum "$file" 2>/dev/null || shasum -a 256 "$file")
	curl() { echo "$published"; }
	run verify_checksum "$file" "https://example.com/idea.tar.gz.sha256"
	[ "$status" -eq 0 ]
	curl() { echo "0000 *idea.tar.gz"; }
	run verify_checksum "$file" "https://example.com/idea.tar.gz.sha256"
	[ "$status" -eq 1 ]
	[[ "$output" == *"SHA-256 mismatch"* ]]
	ASDF_JETBRAINS_SKIP_CHECKSUM=1 run verify_checksum "$file" "https://example.com/idea.tar.gz.sha256"
	[ "$status" -eq 0 ]
}

make_launcher() {
	mkdir -p "$(dirname "$1")"
	printf '#!/bin/sh\n' >"$1"
	chmod +x "$1"
}

@test "launcher_path prefers the native launcher of IDEs" {
	load_plugin idea
	make_launcher "$BATS_TEST_TMPDIR/install/bin/idea"
	make_launcher "$BATS_TEST_TMPDIR/install/bin/idea.sh"
	[ "$(launcher_path "$BATS_TEST_TMPDIR/install")" = "bin/idea" ]
}

@test "launcher_path falls back to bin/<launcher>.sh of older IDEs" {
	load_plugin idea
	make_launcher "$BATS_TEST_TMPDIR/install/bin/idea.sh"
	[ "$(launcher_path "$BATS_TEST_TMPDIR/install")" = "bin/idea.sh" ]
}

@test "launcher_path finds Toolbox App in bin/ and in the archive root" {
	load_plugin toolbox
	make_launcher "$BATS_TEST_TMPDIR/new/bin/jetbrains-toolbox"
	make_launcher "$BATS_TEST_TMPDIR/old/jetbrains-toolbox"
	[ "$(launcher_path "$BATS_TEST_TMPDIR/new")" = "bin/jetbrains-toolbox" ]
	[ "$(launcher_path "$BATS_TEST_TMPDIR/old")" = "jetbrains-toolbox" ]
}

@test "launcher_path finds the launcher in the .app bundle on macOS" {
	load_plugin idea
	UNAME_S=Darwin UNAME_M=arm64
	make_launcher "$BATS_TEST_TMPDIR/install/IntelliJ IDEA.app/Contents/MacOS/idea"
	[ "$(launcher_path "$BATS_TEST_TMPDIR/install")" = "IntelliJ IDEA.app/Contents/MacOS/idea" ]
}

@test "install_version moves the files and links the command" {
	load_plugin toolbox
	export ASDF_DOWNLOAD_PATH="$BATS_TEST_TMPDIR/download"
	make_launcher "$ASDF_DOWNLOAD_PATH/bin/jetbrains-toolbox"
	touch "$ASDF_DOWNLOAD_PATH/.hidden"
	run install_version version 3.9.1 "$BATS_TEST_TMPDIR/install"
	[ "$status" -eq 0 ]
	[ -x "$BATS_TEST_TMPDIR/install/shims/jetbrains-toolbox" ]
	[ -e "$BATS_TEST_TMPDIR/install/.hidden" ]
	[ -z "$(ls -A "$ASDF_DOWNLOAD_PATH")" ]
}

@test "install_version removes the installation when the launcher is missing" {
	load_plugin idea
	export ASDF_DOWNLOAD_PATH="$BATS_TEST_TMPDIR/download"
	mkdir -p "$ASDF_DOWNLOAD_PATH/lib"
	run install_version version 2026.3 "$BATS_TEST_TMPDIR/install"
	[ "$status" -eq 1 ]
	[ ! -e "$BATS_TEST_TMPDIR/install" ]
}

@test "the download directory is emptied after a failure" {
	export ASDF_DOWNLOAD_PATH="$BATS_TEST_TMPDIR/download"
	mkdir -p "$ASDF_DOWNLOAD_PATH/partial"
	touch "$ASDF_DOWNLOAD_PATH/idea.tar.gz"
	run bash -c "source '$(plugin_path idea)/lib/utils.bash'; trap clean_download_path_on_failure EXIT; false"
	[ "$status" -eq 1 ]
	[ -d "$ASDF_DOWNLOAD_PATH" ]
	[ -z "$(ls -A "$ASDF_DOWNLOAD_PATH")" ]
}

@test "help.links points to the product page" {
	run "$(plugin_path rubymine)/bin/help.links"
	[[ "$output" == *"https://www.jetbrains.com/ruby/"* ]]
}
