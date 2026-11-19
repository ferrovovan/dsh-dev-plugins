#!/usr/bin/env bash
# Семейная проверка по STANDART.md для всех репозиториев из .gitmodules.
# Неприкасаема к содержимому подмодулей: неинициализированный репо помечается
# пропущенным, а не упавшим. Гоняется локально (`make family`) и в CI.
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
skip=0
ok=0
note() { echo "  ✗ $1"; fail=$((fail + 1)); }

paths=$(git config -f .gitmodules --get-regexp '\.path$' | awk '{print $2}')
if [ -z "$paths" ]; then
  echo "family: ошибка — в .gitmodules нет ни одного подмодуля"
  exit 1
fi

for p in $paths; do
  echo "== $p"
  if [ ! -f "$p/package.json" ]; then
    echo "  ⊘ пропущен: подмодуль не инициализирован (git submodule update --init)"
    skip=$((skip + 1))
    continue
  fi
  before=$fail

  report() { while IFS= read -r line; do [ -n "$line" ] && note "$line"; done <<< "$1"; }

  # 1. Манифест, обязательные файлы, locale, иконка, CHANGELOG.
  report "$(node --input-type=module -e '
    import { readFileSync, existsSync } from "node:fs"
    const p = process.argv[1]
    const dir = p.replace(/\/$/, "").split("/").pop()
    const m = JSON.parse(readFileSync(p + "/package.json", "utf8"))
    const bad = []
    const req = (cond, msg) => { if (!cond) bad.push(msg) }
    req(m.name === "@local/" + dir, `name: ожидается @local/${dir}, а "${m.name}" (§3)`)
    req(/^\d+\.\d+\.\d+$/.test(m.version || ""), "version не semver: " + m.version + " (§1)")
    req(m.type === "module", "type должен быть module (§3)")
    req(m.private === true, "private должен быть true (§3)")
    req(!!m.description, "нет description (§3)")
    req(m.dsh?.bundle?.patch, "нет dsh.bundle.patch (§3)")
    req(!Object.keys(m.dependencies || {}).length, "npm-зависимостей быть не должно: plain JS (§3)")
    req(m.exports?.["."] === "./index.js", "exports[.] должен вести на ./index.js (§3)")
    req(!!(m.exports?.["./client"] || m.exports?.["./client.js"]) === existsSync(p + "/client.js"),
        "client.js и exports расходятся (§3)")
    for (const need of ["index.js", "cordis.patch.yml", "locale/*.json", "icon.svg"]) {
      req((m.files || []).includes(need), "в files нет " + need + " (§3)")
    }
    for (const file of m.files || []) {
      req(existsSync(p + "/" + file.replace(/\*.*$/, "")), "files ссылается на отсутствующий " + file)
    }
    for (const f of ["README.md", "ARCH.md", "INTERNAL.md", "CHANGELOG.md", "SOUL.md",
                     "Makefile", "scripts/check.sh", "locale/ru.json", "locale/en.json"]) {
      req(existsSync(p + "/" + f) && readFileSync(p + "/" + f, "utf8").trim() !== "", "нет или пуст " + f + " (§2)")
    }
    for (const loc of ["ru", "en"]) {
      try {
        const j = JSON.parse(readFileSync(`${p}/locale/${loc}.json`, "utf8"))
        req(j.meta?.title && j.meta?.description, `locale/${loc}.json: нужны meta.title и meta.description (§9)`)
      } catch { bad.push(`locale/${loc}.json не читается или не JSON (§9)`) }
    }
    req(readFileSync(p + "/icon.svg", "utf8").includes("<svg"), "icon.svg не SVG (§9)")
    req(readFileSync(p + "/CHANGELOG.md", "utf8").includes(m.version),
        `CHANGELOG.md не упоминает версию ${m.version} (§13)`)
    console.log(bad.join("\n"))
  ' "$p" 2>&1)"

  # 2. Синтаксис + контракт экспортов хост-части.
  report "$(node --input-type=module -e '
    import { readFileSync } from "node:fs"
    const p = process.argv[1]
    const m = JSON.parse(readFileSync(p + "/package.json", "utf8"))
    const mod = await import("./" + p + "/index.js")
    const bad = []
    if (typeof mod.apply !== "function") bad.push("нет export function apply (§5)")
    if (!Array.isArray(mod.inject)) bad.push("inject должен быть массивом (§5)")
    const bare = m.name.replace("@local/", "")
    if (mod.name !== bare) bad.push(`export name "${mod.name}" ≠ имя пакета "${bare}" (§5)`)
    console.log(bad.join("\n"))
  ' "$p" 2>&1)"
  [ -f "$p/client.js" ] && { node --check "$p/client.js" 2>/dev/null || note "client.js не парсится (§8)"; }

  # 3. Патч монтирования: YAML, имя пакета, секреты.
  report "$(python3 scripts/check-patch.py "$p" 2>&1)"

  # 4. Секреты в коде плагина.
  secrets=$(grep -rnIE "(api[_-]?key|pat|token|secret|password)[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"']{8,}" \
    "$p/index.js" "$p/client.js" 2>/dev/null | grep -v "credentials\|process.env\|config\." | head -3)
  [ -n "$secrets" ] && report "возможный секрет в открытом коде (§12):
$secrets"

  # 5. Тулы: обязательный output{schema,render} (контракт харнесса 0.2.2, §6).
  if grep -q "tools.register" "$p/index.js" 2>/dev/null; then
    grep -q "output:" "$p/index.js" || note "региструет тул без output{schema,render} — харнесс бросит TypeError (§6)"
    grep -q "render:" "$p/index.js" || note "тул без output.render (§6)"
  fi

  if [ "$fail" -eq "$before" ]; then echo "  ✓ ok"; ok=$((ok + 1)); fi
done

echo
echo "family: ok=${ok} пропущено=${skip} ошибок=${fail}"
[ "$fail" -eq 0 ] || exit 1
