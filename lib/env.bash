#!/usr/bin/env bash

### this file will be replaced by post-plugin-add, non-replaced file will cause an error

# TOOL_NAME="..."
# TOOL_TEST="..."
# JETBRAINS_PRODUCT_CODE="..."

current_script_path=${BASH_SOURCE[0]}
current_script_dir=$(dirname "${current_script_path}")
plugin_dir=$(dirname "${current_script_dir}")
plugin_name=$(basename "${plugin_dir}")

cat <<EOF >&2
Error: Unknown product name: "${plugin_name}".

Supported products:
  - clion
  - datagrip
  - dataspell
  - gateway
  - goland
  - idea
  - ideac
  - mps
  - phpstorm
  - pycharm
  - pycharmc
  - rider
  - rideru
  - rubymine
  - webstorm

If you added the plugin with an incorrect name "${plugin_name}", please remove it using:

  asdf plugin remove ${plugin_name}

and then add with the valid one.
EOF

exit 1
