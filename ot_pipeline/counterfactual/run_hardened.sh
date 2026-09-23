#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Running Counterfactual Hardened Experiment (deterministic, no LLM) ==="
cd "$ROOT_DIR"

FACTS_SRC="${SCRIPT_DIR}/environmentNetwork_hardened.P"
RULES_SRC="${ROOT_DIR}/ot_pipeline/rules/attack1.P"
COMMITTED_CSV="${SCRIPT_DIR}/benchmark_results_hardened.csv"
RESULTS_DIR="${OT_RESULTS_DIR:-${SCRIPT_DIR}/results}"

if [ ! -f "$FACTS_SRC" ]; then
    echo "[-] Missing committed hardened fact base: ${FACTS_SRC}" >&2
    exit 1
fi

# 1. Stage the hardened fact base for isolated scenario execution
cp "$FACTS_SRC" environmentNetwork.P
sed -i '/attackGoal/d' environmentNetwork.P

# 2. Stage the canonical attack rules
cp "$RULES_SRC" attack1.P

# 3. Run the benchmark, writing artifacts to the counterfactual results directory
OT_RESULTS_DIR="$RESULTS_DIR" "${ROOT_DIR}/ot_pipeline/scripts/generate_all_graph.sh"

# 4. Sync the benchmark table to the committed location only when writing to
#    the default counterfactual directory; an OT_RESULTS_DIR override must not
#    clobber committed artifacts.
if [ "$RESULTS_DIR" = "${SCRIPT_DIR}/results" ]; then
    cp "${RESULTS_DIR}/benchmark_results.csv" "${COMMITTED_CSV}"
    echo "[+] Hardened benchmark table synced to ${COMMITTED_CSV}"
fi

echo "=== Counterfactual Benchmark Completed. ==="
