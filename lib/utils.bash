#!/usr/bin/env bash

set -euo pipefail

# Not resolved with readlink: the name of the plugin directory defines the product.
plugin_dir=$(dirname "$(dirname "${BASH_SOURCE[0]}")")

# Directory inside an installation that goes to PATH, holds the product command only.
SHIMS_DIR_NAME=shims

RELEASES_URL="https://data.services.jetbrains.com/products/releases"

# asdf does not cache version lists, the releases of a product are about 1 MB of JSON:
# they are kept for an hour, ASDF_JETBRAINS_CACHE_TTL sets seconds, 0 disables.
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/asdf-jetbrains"
CACHE_TTL="${ASDF_JETBRAINS_CACHE_TTL:-3600}"

curl_opts=(-fsSL)

fail() {
	echo -e "asdf-jetbrains: $*" >&2
	exit 1
}

# Plugin name, product code, launcher ("idea" for bin/idea.sh and Contents/MacOS/idea), command on PATH.
PRODUCTS="
clion      CL  clion             clion             CLion
datagrip   DG  datagrip          datagrip          DataGrip
dataspell  DS  dataspell         dataspell         DataSpell
gateway    GW  gateway           gateway           Gateway
goland     GO  goland            goland            GoLand
idea       IIU idea              idea              IntelliJ IDEA
ideac      IIC idea              ideac             IntelliJ IDEA Community Edition, discontinued after 2025.3
mps        MPS mps               mps               MPS
phpstorm   PS  phpstorm          phpstorm          PhpStorm
pycharm    PCP pycharm           pycharm           PyCharm
pycharmc   PCC pycharm           pycharmc          PyCharm Community Edition, discontinued after 2025.3
rider      RD  rider             rider             Rider
rubymine   RM  rubymine          rubymine          RubyMine
rustrover  RR  rustrover         rustrover         RustRover
toolbox    TBA jetbrains-toolbox jetbrains-toolbox Toolbox App, command jetbrains-toolbox
webstorm   WS  webstorm          webstorm          WebStorm
"

# IDE versions before 2016 had another numbering (IDEA 15.0.6) and are skipped, Toolbox App versions are 1.0 to 3.x.
ALL_VERSIONS_PRODUCTS="toolbox"

# Products the plugin listed before that never had a release.
DISCONTINUED_PRODUCTS="aqua clionn rideru writerside"

supported_products() {
	echo "$PRODUCTS" | awk 'NF { name = $1; $1 = $2 = $3 = $4 = ""; sub(/^ +/, ""); printf "  %-10s %s\n", name, $0 }'
}

# The product is defined by the plugin name: "asdf plugin add ideac <url>".
# "asdf plugin test" adds the prefix "asdf-test-", "jetbrains-" is allowed for clarity.
product_name() {
	local name
	name=$(basename "$plugin_dir")
	name=${name#asdf-test-}
	echo "${name#jetbrains-}"
}

configure_product() {
	local name product
	name=$(product_name)
	product=$(echo "$PRODUCTS" | awk -v name="$name" '$1 == name { print $2, $3, $4 }')

	if [ -z "$product" ]; then
		if [[ " $DISCONTINUED_PRODUCTS " == *" $name "* ]]; then
			fail "JetBrains product \"$name\" was discontinued and has no releases."
		fi
		fail "Unknown JetBrains product: \"$name\". The plugin name defines the product, supported names:\n\n$(supported_products)"
	fi

	TOOL_NAME="$name"
	read -r JETBRAINS_PRODUCT_CODE LAUNCHER COMMAND <<<"$product"

	VERSION_PATTERN="^20"
	if [[ " $ALL_VERSIONS_PRODUCTS " == *" $name "* ]]; then
		VERSION_PATTERN="."
	fi
}

# Download key of the JetBrains releases API.
platform() {
	case "$(uname -s)-$(uname -m)" in
	Linux-x86_64) echo linux ;;
	Linux-aarch64 | Linux-arm64) echo linuxARM64 ;;
	Darwin-x86_64) echo mac ;;
	Darwin-arm64) echo macM1 ;;
	*) fail "Unsupported platform: $(uname -s) $(uname -m)" ;;
	esac
}

is_mac() {
	[ "$(uname -s)" = Darwin ]
}

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

file_age() {
	local modified
	modified=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1")
	echo $(($(date +%s) - modified))
}

# Prints the cached output of the command, runs it when the cache is missing or expired.
cached() {
	local name="$1" file tmp
	shift
	file="$CACHE_DIR/$name"
	if [ "$CACHE_TTL" -gt 0 ] && [ -s "$file" ] && [ "$(file_age "$file")" -lt "$CACHE_TTL" ]; then
		cat "$file"
		return 0
	fi
	mkdir -p "$CACHE_DIR"
	tmp=$(mktemp "$file.XXXXXX")
	if "$@" >"$tmp" && [ -s "$tmp" ]; then
		mv "$tmp" "$file"
		cat "$file"
	else
		rm -f "$tmp"
		return 1
	fi
}

# Releases with a download for the current platform: "version link checksum_link" per line.
list_releases() {
	cached "releases-$JETBRAINS_PRODUCT_CODE-$(platform)" fetch_releases
}

