#!/usr/bin/env bash

_parallels_install_hints_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib/install-hints.sh
source "${_parallels_install_hints_dir}/../../lib/install-hints.sh"

parallels_install_hint() {
  simplicity_install_hint "$@"
}
