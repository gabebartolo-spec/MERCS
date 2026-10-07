#!/usr/bin/env python3
"""Layering lint (guardrails B3 and B2, 05_STYLE_CODE "Layering"): data -> sim -> presentation -> ui.

Scans *.gd under sim/, presentation/ and ui/ (a missing folder or project.godot is fine).
Findings come from code only, never from comments or string contents. Rules:

  LAYER-IMPORT    a res:// string literal pointing outside what the script's layer may use
                  (sim: data, sim; presentation adds presentation, assets; ui adds ui)
  LAYER-CLASS     code names a class_name declared by a script in a higher layer
  LAYER-AUTOLOAD  code names an autoload whose script is in a higher layer; every autoload
                  named from sim/ is an error (autoloads are Nodes)
  SIM-EXTENDS     a sim script extends anything but RefCounted, a sim class_name, a class
                  declared in the same file or a res://sim/ path (no extends line is fine)
  SIM-ENGINE      sim code uses Node, Node2D, Node3D, Control, Input, Engine, SceneTree,
                  any node class in node_classes.txt (Timer.new(), Sprite2D...), OS (non-clock), get_node, get_tree, $Node or %Node access, or a .tscn/.scn path
  SIM-CLOCK       sim code uses Time.* or an OS clock read (OS.get_ticks_msec and friends)
  SIM-AWAIT       sim code uses await
  SIM-RANDOM      sim code outside the randomness owner calls randi, randf, randi_range,
                  randf_range, randfn, randomize, seed(, rand_from_seed, .shuffle(,
                  .pick_random( or names RandomNumberGenerator

The randomness owner is the file whose lowercased path is sim/core/rng.gd, so the docs'
Rng.gd and the naming rule's snake_case both match. Autoloads come from the [autoload]
section of project.godot.

Usage: python tools/lint/layering.py [--root DIR]
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

from lintlib import (IDENT, STR, GdSource, Report, ends_operand, files_under, is_member,
                     parse_args, read_text, rel, scan_gd)

LAYERS = ("data", "sim", "presentation", "ui")  # lowest to highest (docs: B3)
SCANNED = ("sim", "presentation", "ui")
ALLOWED_IMPORTS = {
    "sim": ("res://data/", "res://sim/"),
    "presentation": ("res://data/", "res://sim/", "res://presentation/", "res://assets/"),
    "ui": ("res://data/", "res://sim/", "res://presentation/", "res://assets/", "res://ui/"),
}
RANDOMNESS_OWNER = "sim/core/rng.gd"  # compared with the lowercased relative path
ENGINE_CLASSES = frozenset("Node Node2D Node3D Control Input Engine SceneTree OS".split())
NODE_CLASSES = frozenset(line for line in read_text(Path(__file__).with_name("node_classes.txt")).splitlines()
                         if re.fullmatch(r"[A-Z][A-Za-z0-9]*", line))
ENGINE_CALLS = frozenset({"get_node", "get_tree"})
RANDOM_FUNCS = frozenset("randi randf randi_range randf_range randfn randomize rand_from_seed seed".split())
RANDOM_METHODS = frozenset({"shuffle", "pick_random"})
OS_CLOCK = r"OS\s*\.\s*get_(?:ticks|unix|system|date|time)\w*"
OS_CLOCK_RE = re.compile(OS_CLOCK)
EXTENDS = re.compile(r"\bextends\s+(\x01|[A-Za-z_][\w.]*)")
CALL = re.compile(r"\s*\(")


@dataclass
class Script:
    path: str  # relative to the root, forward slashes
    layer: str
    src: GdSource
    class_name: str | None


@dataclass(frozen=True)
class Autoload:
    path: str  # script path below res://, e.g. presentation/autoload/game_data.gd
    layer: str | None


def load_scripts(root: Path) -> list[Script]:
    scripts = []
    for path in files_under(root, SCANNED, (".gd",)):
        relpath = rel(root, path)
        src = scan_gd(read_text(path))
        declared = re.search(r"\bclass_name\s+([A-Za-z_]\w*)", src.code)
        scripts.append(Script(relpath, relpath.split("/")[0], src, declared.group(1) if declared else None))
    return scripts


def read_autoloads(root: Path) -> dict[str, Autoload]:
    """Name -> script for every line of the [autoload] section of project.godot."""
    project = root / "project.godot"
    found: dict[str, Autoload] = {}
    in_section = False
    for raw in (read_text(project).splitlines() if project.is_file() else []):
        line = raw.strip()
        if line.startswith("["):
            in_section = line == "[autoload]"
        elif in_section and "=" in line and not line.startswith(";"):
            name, _, value = line.partition("=")
            target = value.strip().strip('"').lstrip("*")
            if target.startswith("res://"):
                path = target[len("res://"):]
                head = path.split("/")[0]
                found[name.strip()] = Autoload(path, head if head in LAYERS else None)
    return found


def check_imports(script: Script, report: Report) -> None:
    allowed = ALLOWED_IMPORTS[script.layer]
    for lit in script.src.lits:
        if lit.text.startswith("res://") and not lit.text.startswith(allowed):
            report.error(script.path, lit.line, "LAYER-IMPORT",
                         f'{script.layer} script uses "{lit.text}", outside the layers it may use '
                         "(data -> sim -> presentation -> ui)")


def check_references(script: Script, classes: dict[str, str], autoloads: dict[str, Autoload],
                     report: Report) -> None:
    code, rank = script.src.code, LAYERS.index(script.layer)
    for match in IDENT.finditer(code):
        name = match.group()
        if is_member(code, match.start()):
            continue
        line = script.src.line_at(match.start())
        layer = classes.get(name)
        if layer and LAYERS.index(layer) > rank:
            report.error(script.path, line, "LAYER-CLASS",
                         f"{script.layer} script uses class {name}, declared in the higher {layer} layer")
        auto = autoloads.get(name)
        if auto is None or auto.path == script.path:
            continue
        if script.layer == "sim":
            report.error(script.path, line, "LAYER-AUTOLOAD",
                         f"sim script uses autoload {name}; autoloads are Nodes and sim never touches Nodes")
        elif auto.layer and LAYERS.index(auto.layer) > rank:
            report.error(script.path, line, "LAYER-AUTOLOAD",
                         f"{script.layer} script uses autoload {name}, whose script is in the higher {auto.layer} layer")


def check_extends(script: Script, classes: dict[str, str], report: Report) -> set[int]:
    """SIM-EXTENDS; returns the positions of the extends targets (not engine uses)."""
    code = script.src.code
    local = set(re.findall(r"^\s*class\s+([A-Za-z_]\w*)", code, re.M))
    sim_classes = {name for name, layer in classes.items() if layer == "sim"} | local
    targets: set[int] = set()
    for match in EXTENDS.finditer(code):
        target = match.group(1)
        targets.add(match.start(1))
        if target == STR:
            shown = script.src.lit_at[match.start(1)].text
            allowed = shown.startswith("res://sim/")
        else:
            shown = target
            allowed = target.split(".")[0] == "RefCounted" or target.split(".")[0] in sim_classes
        if not allowed:
            report.error(script.path, script.src.line_at(match.start()), "SIM-EXTENDS",
                         f"sim script extends {shown}; sim extends RefCounted, a sim class or a res://sim/ path only")
    return targets


def check_engine(script: Script, skip: set[int], report: Report) -> None:
    code, src = script.src.code, script.src
    for match in IDENT.finditer(code):
        name, start = match.group(), match.start()
        if start in skip:
            continue
        is_class = (name in ENGINE_CLASSES or name in NODE_CLASSES) and not is_member(code, start)
        if name == "OS" and OS_CLOCK_RE.match(code, start):
            continue  # reported as SIM-CLOCK
        if is_class or name in ENGINE_CALLS:
            report.error(script.path, src.line_at(start), "SIM-ENGINE", f"sim code uses {name}")
    for match in re.finditer(r"\$", code):
        report.error(script.path, src.line_at(match.start()), "SIM-ENGINE", "sim code uses $ node access")
    for match in re.finditer(r"%(?=[A-Za-z_\x01])", code):
        if not ends_operand(code, match.start()):
            report.error(script.path, src.line_at(match.start()), "SIM-ENGINE", "sim code uses % unique-node access")
    for lit in src.lits:
        if lit.text.lower().endswith((".tscn", ".scn")):
            report.error(script.path, lit.line, "SIM-ENGINE", f'sim code uses the scene path "{lit.text}"')


def check_clock_and_await(script: Script, report: Report) -> None:
    code, src = script.src.code, script.src
    for pattern in (r"(?<![\w.])Time\s*\.\s*\w+", r"(?<![\w.])" + OS_CLOCK):
        for match in re.finditer(pattern, code):
            used = "".join(match.group().split())
            report.error(script.path, src.line_at(match.start()), "SIM-CLOCK",
                         f"sim code reads the clock with {used}")
    for match in re.finditer(r"(?<![\w.])await\b", code):
        report.error(script.path, src.line_at(match.start()), "SIM-AWAIT", "sim code uses await")


def check_random(script: Script, report: Report) -> None:
    if script.path.lower() == RANDOMNESS_OWNER:
        return
    code, src = script.src.code, script.src
    for match in IDENT.finditer(code):
        name, member = match.group(), is_member(code, match.start())
        called = CALL.match(code, match.end()) is not None
        bad = (name in RANDOM_FUNCS and not member and called) or \
              (name in RANDOM_METHODS and member and called) or \
              (name == "RandomNumberGenerator" and not member)
        if bad:
            report.error(script.path, src.line_at(match.start()), "SIM-RANDOM",
                         f"sim code uses {name} outside the randomness owner (sim/core/Rng.gd)")


def main() -> int:
    root = parse_args(__doc__, __file__)
    report = Report()
    scripts = load_scripts(root)
    classes = {s.class_name: s.layer for s in scripts if s.class_name}
    autoloads = read_autoloads(root)
    for script in scripts:
        check_imports(script, report)
        check_references(script, classes, autoloads, report)
        if script.layer == "sim":
            skip = check_extends(script, classes, report)
            check_engine(script, skip, report)
            check_clock_and_await(script, report)
            check_random(script, report)
    return report.finish(f"{len(scripts)} scripts")


if __name__ == "__main__":
    sys.exit(main())
