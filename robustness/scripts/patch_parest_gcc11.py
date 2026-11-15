#!/usr/bin/env python3
"""Repair the local SPEC 510.parest_r GCC 11 build without editing its src tree.

SPEC checksums the installed source. The compatibility change therefore goes
only into the generated build copy after runcpu has populated it in /tmp.
"""
from pathlib import Path
import glob
import sys

if len(sys.argv) != 3 or sys.argv[2] not in ("restore-source", "patch-build"):
    raise SystemExit("usage: patch_parest_gcc11.py SPEC restore-source|patch-build")

spec = Path(sys.argv[1])
base = spec / "benchspec/CPU/510.parest_r"
source = base / "src/source/fe/fe_tools.cc"
types = ["Vector<double>", "Vector<float>", "BlockVector<double>", "BlockVector<float>"]
old_call = "    back_interpolate(dof1, u1, dof2.get_fe(), u1_interpolated);"
new_call = (
    "    back_interpolate<dim, InVector, OutVector, spacedim>("
    "dof1, u1, dof2.get_fe(), u1_interpolated);"
)

def original_form(text):
    text = text.replace(new_call, old_call)
    for vector_type in types:
        fixed = (
            "void FETools::back_interpolate<deal_II_dimension, "
            f"{vector_type}, {vector_type}, deal_II_dimension>\n"
            f"(const DoFHandler<deal_II_dimension> &, const {vector_type} &,")
        original = (
            "void FETools::back_interpolate<deal_II_dimension>\n"
            f"(const DoFHandler<deal_II_dimension> &, const {vector_type} &,")
        text = text.replace(fixed, original)
        if original not in text:
            raise SystemExit(f"expected original instantiation missing: {vector_type}")
    if old_call not in text:
        raise SystemExit("expected original overloaded call missing")
    return text

def patched_form(text):
    text = original_form(text).replace(old_call, new_call)
    for vector_type in types:
        original = (
            "void FETools::back_interpolate<deal_II_dimension>\n"
            f"(const DoFHandler<deal_II_dimension> &, const {vector_type} &,")
        fixed = (
            "void FETools::back_interpolate<deal_II_dimension, "
            f"{vector_type}, {vector_type}, deal_II_dimension>\n"
            f"(const DoFHandler<deal_II_dimension> &, const {vector_type} &,")
        text = text.replace(original, fixed)
    return text

if sys.argv[2] == "restore-source":
    paths = [source]
    transform = original_form
else:
    paths = [Path(p) for p in glob.glob(str(base / "build/build_base_gem5static*/source/fe/fe_tools.cc"))]
    if not paths:
        raise SystemExit("510.parest_r build copy missing; run runcpu build first")
    transform = patched_form

for path in paths:
    before = path.read_text()
    after = transform(before)
    if after != before:
        path.write_text(after)
        print(f"updated {path}")
    else:
        print(f"already correct: {path}")
