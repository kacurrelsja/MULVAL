# Neuro-Symbolic Industrial Attack Graph Pipeline

An automated risk assessment pipeline for Operational Technology (OT) networks in industrial manufacturing (Danieli reference architecture).

The framework couples **neural information extraction (LLMs)** with **symbolic deduction (ASP via Clingo)** and **formal attack graph generation (MulVAL / XSB Prolog)** to map cyber-physical attack paths across Purdue Model zones without manual fact authoring or generative hallucinations.

---

## Quick Navigation

1. [Installation & Setup](https://www.google.com/search?q=%2523installation--setup&utm_source=gemini)
* [Option A: Docker (Recommended)](https://www.google.com/search?q=%2523option-a-docker-recommended&utm_source=gemini)
* [Option B: Local Installation (Ubuntu 22.04 / 24.04)](https://www.google.com/search?q=%2523option-b-local-installation-ubuntu-2204--2404&utm_source=gemini)


2. [How It Works](https://www.google.com/search?q=%2523how-it-works&utm_source=gemini)
3. [Running the Pipeline](https://www.google.com/search?q=%2523running-the-pipeline&utm_source=gemini)
4. [Customization & Extension Guide](https://www.google.com/search?q=%2523customization--extension-guide&utm_source=gemini)
5. [Artifacts & Results](https://www.google.com/search?q=%2523artifacts--results&utm_source=gemini)

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
pip install clingo pyyaml openai pandas

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
[ Plant Configuration ] (configuration.json)
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
                           │ 90 Validated Ground Datalog Facts
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

---

## Customization & Extension Guide

To adapt or extend the pipeline, focus on these files:

### 1. Change the Industrial Topology / Network Inventory

* **File:** `configuration.json`
* **What to edit:** Modify host IP definitions, open ports, installed software, CVE identifiers, active user accounts, firewall ACL conduits, and L2 fieldbus connections.

### 2. Modify LLM Extraction Prompts or Symbolic Completion Rules

* **File:** `ot_pipeline/application_ot.yaml`
* **What to edit:**
* **System-1 Prompts:** Update prompt templates under `preprocessing` to instruct the LLM on extracting new predicate signatures.
* **System-2A ASP Logic:** Update the `knowledge_base` section to add new inductive logic (e.g., custom credential inheritance or subnet routing logic).



### 3. Add or Modify OT Attack Interaction Rules

* **File:** `attack1.P` *(and `ot_pipeline/rules/attack1.P`)*
* **What to edit:** Contains formal Horn clauses defining how vulnerabilities combine. Modify this file if you want to model:
* Novel lateral movement primitives (e.g., Modbus/TCP or EtherNet/IP unauthorized commanding).
* Man-in-the-Middle (MitM) data-tampering attacks on industrial fieldbuses.
* Privilege escalation on engineering workstations.



### 4. Adjust Evaluated Attack Goals & Scenarios

* **File:** `ot_pipeline/scripts/generate_all_graph.sh`
* **What to edit:** Look at the `SCENARIOS` array to add new target goals (e.g., targeting a safety PLC or an HMI station):
```bash
"09:attackGoal(execCode(hmi_station,root)).:HMI Station Compromise"

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
├── configuration.json                     # Danieli industrial plant architecture
├── environmentNetwork.P                   # Compiled Datalog fact base (output of System-1/2A)
├── attack1.P                              # Synthesized OT interaction rules (MulVAL)
├── ot_pipeline/
│   ├── application_ot.yaml                # Prompt slicing definitions & Clingo ASP rules
│   ├── rules/
│   │   └── attack1.P                      # Source interaction rules
│   ├── scripts/
│   │   ├── run_llmasp.py                  # Neural extraction & ASP inductive reasoning engine
│   │   └── generate_all_graph.sh          # Benchmark execution suite (8 scenarios)
│   └── results/
│       ├── benchmark_results.csv          # Compiled experimental metrics
│       ├── pipeline_timing.json           # Execution latency logs
│       ├── cached_system1_facts.json      # Offline replay cache
│       ├── dot/                           # Directed attack graphs in Graphviz format
│       └── graphs/                        # Rendered PDF/PNG attack graph visual diagrams
└── utils/                                 # MulVAL graph compiler and translation suite

```
