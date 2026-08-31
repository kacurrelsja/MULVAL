#!/bin/bash


set -u
RULES="attack1.P"
FACTS="environmentNetwork.P"
CSV="benchmark_results.csv"

declare -A GOALS=(
  ["01_DMZ_Ingress"]="execCode(jump_server,admin)"
  ["02_Lateral_Credential_Reuse"]="execCode(vbackup,admin)"
  ["03_Domain_Takeover"]="domainCompromise(danieli_domain)"
  ["04_PLC_Command_Injection"]="unauthorizedControl(plc_l1_1)"
  ["05_PLC_Root_Exec"]="execCode(plc_l1_1,root)"
  ["06_PROFINET_Drive_Control"]="physicalDriveControl(jump_server,drive_area_1_1)"
  ["07_OPCUA_DoS"]="dos(internet,plc_l1_1)"
  ["08_Historian_Data_Tampering"]="processDataTampering(keba_pda_1,iba_hd)"
)

echo "scenario,goal,status,exec_time_sec,num_nodes,num_edges" > "$CSV"

run_one () {
  local NAME="$1"
  local GOAL_FLAG="$2"   # either "-g <goal>" or "" for unfiltered

  rm -f AttackGraph.pdf AttackGraph.dot AttackGraph.png

  echo ""
  echo "[*] Running Scenario: $NAME ${GOAL_FLAG:+(Goal: $GOAL_FLAG)}"

  local START END ELAPSED STATUS
  START=$(date +%s.%N)
  # shellcheck disable=SC2086
  graph_gen.sh "$FACTS" -r "$RULES" $GOAL_FLAG -v -p
  STATUS=$?
  END=$(date +%s.%N)
  ELAPSED=$(echo "$END - $START" | bc)

  if [ $STATUS -ne 0 ]; then
    echo "[-] FAILED: graph_gen.sh exited with status $STATUS for $NAME"
    echo "${NAME},${GOAL_FLAG:-<none>},FAILED,${ELAPSED},0,0" >> "$CSV"
    return 1
  fi

  if [ ! -f "AttackGraph.dot" ]; then
    echo "[-] FAILED: no AttackGraph.dot produced for $NAME (goal likely unsatisfiable)"
    echo "${NAME},${GOAL_FLAG:-<none>},UNSATISFIABLE,${ELAPSED},0,0" >> "$CSV"
    return 1
  fi

  local NODES EDGES
  NODES=$(grep -c '^"\?[0-9]' AttackGraph.dot 2>/dev/null || echo 0)
  EDGES=$(grep -c '\->' AttackGraph.dot 2>/dev/null || echo 0)

  dot -Tpdf AttackGraph.dot -o "AttackGraph_${NAME}.pdf"
  dot -Tpng AttackGraph.dot -o "AttackGraph_${NAME}.png"
  cp AttackGraph.dot "AttackGraph_${NAME}.dot"

  echo "[+] Saved: AttackGraph_${NAME}.pdf  (${ELAPSED}s, ${NODES} nodes, ${EDGES} edges)"
  echo "${NAME},${GOAL_FLAG:-<none>},OK,${ELAPSED},${NODES},${EDGES}" >> "$CSV"
}

echo "=== Generating MulVAL Attack Graphs for Danieli Scenario ==="

# Full, unfiltered graph across every attackGoal in environmentNetwork.P
run_one "00_Full_Unfiltered" ""

for NAME in "${!GOALS[@]}"; do
  run_one "$NAME" "-g ${GOALS[$NAME]}"
done

echo ""
echo "=== Done. See ${CSV} for the quantitative summary. ==="
column -s, -t "$CSV"
