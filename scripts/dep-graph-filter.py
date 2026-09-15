#!/usr/bin/env python3
"""Rewrite CMake / Ninja Graphviz DOT into a shorter diagram.

  cmake-targets  CMake --graphviz output: keep user targets, rename import std
  ninja          ninja -t graph: scan → collate → BMI → compile → link
  imports        union of CMakeFiles/**/CXXModules.json usages
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

DROP_NINJA = (
    re.compile(r"^(phony|\.|all)$"),
    re.compile(r"^cmake_object_order_depends_target_"),
    re.compile(r"CXXDependInfo\.json$"),
    re.compile(r"CXXModules\.json$"),
    re.compile(r"(^|/)CXX\.dd$"),
    re.compile(r"^lib__cmake_cxx_"),
)

STD_TARGET = re.compile(r"^__cmake_cxx_std_\d+")
SYNTH = re.compile(r"^(.+)@synth_[0-9a-f]+$")
RULE = re.compile(
    r"^CXX_(SCAN|DYNDEP|COMPILER|STATIC_LIBRARY_LINKER|SHARED_LIBRARY_LINKER|"
    r"EXECUTABLE_LINKER)__(.+?)(?:_(?:unscanned|scanned))?_Release$"
)
HASH_BMI = re.compile(r"^[0-9a-f]{8,}\.bmi(\.ddi)?$")
GEN_TU = re.compile(r"^(include|import)_(\d+)(\.cpp(?:\.o(?:\.(?:ddi|modmap))?)?)$")
NODE_RE = re.compile(
    r'^"([^"]+)"\s*\[label="([^"]*)"(?:,\s*shape=([^,\]]+))?.*\]\s*$'
)
EDGE_RE = re.compile(r'^"([^"]+)"\s*->\s*"([^"]+)"(.*)$')


def _basename(label: str) -> str:
    label = label.replace("\\n", " ")
    return os.path.basename(label.replace("\\", "/"))


def _load_bmi_names(build_dir: Path | None) -> dict[str, str]:
    names: dict[str, str] = {}
    if build_dir is None or not build_dir.is_dir():
        return names
    for path in build_dir.glob("CMakeFiles/**/CXXModules.json"):
        try:
            data = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        for mod, info in (data.get("modules") or {}).items():
            bmi = info.get("bmi")
            if bmi:
                names[_basename(bmi)] = mod
        for mod, info in (data.get("references") or {}).items():
            bmi = info.get("path")
            if bmi:
                names[_basename(bmi)] = mod
    return names


def _load_imports(build_dir: Path) -> tuple[set[str], set[tuple[str, str]]]:
    modules: set[str] = set()
    edges: set[tuple[str, str]] = set()
    for path in build_dir.glob("CMakeFiles/**/CXXModules.json"):
        try:
            data = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        for mod in data.get("modules") or {}:
            modules.add(mod)
        for importer, deps in (data.get("usages") or {}).items():
            modules.add(importer)
            for dep in deps:
                modules.add(dep)
                edges.add((importer, dep))
        for mod in data.get("references") or {}:
            modules.add(mod)
    return modules, edges


def _relabel_ninja(label: str, bmi_names: dict[str, str]) -> str:
    raw = label.strip()
    if raw in ("phony", ".", "all") or raw == " phony":
        return raw.strip()
    m = RULE.match(raw)
    if m:
        kind, tgt = m.group(1), m.group(2).replace(".40synth_", "@synth_")
        tgt = re.sub(r"@synth_[0-9a-f]+$", "", tgt)
        if STD_TARGET.match(tgt):
            tgt = "std"
        action = {
            "SCAN": "scan",
            "DYNDEP": "collate",
            "COMPILER": "compile",
            "STATIC_LIBRARY_LINKER": "archive",
            "SHARED_LIBRARY_LINKER": "link",
            "EXECUTABLE_LINKER": "link",
        }[kind]
        return f"{action} {tgt}" if tgt else action

    base = _basename(raw)
    sm = SYNTH.match(base)
    if sm:
        inner = sm.group(1)
        if STD_TARGET.match(inner):
            return "std"
        return f"{inner} BMI"

    if STD_TARGET.match(base):
        return "std"

    if base in bmi_names:
        mod = bmi_names[base]
        if base.endswith(".ddi"):
            return f"{mod}.bmi.ddi"
        return f"{mod}.bmi"

    hm = HASH_BMI.match(base)
    if hm:
        return "bmi.ddi" if hm.group(1) else "bmi"

    if base.endswith(".gcm"):
        return base
    if base.endswith(".pcm"):
        return base

    gm = GEN_TU.match(base)
    if gm:
        return f"{gm.group(1)}_*{gm.group(3)}"

    return base


def _drop_ninja(label: str) -> bool:
    if label == " phony":
        return True
    return any(p.search(label) for p in DROP_NINJA)


def _parse_dot(text: str) -> tuple[dict[str, dict], list[tuple[str, str, str]]]:
    nodes: dict[str, dict] = {}
    edges: list[tuple[str, str, str]] = []
    for line in text.splitlines():
        s = line.strip()
        nm = NODE_RE.match(s)
        if nm:
            nodes[nm.group(1)] = {
                "label": nm.group(2),
                "shape": nm.group(3) or "",
            }
            continue
        em = EDGE_RE.match(s)
        if em:
            edges.append((em.group(1), em.group(2), em.group(3).strip()))
    return nodes, edges


def _bypass(
    nodes: dict[str, dict],
    edges: list[tuple[str, str, str]],
    drop: set[str],
) -> list[tuple[str, str, str]]:
    succ: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for a, b, attrs in edges:
        succ[a].append((b, attrs))

    out: list[tuple[str, str, str]] = []
    seen: set[tuple[str, str, str]] = set()

    def walk(start: str, node: str, attrs: str, stack: set[str]) -> None:
        if node in drop:
            if node in stack:
                return
            stack = stack | {node}
            for nxt, nattrs in succ.get(node, []):
                walk(start, nxt, attrs or nattrs, stack)
            return
        key = (start, node, attrs)
        if key in seen:
            return
        seen.add(key)
        out.append(key)

    for a, b, attrs in edges:
        if a in drop:
            continue
        walk(a, b, attrs, set())
    return out


def filter_ninja(text: str, build_dir: Path | None) -> str:
    bmi_names = _load_bmi_names(build_dir)
    nodes, edges = _parse_dot(text)
    mentioned = {a for a, _, _ in edges} | {b for _, b, _ in edges}
    for nid in mentioned:
        if nid not in nodes:
            # Ninja sometimes emits extra outputs with no label node.
            nodes[nid] = {"label": "", "shape": ""}
    drop: set[str] = set()
    labels: dict[str, str] = {}
    shapes: dict[str, str] = {}
    for nid, info in nodes.items():
        labels[nid] = _relabel_ninja(info["label"], bmi_names) if info["label"] else ""
        shapes[nid] = info["shape"]
        if not info["label"] or _drop_ninja(info["label"]) or _drop_ninja(labels[nid]):
            drop.add(nid)

    # Distinguish per-TU scan/compile (otherwise every tally .cppm shares one node).
    for nid, lab in list(labels.items()):
        if nid in drop:
            continue
        kind = "scan" if lab.startswith("scan ") else "compile" if lab.startswith("compile ") else None
        if kind is None:
            continue
        for a, b, attrs in edges:
            if a != nid or "arrowhead=none" in attrs:
                continue
            prod = labels.get(b, "")
            if kind == "scan" and prod.endswith(".ddi"):
                src = prod[: -len(".ddi")]
                if src.endswith(".o"):
                    src = src[:-2]
                labels[nid] = f"scan {src}"
                break
            if kind == "compile" and prod.endswith(".o"):
                labels[nid] = f"compile {prod[:-2]}"
                break

    for nid, lab in labels.items():
        if lab in ("bmi", "bmi.ddi", "scan bmi", "compile bmi"):
            drop.add(nid)

    # One node per label (std scan/compile clones, include_1.cpp vs include_2.cpp).
    merged: dict[str, str] = {}
    rewrite: dict[str, str] = {}
    for nid, lab in labels.items():
        if nid in drop:
            continue
        if lab not in merged:
            merged[lab] = nid
        rewrite[nid] = merged[lab]

    cleaned_edges: list[tuple[str, str, str]] = []
    for a, b, attrs in edges:
        if "phony" in attrs:
            continue
        cleaned_edges.append((a, b, attrs))

    new_edges = _bypass(nodes, cleaned_edges, drop)
    remapped: list[tuple[str, str, str]] = []
    seen_e: set[tuple[str, str, str]] = set()
    for a, b, attrs in new_edges:
        a2, b2 = rewrite.get(a, a), rewrite.get(b, b)
        if a2 in drop or b2 in drop or a2 == b2:
            continue
        # Keep the edge style; drop leftover labels.
        attrs = re.sub(r'\s*label\s*=\s*"[^"]*"', "", attrs).strip()
        key = (a2, b2, attrs)
        if key in seen_e:
            continue
        seen_e.add(key)
        remapped.append(key)

    keep = {a for a, _, _ in remapped} | {b for _, b, _ in remapped}
    lines = [
        "digraph ninja {",
        "rankdir=LR",
        'node [fontsize=11, fontname="IBM Plex Sans, Helvetica, sans-serif"]',
        'edge [fontsize=10]',
    ]
    for nid in sorted(keep, key=lambda n: labels.get(n, n)):
        lab = labels[nid]
        shape = shapes.get(nid) or "box"
        extra = ""
        if lab.startswith(("scan ", "collate ", "compile ", "archive ", "link ")):
            extra = ', shape=ellipse, style=filled, fillcolor="#f4f4f5"'
        elif lab.endswith((".bmi", ".gcm", ".pcm")) or lab.endswith(" BMI"):
            extra = ', shape=box, style=filled, fillcolor="#fde68a"'
        elif lab in ("std",) or lab.startswith("std."):
            extra = ', shape=box, style=filled, fillcolor="#dbeafe"'
        elif lab.endswith((".a", ".so")) or not any(
            lab.endswith(s) for s in (".o", ".cpp", ".cppm", ".cc", ".ddi", ".modmap")
        ):
            if shape == "ellipse":
                extra = ", shape=ellipse"
            elif lab.endswith((".a", ".so")) or "/" not in lab and "." not in lab:
                extra = ', shape=box, style=filled, fillcolor="#e2e8f0"'
        else:
            extra = ", shape=box"
        lines.append(f'  "{nid}" [label="{lab}"{extra}]')
    for a, b, attrs in remapped:
        suffix = f" {attrs}" if attrs else ""
        lines.append(f'  "{a}" -> "{b}"{suffix}')
    lines.append("}")
    return "\n".join(lines) + "\n"


def filter_cmake_targets(text: str) -> str:
    def relabel(lab: str) -> str:
        lab = lab.replace("\\n", "\n")
        first = lab.split("\n", 1)[0]
        if STD_TARGET.match(first):
            return "std"
        sm = SYNTH.match(first)
        if sm:
            inner = sm.group(1)
            if STD_TARGET.match(inner):
                return "std"
            return inner
        return first

    def sub_label(match: re.Match[str]) -> str:
        return f'label="{relabel(match.group(1))}"'

    out = re.sub(r'label\s*=\s*"([^"]*)"', sub_label, text)
    if not out.endswith("\n"):
        out += "\n"
    return out


def write_imports(build_dir: Path) -> str | None:
    modules, edges = _load_imports(build_dir)
    if not modules:
        return None
    lines = [
        "digraph imports {",
        "rankdir=LR",
        'node [shape=box, fontsize=12, fontname="IBM Plex Sans, Helvetica, sans-serif"]',
        'edge [fontsize=10]',
    ]
    for mod in sorted(modules):
        extra = ', style=filled, fillcolor="#dbeafe"' if mod == "std" or mod.startswith("std.") else ""
        lines.append(f'  "{mod}" [label="{mod}"{extra}]')
    for a, b in sorted(edges):
        lines.append(f'  "{a}" -> "{b}"')
    if not edges:
        lines.append("  // no usage edges yet — scan/build the project first")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("kind", choices=("ninja", "cmake-targets", "imports"))
    ap.add_argument("input", nargs="?", help="DOT file or - for stdin (ninja/cmake-targets)")
    ap.add_argument("output", nargs="?", help="DOT file or - for stdout")
    ap.add_argument("--build-dir", type=Path, default=None)
    args = ap.parse_args()

    if args.kind == "imports":
        if args.build_dir is None:
            ap.error("imports requires --build-dir")
        text = write_imports(args.build_dir)
        if text is None:
            return 2
        dest = args.output or args.input
        if not dest or dest == "-":
            sys.stdout.write(text)
        else:
            Path(dest).write_text(text)
        return 0

    src = args.input or "-"
    if src == "-":
        raw = sys.stdin.read()
    else:
        raw = Path(src).read_text()

    if args.kind == "ninja":
        out = filter_ninja(raw, args.build_dir)
    else:
        out = filter_cmake_targets(raw)

    dest = args.output
    if not dest or dest == "-":
        sys.stdout.write(out)
    else:
        Path(dest).write_text(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
