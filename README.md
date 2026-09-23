# Neuro-Symbolic Industrial Attack Graph Pipeline

An automated risk assessment pipeline for Operational Technology (OT) networks in industrial manufacturing (Danieli reference architecture).

The framework couples **neural information extraction (LLMs)** with **symbolic deduction (ASP via Clingo)** and **formal attack graph generation (MulVAL / XSB Prolog)** to map cyber-physical attack paths across Purdue Model zones without manual fact authoring or generative hallucinations.

---

## Quick Navigation

1. [Installation & Setup](#installation--setup)
   - [Option A: Docker (Recommended)](#option-a-docker-recommended)
   - [Option B: Local Installation (Ubuntu 22.04 / 24.04)](#option-b-local-installation-ubuntu-2204--2404)
2. [How It Works](#how-it-works)
3. [Running the Pipeline](#running-the-pipeline)
4. [Counterfactual Hardening Experiment](#counterfactual-hardening-experiment)
5. [Customization & Extension Guide](#customization--extension-guide)
6. [Artifacts & Results](#artifacts--results)

---

## Installation & Setup

### Option A: Docker (Recommended)

Docker packages all legacy C++ compiler patches, XSB Prolog binaries, Clingo, and Graphviz dependencies without polluting your local system.

1. **Build the container image:**
```bash
docker build -t mulval-pipeline .

```


2. **Run an interactive shell inside the container:**
```bash
docker run -it --rm \
  -v "$(pwd)/ot_pipeline/results:/root/mulval/ot_pipeline/results" \
  mulval-pipeline /bin/bash

```


*(The `-v` flag mounts your host's results directory so generated graphs, CSVs, and timing profiles persist on your machine).*

---

### Option B: Local Installation (Ubuntu 22.04 / 24.04)

If you are running directly on an Ubuntu VM or bare metal:

1. **Install system packages & build tools:**
```bash
sudo apt update
sudo apt install -y \
  autoconf bison flex gcc g++ make graphviz default-jdk git curl bc \
  bsdmainutils ca-certificates python3 python3-pip python3-venv

```


2. **Set up Python Virtual Environment:**
```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install clingo==5.7.0 pyyaml openai pandas

```


3. **Install & Compile XSB Prolog:**
```bash
cd ~
git clone --depth 1 https://git.code.sf.net/p/xsb/code XSB_SRC
cd XSB_SRC/XSB/build
./configure && ./makexsb
mkdir -p ~/XSB/bin
cp -r ~/XSB_SRC/XSB/* ~/XSB/

```


Add to `~/.bashrc`:
```bash
export XSB_DIR=~/XSB
export PATH="$PATH:$XSB_DIR/bin"

```


4. **Compile Local MulVAL Toolchain:**
In the repository root:
```bash
export MULVALROOT=$(pwd)
export PATH="$PATH:$MULVALROOT/bin:$MULVALROOT/utils"
make clean || true
make

```



---

## API & Environment Configuration

The pipeline supports both **live neural extraction** and **offline replay**:

```bash
# 1. Create your local .env configuration from the template
cp .env.example .env

```

Open `.env` and set your credentials:

```ini
GROQ_API_KEY=gsk_your_groq_api_key_here
LLM_MODEL=llama-3.1-8b-instant
LLM_BASE_URL=https://api.groq.com/openai/v1

```

> **Zero-Config Offline Replay:** If no `GROQ_API_KEY` is specified in `.env`, the pipeline automatically falls back to deterministic replay using cached System-1 extractions (`ot_pipeline/results/cached_system1_facts.json`). Reviewers can test the entire pipeline out-of-the-box without an active API key.

---

## How It Works

The architecture follows a decoupled neuro-symbolic workflow:

```
[ Plant Configuration ] (ot_pipeline/configs/configuration.json)
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│ 1. System-1: Neural Primitive Extraction                    │
│    Prompt-sliced LLM extracts explicit Datalog atoms        │
│    (hosts, services, credentials, ACLs, fieldbus links)    │
└──────────────────────────┬──────────────────────────────────┘
                           │ Raw Facts
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. System-2A: Symbolic Inductive Completion (Clingo ASP)    │
│    Computes transitive closures (credential reuse, domain   │
│    identities, L2 fieldbus relationships) - zero hallucination│
└──────────────────────────┬──────────────────────────────────┘
                            │ Validated Ground Datalog Facts
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. System-2B: Formal Attack Graph Derivation (MulVAL / XSB) │
│    Horn-clause SLG resolution against OT interaction rules  │
│    evaluates 8 multi-hop operational attack scenarios      │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
[ Attack Graphs (.dot, .pdf, .png) & Quantitative Metrics (.csv) ]

```

1. **System-1 (Neural Extraction):** Slices `configuration.json` into isolated conceptual domains using prompt templates defined in `ot_pipeline/application_ot.yaml`. It extracts raw Datalog primitives like `vulHost/5`, `aclNW/4`, and `l2Connection/5`.
2. **System-2A (Symbolic Completion):** Feeds raw primitives into Clingo (Answer Set Programming). ASP rules compute transitive closures—such as cross-host `sameCredentials/2` propagation and domain controller privileges—producing a sound, fully completed fact base (`environmentNetwork.P`).
3. **System-2B (MulVAL Attack Graph Engine):** Combines completed network facts with formal OT interaction rules (`attack1.P`). MulVAL and XSB Prolog derive directional causal attack graphs illustrating how an attacker moves from external networks to critical plant assets (PLCs, drives, and data loggers).

---

## Running the Pipeline

Execute the master workflow script:

```bash
chmod +x run_pipeline.sh
./run_pipeline.sh

```

### What this executes:

1. Runs `ot_pipeline/scripts/run_llmasp.py` to produce `environmentNetwork.P`.
2. Executes `ot_pipeline/scripts/generate_all_graph.sh` across all 8 evaluation attack scenarios.
3. Automatically isolates attack goals, runs MulVAL resolution, renders Graphviz visualizations, and populates `benchmark_results.csv`.

> **Reproducibility note:** every benchmark run clears stale XSB `.xwam` compilation caches and verifies that each generated graph is rooted at the current scenario's goal, so consecutive runs can never inherit a previous goal. Execution times in `benchmark_results.csv` depend on the host CPU and are not reproducible across machines; graph structure (node/edge counts) is deterministic for a given fact base.

---

## Counterfactual Hardening Experiment

A counterfactual variant of the Danieli plant configuration is committed under `ot_pipeline/counterfactual/`. Relative to the baseline, it removes three firewall conduits:

| Source | Destination | Protocol / Port | Effect |
| --- | --- | --- | --- |
| `jump_server` | `plc_l1_1` | `tcp/502` | Breaks direct lateral movement to the S7 PLC |
| `vdc01` | `certificationauthority` | `tcp/443` | Breaks credential reuse toward the CA |
| `vdc01` | `vdc02` | `tcp/389` | Breaks AD replication / lateral movement between domain controllers |

The experiment re-derives all 8 scenario graphs on the hardened fact base (`environmentNetwork_hardened.P`) and is fully deterministic: it does **not** call the LLM and requires no API key.

```bash
# from the repository root (inside the container)
./ot_pipeline/counterfactual/run_hardened.sh

```

Results are written to `ot_pipeline/counterfactual/results/` and the summary table is synced back to `ot_pipeline/counterfactual/benchmark_results_hardened.csv`. Expected outcome on the committed fact base: scenarios **01** and **07** remain reachable (`OK`), scenarios **02, 03, 04, 05, 06, 08** become `UNSATISFIABLE` (6 of 8).

---

## Customization & Extension Guide

To adapt or extend the pipeline, focus on these files:

### 1. Change the Industrial Topology / Network Inventory

* **File:** `ot_pipeline/configs/configuration.json`
* **What to edit:** Modify host IP definitions, open ports, installed software, CVE identifiers, active user accounts, firewall ACL conduits, and L2 fieldbus connections.

### 2. Modify LLM Extraction Prompts or Symbolic Completion Rules

* **File:** `ot_pipeline/configs/application_ot.yaml`
* **What to edit:**
* **System-1 Prompts:** Update prompt templates under `preprocessing` to instruct the LLM on extracting new predicate signatures.
* **System-2A ASP Logic:** Update the `knowledge_base` section to add new inductive logic (e.g., custom credential inheritance or subnet routing logic).
* `ot_pipeline/configs/behavior_ot.yaml` holds the additional pre/post-processing hooks used by the extraction engine.



### 3. Add or Modify OT Attack Interaction Rules

* **File:** `ot_pipeline/rules/attack1.P` *(canonical copy; `run_pipeline.sh` stages it as `./attack1.P` at the repository root during execution)*
* **What to edit:** Contains formal Horn clauses defining how vulnerabilities combine. Modify this file if you want to model:
* Novel lateral movement primitives (e.g., Modbus/TCP or EtherNet/IP unauthorized commanding).
* Man-in-the-Middle (MitM) data-tampering attacks on industrial fieldbuses.
* Privilege escalation on engineering workstations.



### 4. Adjust Evaluated Attack Goals & Scenarios

* **File:** `ot_pipeline/scripts/generate_all_graph.sh`
* **What to edit:** each `SCENARIOS` entry is `ScenarioName:goal`; add a new entry to evaluate an additional goal (e.g., a safety PLC or an HMI station):
```bash
"09_HMI_Station_Exec:execCode(hmi_station,root)"
```



---

## Artifacts & Results

All outputs are written to `ot_pipeline/results/`:

| Artifact | Path | Description |
| --- | --- | --- |
| **Benchmark Summary** | `ot_pipeline/results/benchmark_results.csv` | Derivation status (`OK`), node counts, edge counts, and execution latencies for all 8 scenarios. |
| **Extraction Latency** | `ot_pipeline/results/pipeline_timing.json` | Detailed latency breakdown for each System-1 prompt atom and System-2 ASP solving time. |
| **Visual Graphs** | `ot_pipeline/results/graphs/*.pdf`, `*.png` | Visual attack trees illustrating causal vulnerability chains. |
| **Raw Graphviz** | `ot_pipeline/results/dot/*.dot` | Raw directed graphs for graph-theoretic post-processing. |
| **Ground Facts** | `ot_pipeline/results/cached_system1_facts.json` | Ground-truth primitives for zero-config offline execution. |

---

## Repository Tree

```text
.
├── Dockerfile                             # Containerization definition (Ubuntu 22.04 base)
├── run_pipeline.sh                        # Master entrypoint script
├── .env.example                           # Template for API credentials
├── ot_pipeline/
│   ├── environmentNetwork.P               # Compiled Datalog fact base (output of System-1/2A)
│   ├── requirement.txt                    # Python dependencies (Clingo pinned)
│   ├── configs/
│   │   ├── configuration.json             # Danieli industrial plant architecture
│   │   ├── application_ot.yaml            # Prompt slicing definitions & Clingo ASP rules
│   │   └── behavior_ot.yaml               # Pre/post-processing hooks for the extractors
│   ├── rules/
│   │   └── attack1.P                      # Canonical OT interaction rules (MulVAL)
│   ├── scripts/
│   │   ├── run_llmasp.py                  # Neural extraction & ASP inductive reasoning engine
│   │   ├── generate_all_graph.sh          # Benchmark execution suite (8 scenarios)
│   │   └── format_graphs.py               # Label compaction & figure compositing (requires Pillow, host-side)
│   ├── counterfactual/
│   │   ├── configuration_hardened.json    # Hardened plant configuration (3 ACLs removed)
│   │   ├── environmentNetwork_hardened.P  # Hardened Datalog fact base
│   │   ├── benchmark_results_hardened.csv # Reproduced experiment summary
│   │   └── run_hardened.sh                # Deterministic hardened re-derivation (no LLM, no API key)
│   └── results/
│       ├── benchmark_results.csv          # Compiled experimental metrics
│       ├── pipeline_timing.json           # Execution latency logs
│       ├── cached_system1_facts.json      # Offline replay cache
│       ├── dot/                           # Directed attack graphs in Graphviz format
│       └── graphs/                        # Rendered PDF/PNG attack graph visual diagrams
└── utils/                                 # MulVAL graph compiler and translation suite

```
