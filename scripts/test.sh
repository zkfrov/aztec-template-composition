#!/usr/bin/env bash
# Run composition and/or compilation-failure tests.
#
# Usage:
#   scripts/test.sh              # compile + composition + failure tests
#   scripts/test.sh composition  # compile + composition tests only
#   scripts/test.sh failure      # compilation failure tests only
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

composition_test_packages() {
  local toml pkg
  for toml in "$REPO_ROOT"/composition_tests/*/Nargo.toml; do
    pkg=$(
      grep -E '^name = "composition_.*_contract"' "$toml" 2>/dev/null |
        head -1 |
        sed 's/name = "\(.*\)"/\1/' ||
        true
    )
    [ -n "$pkg" ] && echo "$pkg"
  done | sort
}

run_composition_tests() {
  mapfile -t packages < <(composition_test_packages)
  if [ "${#packages[@]}" -eq 0 ]; then
    echo "ERROR: no composition test packages found under composition_tests/" >&2
    exit 1
  fi

  echo "=== Compiling composition contracts ==="
  aztec compile --workspace --force

  echo ""
  echo "=== Running composition tests ==="
  for pkg in "${packages[@]}"; do
    echo "--- aztec test --package $pkg ---"
    aztec test --package "$pkg"
  done
}

run_failure_tests() {
  echo "=== Running compilation failure tests ==="
  ./composition_failure_tests/assert_composition_failure.sh
}

case "${1:-all}" in
  all)
    run_composition_tests
    echo ""
    run_failure_tests
    echo ""
    echo "All tests passed."
    ;;
  composition)
    run_composition_tests
    echo ""
    echo "Composition tests passed."
    ;;
  failure)
    run_failure_tests
    ;;
  *)
    echo "Usage: $0 [all|composition|failure]" >&2
    exit 1
    ;;
esac
