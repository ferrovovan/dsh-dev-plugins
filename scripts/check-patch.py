#!/usr/bin/env python3
"""Проверка cordis.patch.yml плагина по стандартам семьи (STANDART.md §4).

Выводит по одной строке на находку, код возврата 1 при любой находке.
"""
import json
import re
import sys

import yaml

SECRET = re.compile(r"(api[_-]?key|token|secret|password|pat)\s*[:=]\s*\S", re.I)

problems: list[str] = []


def check(path: str) -> None:
    try:
        with open(path + "/package.json", encoding="utf-8") as handle:
            pkg_name = json.load(handle)["name"]
    except (OSError, KeyError, ValueError) as error:
        problems.append(f"package.json не читается: {error}")
        return

    try:
        with open(path + "/cordis.patch.yml", encoding="utf-8") as handle:
            raw = handle.read()
    except OSError as error:
        problems.append(f"cordis.patch.yml не читается: {error}")
        return

    try:
        data = yaml.safe_load(raw)
    except yaml.YAMLError as error:
        marker = getattr(error, "problem_mark", None)
        where = f" (строка {marker.line + 1})" if marker else ""
        problems.append(f"cordis.patch.yml: невалидный YAML{where}")
        return

    if not isinstance(data, list) or not data:
        problems.append("cordis.patch.yml: ожидается непустой список строк монтирования")
        return

    if pkg_name not in raw:
        problems.append(f"cordis.patch.yml: нет имени пакета {pkg_name}")

    for index, row in enumerate(data):
        if not isinstance(row, dict):
            problems.append(f"cordis.patch.yml[{index}]: элемент должен быть отображением")
            continue
        if not ({"insert", "id", "override", "group", "remove"} & row.keys()):
            problems.append(f"cordis.patch.yml[{index}]: нет действия (insert/id/…)")

    for number, line in enumerate(raw.splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("#") or "!!js" in line:
            continue
        if SECRET.search(line) and "credentials" not in line:
            problems.append(f"cordis.patch.yml:{number}: похоже на секрет в открытом виде")


for target in sys.argv[1:]:
    check(target)

for problem in problems:
    print(problem)
sys.exit(1 if problems else 0)
