#!/bin/bash
set -u

# Resolve base directories dynamically
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OT_PIPELINE_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="${OT_RESULTS_DIR:-${OT_PIPELINE_DIR}/results}"
GRAPHS_DIR="${RESULTS_DIR}/graphs"
DOT_DIR="${RESULTS_DIR}/dot"

# Ensure output directories exist
mkdir -p "$RESULTS_DIR"
mkdir -p "$GRAPHS_DIR"
mkdir -p "$DOT_DIR"

FACTS="environmentNetwork.P"
RULES="attack1.P"
CSV="${RESULTS_DIR}/benchmark_results.csv"

# Pair of "Scenario_Name:Goal"
SCENARIOS=(
  "01_DMZ_Ingress:execCode(jump_server,admin)"
  "02_Lateral_Credential_Reuse:execCode(vbackup,admin)"
  "03_Domain_Takeover:domainCompromise(danieli_domain)"
  "04_PLC_Command_Injection:unauthorizedControl(plc_l1_1)"
  "05_PLC_Root_Exec:execCode(plc_l1_1,root)"
  "06_PROFINET_Drive_Control:physicalDriveControl(jump_server,drive_area_1_1)"
  "07_OPCUA_DoS:dos(internet,plc_l1_1)"
  "08_Historian_Data_Tampering:processDataTampering(keba_pda_1,iba_hd)"
)

echo "scenario,goal,status,exec_time_sec,num_nodes,num_edges" > "$CSV"

for item in "${SCENARIOS[@]}"; do
  NAME="${item%%:*}"
  GOAL="${item#*:}"

  # XSB caches compiled .P sources as .xwam files keyed by (mtime, size) with
  # second resolution; reusing a cache left over from the previous scenario
  # silently reuses that scenario's asserted goal.
  rm -f *.xwam AttackGraph.pdf AttackGraph.dot AttackGraph.png VERTICES.CSV ARCS.CSV

  echo ""
  echo "[*] Running Scenario: $NAME (Goal: $GOAL)"

  START=$(date +%s.%N)
  ./utils/graph_gen.sh "$FACTS" -r "$RULES" -g "$GOAL" -v -p
  STATUS=$?
  END=$(date +%s.%N)
  ELAPSED=$(echo "$END - $START" | bc)

  if [ -f "AttackGraph.dot" ]; then
    # Exact node and edge counting via MulVAL output tables
    if [ -f "VERTICES.CSV" ] && [ -f "ARCS.CSV" ]; then
      NODES=$(grep -c '[^[:space:]]' VERTICES.CSV 2>/dev/null || echo 0)
      EDGES=$(grep -c '[^[:space:]]' ARCS.CSV 2>/dev/null || echo 0)
    else
      NODES=$(grep -c -E '^[[:space:]]*"?[0-9]+"?[[:space:]]*\[' AttackGraph.dot 2>/dev/null || echo 0)
      EDGES=$(grep -c -F '->' AttackGraph.dot 2>/dev/null || echo 0)
    fi

    # Save visual formats to graphs/
    dot -Tpdf AttackGraph.dot -o "${GRAPHS_DIR}/AttackGraph_${NAME}.pdf"
    dot -Tpng AttackGraph.dot -o "${GRAPHS_DIR}/AttackGraph_${NAME}.png"

    # Save raw graph definition to dot/
    cp AttackGraph.dot "${DOT_DIR}/AttackGraph_${NAME}.dot"

    # Guard against goal leakage: the graph must be rooted at this scenario's goal.
    if ! grep -qF "1 [label=\"1:${GOAL}:" "${DOT_DIR}/AttackGraph_${NAME}.dot"; then
      echo "[-] GOAL MISMATCH for ${NAME}: root node is not ${GOAL}"
      exit 1
    fi

    # Clean local working directory intermediates
    rm -f AttackGraph.pdf AttackGraph.dot AttackGraph.png VERTICES.CSV ARCS.CSV

    echo "[+] SUCCESS: (${ELAPSED}s, ${NODES} nodes, ${EDGES} edges)"
    echo "    -> Graphs: ${GRAPHS_DIR}/AttackGraph_${NAME}.{pdf,png}"
    echo "    -> Dot:    ${DOT_DIR}/AttackGraph_${NAME}.dot"
    echo "${NAME},\"${GOAL}\",OK,${ELAPSED},${NODES},${EDGES}" >> "$CSV"
  else
    echo "[-] FAILED: No attack path derived for $NAME"
    echo "${NAME},\"${GOAL}\",UNSATISFIABLE,${ELAPSED},0,0" >> "$CSV"
  fi
done

# Sync pipeline_timing.json if present
if [ -f "pipeline_timing.json" ]; then
  cp pipeline_timing.json "${RESULTS_DIR}/pipeline_timing.json"
  echo "[+] Synced pipeline_timing.json to ${RESULTS_DIR}/"
fi

echo ""
echo "=== Summary Table (${CSV}) ==="
column -s, -t "$CSV"