# Called inside "if" by cached, where set -e does not work: the pipeline is the last command,
# so a failed curl or invalid JSON is the function result.
fetch_releases() {
	curl "${curl_opts[@]}" "$RELEASES_URL?code=$JETBRAINS_PRODUCT_CODE&type=release" |
		jq -r --arg code "$JETBRAINS_PRODUCT_CODE" --arg platform "$(platform)" \
			'.[$code][] | select(.downloads[$platform].link != null) |
			[.version, .downloads[$platform].link, .downloads[$platform].checksumLink // ""] | join(" ")' |
		{ grep "$VERSION_PATTERN" || true; }
}

list_all_versions() {
	list_releases | awk '{print $1}'
}

# Latest version matching the query: "2025" gives 2025.x, "2025.2" gives 2025.2.x.
latest_version() {
	local query="$1"
	list_all_versions |
		awk -v query="$query" 'query == "" || $0 "" == query "" || index($0, query ".") == 1' |
		sort_versions | tail -n1
}

sha256_of() {
	if command -v sha256sum >/dev/null; then
		sha256sum "$1"
	else
		shasum -a 256 "$1"
	fi | awk '{print $1}'
}

verify_checksum() {
	local file="$1" checksum_url="$2" expected actual
	if [ -n "${ASDF_JETBRAINS_SKIP_CHECKSUM:-}" ]; then
		echo "* ASDF_JETBRAINS_SKIP_CHECKSUM is set, skipping verification" >&2
		return 0
	fi
	if [ -z "$checksum_url" ]; then
		echo "* No checksum published, skipping verification" >&2
		return 0
	fi
	expected=$(curl "${curl_opts[@]}" "$checksum_url" | awk '{print tolower($1); exit}') ||
		fail "Could not download $checksum_url"
	actual=$(sha256_of "$file")
	[ "$actual" = "$expected" ] || fail "SHA-256 mismatch for $file: expected $expected, got $actual"
	echo "* SHA-256 checksum verified"
}

# Downloads the release and unpacks it into the directory: the tarball contents on Linux, the .app bundle on macOS.
download_release() {
	local version="$1" download_path="$2"
	local release link checksum_link file
	release=$(list_releases | awk -v version="$version" '$1 == version')
	[ -n "$release" ] || fail "$TOOL_NAME $version is not available for $(platform), see \"asdf list all $TOOL_NAME\"."
	read -r _ link checksum_link <<<"$release"

	mkdir -p "$download_path"
	file="$download_path/$(basename "$link")"
	echo "* Downloading $TOOL_NAME $version from $link..."
	curl "${curl_opts[@]}" -o "$file" "$link" || fail "Could not download $link"
	verify_checksum "$file" "$checksum_link"

	if is_mac; then
		extract_dmg "$file" "$download_path"
	else
		tar -xzf "$file" -C "$download_path" --strip-components=1 || fail "Could not extract $file"
	fi
	rm "$file"
}

extract_dmg() {
	local dmg="$1" destination="$2" mount_point app status=0
	mount_point=$(mktemp -d)
	hdiutil attach -nobrowse -noautoopen -readonly -quiet -mountpoint "$mount_point" "$dmg" ||
		fail "Could not mount $dmg"
	app=$(find "$mount_point" -maxdepth 1 -name '*.app' | head -n1)
	if [ -n "$app" ]; then
		ditto "$app" "$destination/$(basename "$app")" || status=$?
	fi
	hdiutil detach -quiet "$mount_point" || hdiutil detach -quiet -force "$mount_point" || true
	rmdir "$mount_point" 2>/dev/null || true
	[ -n "$app" ] || fail "No application found in $dmg"
	[ "$status" -eq 0 ] || fail "Could not copy $app"
}

# Launcher path relative to the installation directory: bin/idea.sh of IDEs,
# bin/jetbrains-toolbox of Toolbox App 2.6.3 and later, jetbrains-toolbox of earlier ones.
launcher_path() {
	local install_path="$1" app candidate
	if is_mac; then
		app=$(find "$install_path" -maxdepth 1 -name '*.app' | head -n1)
		[ -n "$app" ] || return 1
		candidate="$(basename "$app")/Contents/MacOS/$LAUNCHER"
		[ -x "$install_path/$candidate" ] || return 1
		echo "$candidate"
		return 0
	fi
	for candidate in "bin/$LAUNCHER.sh" "bin/$LAUNCHER" "$LAUNCHER"; do
		if [ -f "$install_path/$candidate" ] && [ -x "$install_path/$candidate" ]; then
			echo "$candidate"
			return 0
		fi
	done
	return 1
}

# Not "find -exec mv": find succeeds even when mv fails.
move_contents() {
	local entry
	for entry in "$1"/* "$1"/.[!.]*; do
		[ -e "$entry" ] || continue
		mv "$entry" "$2/" || return 1
	done
}

# asdf expects nothing left in the download directory after a failed download.
clean_download_path_on_failure() {
	local status=$?
	if [ "$status" -ne 0 ] && [ -n "${ASDF_DOWNLOAD_PATH:-}" ] && [ -d "$ASDF_DOWNLOAD_PATH" ]; then
		find "$ASDF_DOWNLOAD_PATH" -mindepth 1 -delete
	fi
	return "$status"
}

install_version() {
	local install_type="$1" version="$2" install_path="$3" launcher

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	# A chain, not a subshell: set -e does not work inside "( ... ) || ...".
	# Moved, not copied: IDEs are 1-3 GB, and asdf removes the download directory after the install
	# anyway (with --keep-download it stays empty).
	if ! {
		mkdir -p "$install_path/$SHIMS_DIR_NAME" &&
			move_contents "$ASDF_DOWNLOAD_PATH" "$install_path" &&
			launcher=$(launcher_path "$install_path") &&
			ln -sf "../$launcher" "$install_path/$SHIMS_DIR_NAME/$COMMAND"
	}; then
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	fi

	echo "$TOOL_NAME $version installation was successful!"
}

configure_product
