from __future__ import annotations

import re
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

import pytest

ROOT = Path(__file__).resolve().parents[1]
CPSAT_DIR = ROOT / "tests" / "cpsat"


@dataclass(frozen=True)
class ScriptExpectation:
    returncode: int
    stdout_lines: tuple[str, ...] = ()
    stdout_mode: Literal["exact", "any_order", "cumulative_schedule"] = "exact"
    stderr_contains: tuple[str, ...] = ()


_SLOT_INCREMENT_RE = re.compile(r"^slot (?P<slot>\d+) \+(?P<size>\d+)$")
_SLOT_SUM_RE = re.compile(r"^slot (?P<slot>\d+), sum = (?P<total>\d+)$")

EXPECTED_BY_SCRIPT: dict[str, ScriptExpectation] = {
    "add_cumulative.py": ScriptExpectation(
        returncode=0,
        stdout_mode="cumulative_schedule",
        stdout_lines=(
            "possible elements: 5",
            "possible slots: 3",
            "5 variables 6 constraints",
        ),
    ),
    "bool_mult_demo.py": ScriptExpectation(
        returncode=0,
        stdout_mode="any_order",
        stdout_lines=(
            "x=1 y=1 z=1 ",
            "x=1 y=0 z=0 ",
            "x=1 y=2 z=2 ",
            "x=1 y=3 z=3 ",
            "x=1 y=4 z=4 ",
            "x=1 y=5 z=5 ",
            "x=0 y=5 z=0 ",
            "x=0 y=4 z=0 ",
            "x=0 y=3 z=0 ",
            "x=0 y=2 z=0 ",
            "x=0 y=0 z=0 ",
            "x=0 y=1 z=0 ",
        ),
    ),
    "bool_op_demo.py": ScriptExpectation(
        returncode=0,
        stdout_mode="any_order",
        stdout_lines=(
            "x=1 y=0 x&y=0 z=0 ",
            "x=1 y=1 x&y=1 z=1 ",
            "x=0 y=1 x&y=0 z=0 ",
            "x=0 y=0 x&y=0 z=0 ",
        ),
    ),
    "closed_domain_demo.py": ScriptExpectation(
        returncode=0,
        stdout_mode="any_order",
        stdout_lines=("x=0 ",),
    ),
    "div_demo.py": ScriptExpectation(
        returncode=0,
        stdout_mode="any_order",
        stdout_lines=(
            "x=0 y=0 ",
            "x=1 y=0 ",
            "x=2 y=1 ",
            "x=3 y=1 ",
            "x=4 y=2 ",
            "x=5 y=2 ",
            "x=6 y=3 ",
            "x=7 y=3 ",
            "x=8 y=4 ",
            "x=9 y=4 ",
            "x=10 y=5 ",
        ),
    ),
    "linexpr_demo.py": ScriptExpectation(
        returncode=0,
        stdout_mode="any_order",
        stdout_lines=(
            "x=0 y=5 ",
            "x=1 y=7 ",
            "x=2 y=9 ",
            "x=3 y=11 ",
            "x=4 y=13 ",
            "x=5 y=15 ",
            "x=6 y=17 ",
            "x=7 y=19 ",
            "x=8 y=21 ",
            "x=9 y=23 ",
            "x=10 y=25 ",
        ),
    ),
    "mod_demo.py": ScriptExpectation(
        returncode=0,
        stdout_mode="any_order",
        stdout_lines=(
            "x=0 ",
            "x=2 ",
            "x=4 ",
            "x=6 ",
            "x=8 ",
            "x=10 ",
        ),
    ),
    "mult_demo.py": ScriptExpectation(
        returncode=0,
        stdout_mode="any_order",
        stdout_lines=("x=1 y=5 y=5 ",),
    ),
    "only_enforce_if_or.py": ScriptExpectation(
        returncode=0,
        stdout_mode="any_order",
        stdout_lines=(
            "X=0 Y=0 switch=1 active=0 ",
            "X=0 Y=0 switch=0 active=0 ",
            "X=0 Y=1 switch=0 active=0 ",
            "X=0 Y=1 switch=1 active=1 ",
            "X=1 Y=1 switch=1 active=1 ",
            "X=1 Y=1 switch=0 active=0 ",
            "X=1 Y=0 switch=0 active=0 ",
            "X=1 Y=0 switch=1 active=1 ",
        ),
    ),
    "reification_demo.py": ScriptExpectation(
        returncode=0,
        stdout_mode="any_order",
        stdout_lines=(
            "x=0 y=0 z=10 ",
            "x=1 y=0 z=10 ",
            "x=2 y=0 z=10 ",
            "x=3 y=0 z=10 ",
            "x=4 y=0 z=10 ",
            "x=5 y=1 z=5 ",
            "x=6 y=1 z=5 ",
            "x=7 y=1 z=5 ",
            "x=8 y=1 z=5 ",
            "x=9 y=1 z=5 ",
            "x=10 y=1 z=5 ",
        ),
    ),
    "reification_demo_2.py": ScriptExpectation(
        returncode=0,
        stdout_mode="any_order",
        stdout_lines=(
            "x=0 y=0 y2=0 z=0 ",
            "x=1 y=0 y2=0 z=0 ",
            "x=2 y=0 y2=0 z=0 ",
            "x=3 y=0 y2=1 z=0 ",
            "x=4 y=0 y2=1 z=0 ",
        ),
    ),
    "reification_demo_3.py": ScriptExpectation(
        returncode=1,
        stderr_contains=("TypeError: Invalid boolean literal:  'BoundedLinearExpression'",),
    ),
}


