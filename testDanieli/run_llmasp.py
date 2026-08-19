import os
import json
import re
import time
import yaml
import clingo
from openai import OpenAI

client = OpenAI(
    base_url=os.getenv("LLM_BASE_URL", "https://api.groq.com/openai/v1"),
    api_key=os.getenv("GROQ_API_KEY") or os.getenv("OPENAI_API_KEY"),
)

def load_yaml(file_path: str) -> dict:
    with open(file_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)

def sanitize_term(term: str) -> str:
    term = term.strip()
    if term.isdigit():
        return term
    sanitized = re.sub(r"[^a-zA-Z0-9_]", "_", term).lower()
    sanitized = re.sub(r"_+", "_", sanitized).strip("_")
    if sanitized == "vjumpserver":
        sanitized = "jump_server"
    return sanitized if sanitized else "unknown"

def sanitize_prolog_fact(raw_fact: str) -> str:
    raw_fact = raw_fact.strip().rstrip(".")
    match = re.match(r"^([a-zA-Z0-9_]+)\s*\((.*)\)$", raw_fact)
    if not match:
        return None
    pred_name = match.group(1).strip()
    args_str = match.group(2).strip()
    args = [sanitize_term(arg) for arg in args_str.split(",") if arg.strip()]
    return f"{pred_name}({','.join(args)})."

def run_llmasp_pipeline(json_input_path, behavior_path, application_path, output_p_path):
    timing = {"llm_calls": [], "llm_total_sec": 0.0, "asp_total_sec": 0.0}

    behavior = load_yaml(behavior_path)
    application = load_yaml(application_path)

    with open(json_input_path, "r", encoding="utf-8") as f:
        raw_json_data = json.load(f)

    init_prompt = behavior["preprocessing"]["init"]
    context_prompt_text = application["preprocessing"].get("_", "")
    context_prompt = behavior["preprocessing"]["context"].format(context=context_prompt_text)

    mapping_template = behavior["preprocessing"]["mapping"]
    extracted_facts = []

    for atom_key, instruction in application["preprocessing"].items():
        if atom_key == "_":
            continue

        pred_name = atom_key.split("(")[0].strip()

        # Route the proper JSON slice
        if pred_name == "aclNW":
            payload_data = {"firewall_rules": raw_json_data.get("firewall_rules", [])}
        elif pred_name in ["l2Connection", "isMaster", "isSlave"]:
            payload_data = {"fieldbus_connections": raw_json_data.get("fieldbus_connections", [])}
        elif pred_name == "dataFlow":
            payload_data = {"data_flows": raw_json_data.get("data_flows", [])}
        else:
            payload_data = {"hosts": raw_json_data.get("hosts", [])}

        input_payload = json.dumps(payload_data, indent=1)

        prompt = mapping_template.format(
            input=input_payload,
            instructions=instruction,
            atom=atom_key,
        )

        messages = [
            {"role": "system", "content": f"{init_prompt}\n\n{context_prompt}"},
            {"role": "user", "content": prompt}
        ]

        for attempt in range(5):
            try:
                t0 = time.perf_counter()
                response = client.chat.completions.create(
                    model=os.getenv("LLM_MODEL", "openai/gpt-oss-20b"),
                    temperature=0.0,
                    messages=messages,
                )
                elapsed = time.perf_counter() - t0
                timing["llm_calls"].append({"atom": atom_key, "sec": elapsed})
                timing["llm_total_sec"] += elapsed
                break
            except Exception as e:
                if "429" in str(e) or "413" in str(e) or "rate_limit" in str(e).lower():
                    sleep_time = 5 * (attempt + 1)
                    print(f"[!] Rate limit on '{atom_key}'. Retrying in {sleep_time}s...")
                    time.sleep(sleep_time)
                else:
                    raise e

        reply = response.choices[0].message.content.strip()

        # Extract lines
        matches = re.findall(r"\[OUTPUT\](.*?)\[/OUTPUT\]", reply, re.DOTALL)
        candidate_text = "\n".join(matches) if matches else reply

        for line in candidate_text.splitlines():
            line = line.strip().replace("'", "").replace('"', "")
            if not line or line.upper() == "NONE":
                continue

            found_preds = re.findall(rf"\b{pred_name}\s*\([^)]*\)", line)
            for raw_pred in found_preds:
                sanitized_fact = sanitize_prolog_fact(raw_pred)
                if sanitized_fact:
                    extracted_facts.append(sanitized_fact)

        time.sleep(1.0)

    extracted_facts = sorted(list(set(extracted_facts)))
    print(f"[+] System-1 (LLM/SLM) extracted {len(extracted_facts)} explicit facts "
          f"in {timing['llm_total_sec']:.2f}s.")

    # System-2: Clingo ASP
    t0 = time.perf_counter()
    ctl = clingo.Control()

    for fact in extracted_facts:
        try:
            ctl.add("base", [], fact)
        except Exception as e:
            print(f"[!] Clingo parse error on '{fact}': {e}")

    asp_kb = application.get("knowledge_base", "")
    if asp_kb:
        ctl.add("base", [], asp_kb)

    ctl.ground([("base", [])])

    completed_facts = set(extracted_facts)
    def on_model(model):
        for atom in model.symbols(shown=True):
            completed_facts.add(f"{atom}.")

    ctl.solve(on_model=on_model)
    timing["asp_total_sec"] = time.perf_counter() - t0

    print(f"[+] System-2 (Clingo) completed to {len(completed_facts)} total facts "
          f"in {timing['asp_total_sec']:.2f}s.")

    with open(output_p_path, "w", encoding="utf-8") as out:
        out.write("/* Auto-generated via LLMASP Pipeline (Alviano et al.) */\n\n")
        out.write("attackerLocated(internet).\nmalicious(internet).\n\n")

        for fact in sorted(completed_facts):
            out.write(f"{fact}\n")

        out.write("\n% Core Evaluation Goals\n")
        out.write("attackGoal(execCode(jump_server,admin)).\n")
        out.write("attackGoal(execCode(vbackup,admin)).\n")
        out.write("attackGoal(domainCompromise(danieli_domain)).\n")
        out.write("attackGoal(unauthorizedControl(plc_l1_1)).\n")
        out.write("attackGoal(execCode(plc_l1_1,root)).\n")
        out.write("attackGoal(physicalDriveControl(jump_server,drive_area_1_1)).\n")
        out.write("attackGoal(dos(internet,plc_l1_1)).\n")
        out.write("attackGoal(processDataTampering(keba_pda_1,iba_hd)).\n")

    print(f"[+] Successfully wrote MulVAL facts to {output_p_path}")

    with open("pipeline_timing.json", "w", encoding="utf-8") as tf:
        json.dump(timing, tf, indent=2)
    print("[+] Timing data written to pipeline_timing.json")


if __name__ == "__main__":
    run_llmasp_pipeline(
        json_input_path="configuration.json",
        behavior_path="behavior_ot.yaml",
        application_path="application_ot.yaml",
        output_p_path="environmentNetwork.P",
    )