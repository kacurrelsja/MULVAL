#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Running Counterfactual Hardened Experiment from $ROOT_DIR ==="
cd "$ROOT_DIR"

# 1. Compile configuration_hardened.json via System-1 and System-2A
"$ROOT_DIR/venv/bin/python3" "$ROOT_DIR/ot_pipeline/scripts/run_llmasp.py" \
    --input "$ROOT_DIR/ot_pipeline/counterfactual/configuration_hardened.json"

# Move the generated file to the counterfactual directory
cp "$ROOT_DIR/ot_pipeline/environmentNetwork.P" "$ROOT_DIR/ot_pipeline/counterfactual/environmentNetwork_hardened.P"

# 2. Strip any hardcoded goals to allow isolated scenario execution
sed -i '/attackGoal/d' "$ROOT_DIR/ot_pipeline/counterfactual/environmentNetwork_hardened.P"

# 3. Copy to working directory and ensure attack1.P is present
cp "$ROOT_DIR/ot_pipeline/counterfactual/environmentNetwork_hardened.P" "$ROOT_DIR/environmentNetwork.P"
cp "$ROOT_DIR/ot_pipeline/rules/attack1.P" "$ROOT_DIR/attack1.P"

# 4. Run the benchmark across all scenarios
"$ROOT_DIR/ot_pipeline/scripts/generate_all_graph.sh" "$ROOT_DIR/environmentNetwork.P" -r "$ROOT_DIR/attack1.P" -v

echo "=== Counterfactual Benchmark Completed. ==="