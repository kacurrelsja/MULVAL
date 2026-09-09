# Neuro-Symbolic Industrial Attack Graph Pipeline (Danieli Reference Architecture)

An automated, formal cybersecurity risk-assessment pipeline for Industrial Operational Technology (OT) networks. This repository couples LLMASP (prompt-sliced Large Language Model extraction) with Clingo (Answer Set Programming completion) and MulVAL / XSB Prolog (Horn-clause causal attack graph derivation) to model and evaluate multi-hop cyber-physical attack paths against steel manufacturing OT architectures.

---

## Architecture Overview

The pipeline operates in three decoupled stages:

1. System-1 (Neural Topology Extraction):
   A domain-adapted LLM processes segmented slices of plant configurations (`configuration.json`) via structured prompts (`application_ot.yaml`). It extracts explicit primitives spanning network topology (`located/3`), services (`networkService/5`), credentials (`hasAccount/3`), firewall access conduits (`aclNW/4`), vulnerabilities (`vulHost/5`), industrial fieldbus links (`l2Connection/5`), and telemetry streams (`dataFlow/4`).

2. System-2A (Symbolic Inductive Completion via Clingo):
   Deductive Answer Set Programming rules compute transitive equivalence closures (e.g., cross-host `sameCredentials/2` propagation, domain controller identity resolution, fieldbus master/slave relationships, and protocol bindings) yielding 90 ground Datalog facts without hallucination or generative drift.

3. System-2B (Formal Attack Graph Derivation via MulVAL & XSB Prolog):
   Using formal OT interaction rules (`attack1.P`), the pipeline performs SLG resolution in XSB Prolog to generate directional causal attack graphs (`.dot`, `.pdf`, `.png`) isolating multi-stage attack scenarios across Purdue Model zones.

---

## Repository Structure

```text
.
├── Dockerfile                             # Reproducible execution container
├── run_pipeline.sh                        # Master entrypoint script
├── configuration.json                     # Danieli industrial plant topology definition
├── environmentNetwork.P                   # Master Datalog network fact base
├── attack1.P                              # Synthesized OT interaction rules (MulVAL)
├── ot_pipeline/
│   ├── application_ot.yaml                # LLMASP extraction schema & Clingo inductive rules
│   ├── rules/
│   │   └── attack1.P                      # Source interaction rule repository
│   ├── scripts/
│   │   ├── run_llmasp.py                  # System-1/2A extraction runner
│   │   └── generate_all_graph.sh          # Automated benchmark execution suite
│   └── results/
│       ├── benchmark_results.csv          # Quantitative benchmark metrics
│       ├── pipeline_timing.json           # Execution latencies per extraction atom
│       ├── dot/                           # Raw Graphviz .dot attack graph representations
│       └── graphs/                        # Visual PDF and PNG attack graph artifacts
└── utils/                                 # MulVAL graph compilation and translation toolchain