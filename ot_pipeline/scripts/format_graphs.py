#!/usr/bin/env python3
import os
import re
import glob
import subprocess
from PIL import Image, ImageDraw, ImageFont

def clean_label(raw_label):
    # Remove leading "ID:" if present
    lbl = re.sub(r'^\d+:\s*', '', raw_label.strip())
    # Remove trailing ":0" or ":1"
    lbl = re.sub(r':\d+$', '', lbl)
    return lbl.strip()

def process_single_graph(dot_file, output_img_path):
    with open(dot_file, 'r', encoding='utf-8') as f:
        dot_content = f.read()

    node_map = {}
    
    # Regex to match node lines: 1 [label="...",shape=...];
    node_pattern = re.compile(r'^\s*"?(\d+)"?\s*\[label="([^"]+)"(.*?)\];', re.MULTILINE)
    
    for match in node_pattern.finditer(dot_content):
        node_id = int(match.group(1))
        label_text = match.group(2)
        attrs = match.group(3)
        
        cleaned = clean_label(label_text)
        
        if 'shape=diamond' in attrs:
            prefix, suffix = '<', '>'
        elif 'shape=ellipse' in attrs or 'shape=circle' in attrs:
            prefix, suffix = '(', ')'
        else: # box / rectangle
            prefix, suffix = '[', ']'
            
        node_map[node_id] = f"{prefix}{node_id}{suffix}:{cleaned}"

    # Replace labels with just numbers and make nodes compact
    def replace_node(m):
        nid = m.group(1)
        attrs = m.group(3)
        # Force compact size and fontsize
        return f'  "{nid}" [label="{nid}"{attrs},fontsize=11,width=0.4,height=0.3];'

    simplified_dot = node_pattern.sub(replace_node, dot_content)
    # Add graph layout properties for a clean vertical column
    simplified_dot = simplified_dot.replace('digraph G {', 'digraph G {\n  rankdir=TB;\n  nodesep=0.25;\n  ranksep=0.35;')

    temp_dot = dot_file + ".tmp.dot"
    temp_png = dot_file + ".tmp.png"
    with open(temp_dot, 'w', encoding='utf-8') as f:
        f.write(simplified_dot)

    # Render left graph via Graphviz dot
    subprocess.run(["dot", "-Tpng", temp_dot, "-o", temp_png], check=True)

    # Build sorted legend text: descending or ascending
    sorted_ids = sorted(node_map.keys())
    legend_lines = [node_map[nid] for nid in sorted_ids]

    # Render Composite Image using PIL
    graph_img = Image.open(temp_png)
    gw, gh = graph_img.size

    # Prepare Font
    try:
        font = ImageFont.truetype("DejaVuSansMono.ttf", 15)
        bold_font = ImageFont.truetype("DejaVuSans-Bold.ttf", 16)
    except Exception:
        font = ImageFont.load_default()
        bold_font = ImageFont.load_default()

    # Calculate text image width and height
    line_spacing = 6
    line_height = 20
    text_w = 950
    text_h = len(legend_lines) * (line_height + line_spacing) + 80

    total_h = max(gh, text_h) + 60
    total_w = gw + text_w + 60

    composite = Image.new("RGB", (total_w, total_h), "white")
    draw = ImageDraw.Draw(composite)

    # Paste left graph vertically centered
    y_graph = (total_h - 40 - gh) // 2
    composite.paste(graph_img, (30, y_graph))

    # Draw left caption
    draw.text((30 + gw // 2 - 60, total_h - 35), "(a) AG structure.", fill="black", font=bold_font)

    # Draw right legend lines
    x_text = gw + 60
    y_text = 40
    for line in legend_lines:
        draw.text((x_text, y_text), line, fill="black", font=font)
        y_text += line_height + line_spacing

    # Draw right caption
    draw.text((x_text + 150, total_h - 35), "(b) AG node interpretation.", fill="black", font=bold_font)

    # Save output
    composite.save(output_img_path)
    print(f"[+] Successfully generated: {output_img_path}")

    # Clean temporary files
    if os.path.exists(temp_dot): os.remove(temp_dot)
    if os.path.exists(temp_png): os.remove(temp_png)

if __name__ == "__main__":
    dot_files = sorted(glob.glob("ot_pipeline/results/dot/*.dot"))
    if not dot_files:
        dot_files = sorted(glob.glob("ot_pipeline/results/graphs/*.dot"))
    if not dot_files:
        dot_files = sorted(glob.glob("*.dot"))

    out_dir = "ot_pipeline/results/graphs"
    os.makedirs(out_dir, exist_ok=True)

    for df in dot_files:
        base_name = os.path.splitext(os.path.basename(df))[0]
        out_png = os.path.join(out_dir, f"{base_name}.png")
        process_single_graph(df, out_png)