def test_all_cpsat_scripts_are_covered() -> None:
    scripts = {path.name for path in CPSAT_DIR.glob("*.py")}

    assert scripts == set(EXPECTED_BY_SCRIPT)


@pytest.mark.parametrize(
    ("script", "expectation"),
    EXPECTED_BY_SCRIPT.items(),
    ids=EXPECTED_BY_SCRIPT.keys(),
)
def test_cpsat_script_output(script: str, expectation: ScriptExpectation) -> None:
    result = subprocess.run(
        [sys.executable, str(CPSAT_DIR / script)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == expectation.returncode
    assert_output(result.stdout, expectation)
    for expected in expectation.stderr_contains:
        assert expected in result.stderr


def assert_output(output: str, expectation: ScriptExpectation) -> None:
    lines = tuple(output.splitlines())

    if expectation.stdout_mode == "any_order":
        assert Counter(lines) == Counter(expectation.stdout_lines)
    elif expectation.stdout_mode == "cumulative_schedule":
        assert_cumulative_schedule_output(lines, expectation.stdout_lines)
    else:
        assert lines == expectation.stdout_lines


def assert_cumulative_schedule_output(
    lines: tuple[str, ...], expected_prefix: tuple[str, ...]
) -> None:
    assert lines[: len(expected_prefix)] == expected_prefix

    sizes_by_slot: dict[int, list[int]] = {0: [], 1: [], 2: []}
    assigned_sizes: list[int] = []
    seen_sum_slots: set[int] = set()
    for line in lines[len(expected_prefix) :]:
        if match := _SLOT_INCREMENT_RE.match(line):
            slot = int(match["slot"])
            size = int(match["size"])

            assert slot in sizes_by_slot
            sizes_by_slot[slot].append(size)
            assigned_sizes.append(size)
            continue

        if match := _SLOT_SUM_RE.match(line):
            slot = int(match["slot"])
            total = int(match["total"])

            assert slot in sizes_by_slot
            assert sum(sizes_by_slot[slot]) == total
            assert total <= 6
            seen_sum_slots.add(slot)
            continue

        pytest.fail(f"unexpected cumulative output line: {line}")

    assert Counter(assigned_sizes) == Counter([1, 4, 6, 2, 3])
    assert seen_sum_slots == {0, 1, 2}
