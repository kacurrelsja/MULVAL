#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "================================================================="
echo "   Industrial OT Neuro-Symbolic Attack Graph Pipeline Runner    "
echo "================================================================="

# -----------------------------------------------------------------
# Step 1: System-1 & System-2A Extraction & Symbolic Completion
# -----------------------------------------------------------------
echo "[1/3] Processing topology ingestion (LLMASP + Clingo)..."

# Attempt live extraction if credentials are set; fallback to offline replay on failure
if python3 ot_pipeline/scripts/run_llmasp.py; then
    echo "[+] Knowledge base extraction and Clingo completion successful."
else
    echo "[!] Notice: Live LLM ingestion failed or key/model unavailable."
    echo "[*] Falling back to deterministic offline replay mode..."
    python3 ot_pipeline/scripts/run_llmasp.py --offline
fi

# -----------------------------------------------------------------
# Step 2: Stage Master Knowledge Base for Isolated Scenario Goals
# -----------------------------------------------------------------
echo "[2/3] Staging environmentNetwork.P and attack rules..."

if [ -f "ot_pipeline/environmentNetwork.P" ]; then
    cp ot_pipeline/environmentNetwork.P ./environmentNetwork.P
fi

if [ -f "ot_pipeline/rules/attack1.P" ]; then
    cp ot_pipeline/rules/attack1.P ./attack1.P
fi

# Strip embedded multi-goal lines so each scenario runs in strict isolation
sed -i '/attackGoal/d' ./environmentNetwork.P

# -----------------------------------------------------------------
# Step 3: Formal MulVAL Graph Generation Across All 8 Scenarios
# -----------------------------------------------------------------
echo "[3/3] Deriving causal attack graphs across operational scenarios (01 to 08)..."
chmod +x ./ot_pipeline/scripts/generate_all_graph.sh
./ot_pipeline/scripts/generate_all_graph.sh

echo "================================================================="
echo "[+] Pipeline execution completed successfully."
echo "    - Quantitative Metrics : ot_pipeline/results/benchmark_results.csv"
echo "    - Extraction Timings   : ot_pipeline/results/pipeline_timing.json"
echo "    - Visual Graphs (.pdf) : ot_pipeline/results/graphs/"
echo "    - Graphviz Dot (.dot)  : ot_pipeline/results/dot/"
echo "================================================================="