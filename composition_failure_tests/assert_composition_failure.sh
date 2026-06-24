#!/usr/bin/env bash
# Contracts in failure_contracts/ are expected to FAIL compilation.
# Each package may contain an expected_error.txt with a substring the error must contain.
#
# This harness runs standalone packages outside the root workspace so intentionally
# broken contracts do not interfere with `aztec compile --workspace`.
# Usage: ./assert_composition_failure.sh [nargo_binary]

resolve_nargo() {
    if [ -n "${NARGO:-}" ]; then
        echo "$NARGO"
        return
    fi

    if [ -n "${AZTEC_HOME:-}" ] && [ -x "$AZTEC_HOME/internal-bin/nargo" ]; then
        echo "$AZTEC_HOME/internal-bin/nargo"
        return
    fi

    if [ -x "$HOME/.aztec/current/internal-bin/nargo" ]; then
        echo "$HOME/.aztec/current/internal-bin/nargo"
        return
    fi

    echo "nargo"
}

if [ "${1:-}" != "" ]; then
    NARGO="$1"
else
    NARGO="$(resolve_nargo)"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

total_tests=0
passed_tests=0

test_compilation_failure() {
    local contract_dir=$1
    local expected_error=""
    ((total_tests++))

    if [ -f "$contract_dir/expected_error.txt" ]; then
        expected_error=$(cat "$contract_dir/expected_error.txt")
    fi

    echo "Testing: $(basename "$contract_dir")"

    local output
    output=$(cd "$contract_dir" && $NARGO check 2>&1)
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo -e "${RED}❌ FAIL: compiled successfully when it should have failed${NC}"
        return 1
    fi

    if [ -n "$expected_error" ] && ! echo "$output" | grep -qF -- "$expected_error"; then
        echo -e "${RED}❌ FAIL: compiled with wrong error. Expected substring: '$expected_error'${NC}"
        echo "  Got: $(echo "$output" | tail -3)"
        return 1
    fi

    echo -e "${GREEN}✓ PASS${NC}"
    ((passed_tests++))
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
FAILURE_CONTRACTS_DIR="$SCRIPT_DIR/failure_contracts"
WORKSPACE_MANIFEST="$REPO_ROOT/Nargo.toml"
WORKSPACE_BACKUP="$REPO_ROOT/Nargo.toml.failure-test.bak"

cleanup() {
    if [ -f "$WORKSPACE_BACKUP" ]; then
        mv -f "$WORKSPACE_BACKUP" "$WORKSPACE_MANIFEST"
    fi
}

# Recover from a previous interrupted run before doing anything else.
if [ -f "$WORKSPACE_BACKUP" ] && [ ! -f "$WORKSPACE_MANIFEST" ]; then
    mv -f "$WORKSPACE_BACKUP" "$WORKSPACE_MANIFEST"
fi

if [ ! -f "$WORKSPACE_MANIFEST" ]; then
    echo "ERROR: missing workspace manifest at $WORKSPACE_MANIFEST" >&2
    exit 1
fi

trap cleanup EXIT INT TERM

mv "$WORKSPACE_MANIFEST" "$WORKSPACE_BACKUP"

echo "Using nargo: $NARGO ($($NARGO --version | head -1))"

for contract in "$FAILURE_CONTRACTS_DIR"/*/; do
    [ -d "$contract" ] && test_compilation_failure "$contract"
done

echo ""
echo "Results: $passed_tests/$total_tests passed"
[ "$total_tests" -eq "$passed_tests" ] || exit 1
