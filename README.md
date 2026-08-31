# MulVAL for Operational Technology (OT) Networks

A fork of the  MulVAL  (Multi-host, Multi-stage Vulnerability Analysis Language) logic-based attack graph generator, extended with custom interaction rules and an automated pipeline to model industrial automation and Purdue-segmented networks.


## Features

-  Purdue Model Interaction Rules (`rules/attack1.P`):  Custom Datalog rules for modeling multi-tier industrial environments (Levels 3.5 through 0), unauthenticated industrial protocols (Modbus/TCP, PROFINET), lateral movement via credential reuse, domain controller takeover, controller denial-of-service, and physical fieldbus actuation.
-  Automated Scenario Runner (`generate_all_graph.sh`):  Shell automation to generate, convert, and benchmark visual attack graphs across targeted attack goals.
-  LLMASP Configuration Ingestion (`run_llmasp.py`):  Neuro-symbolic extraction pipeline using LLM prompting and Clingo ASP (`kb.lp`) to convert JSON network manifests (`configuration.json`) into valid MulVAL Datalog input facts (`environmentNetwork.P`).



