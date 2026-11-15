#!/usr/bin/env bash

set -euo pipefail

# Not resolved with readlink: the name of the plugin directory defines the product.
plugin_dir=$(dirname "$(dirname "${BASH_SOURCE[0]}")")

# Directory inside an installation that goes to PATH, holds the product command only.
SHIMS_DIR_NAME=shims

RELEASES_URL="https://data.services.jetbrains.com/products/releases"

curl_opts=(-fsSL)

fail() {
	echo -e "asdf-jetbrains: $*" >&2
	exit 1
}

# Plugin name, product code and launcher name ("idea" for bin/idea.sh and Contents/MacOS/idea).
PRODUCTS="
clion      CL  clion     CLion
datagrip   DG  datagrip  DataGrip
dataspell  DS  dataspell DataSpell
gateway    GW  gateway   Gateway
goland     GO  goland    GoLand
idea       IIU idea      IntelliJ IDEA
ideac      IIC idea      IntelliJ IDEA Community Edition, discontinued after 2025.3
mps        MPS mps       MPS
phpstorm   PS  phpstorm  PhpStorm
pycharm    PCP pycharm   PyCharm
pycharmc   PCC pycharm   PyCharm Community Edition, discontinued after 2025.3
rider      RD  rider     Rider
rubymine   RM  rubymine  RubyMine
rustrover  RR  rustrover RustRover
webstorm   WS  webstorm  WebStorm
"

# Products the plugin listed before that never had a release.
DISCONTINUED_PRODUCTS="aqua clionn rideru writerside"

supported_products() {
	echo "$PRODUCTS" | awk 'NF { name = $1; $1 = $2 = $3 = ""; sub(/^ +/, ""); printf "  %-10s %s\n", name, $0 }'
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
	product=$(echo "$PRODUCTS" | awk -v name="$name" '$1 == name { print $2, $3 }')

	if [ -z "$product" ]; then
		if [[ " $DISCONTINUED_PRODUCTS " == *" $name "* ]]; then
			fail "JetBrains product \"$name\" was discontinued and has no releases."
		fi
		fail "Unknown JetBrains product: \"$name\". The plugin name defines the product, supported names:\n\n$(supported_products)"
	fi

	TOOL_NAME="$name"
	read -r JETBRAINS_PRODUCT_CODE LAUNCHER <<<"$product"
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
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

# Releases with a download for the current platform: "version link checksum_link" per line.
list_releases() {
	curl "${curl_opts[@]}" "$RELEASES_URL?code=$JETBRAINS_PRODUCT_CODE&type=release" |
		jq -r --arg code "$JETBRAINS_PRODUCT_CODE" --arg platform "$(platform)" \
			'.[$code][] | select(.downloads[$platform].link != null) |
			[.version, .downloads[$platform].link, .downloads[$platform].checksumLink // ""] | join(" ")' |
		{ grep "^20" || true; }
}

list_all_versions() {
	list_releases | awk '{print $1}'
}

# Latest version matching the query: "2025" gives 2025.x, "2025.2" gives 2025.2.x.
latest_version() {
	local query="$1"
	list_all_versions |
		awk -v query="$query" 'query == "" || $0 == query || index($0, query ".") == 1' |
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

# Launcher path relative to the installation directory.
launcher_path() {
	local install_path="$1" app
	if is_mac; then
		app=$(find "$install_path" -maxdepth 1 -name '*.app' | head -n1)
		echo "$(basename "$app")/Contents/MacOS/$LAUNCHER"
	else
		echo "bin/$LAUNCHER.sh"
	fi
}

install_version() {
	local install_type="$1" version="$2" install_path="$3" launcher

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	# A chain, not a subshell: set -e does not work inside "( ... ) || ...".
	if ! {
		mkdir -p "$install_path/$SHIMS_DIR_NAME" &&
			cp -R "$ASDF_DOWNLOAD_PATH"/. "$install_path" &&
			launcher=$(launcher_path "$install_path") &&
			test -x "$install_path/$launcher" &&
			ln -sf "../$launcher" "$install_path/$SHIMS_DIR_NAME/$TOOL_NAME"
	}; then
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	fi

	echo "$TOOL_NAME $version installation was successful!"
}

configure_product
