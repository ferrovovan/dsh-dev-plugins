#!/usr/bin/env bash
# Пуш семьи: сначала ВСЕ плагины (иначе зонтик будет ссылаться на коммиты,
# которых на GitHub нет, и CI упадёт на checkout --recursive), затем зонтик.
# Креды для GitHub должны быть настроены у запускающего (gh auth login,
# git credential helper или SSH) — скрипт их не хранит и не запрашивает.
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
paths=$(git config -f .gitmodules --get-regexp '\.path$' | awk '{print $2}')

for p in $paths; do
  url=$(git -C "$p" remote get-url origin 2>/dev/null)
  if [ -z "$url" ]; then
    echo "✗ $p: нет origin — создай репозиторий и git -C $p remote add origin <url>"
    fail=1
    continue
  fi
  echo "== push $p → ${url#https://github.com/}"
  git -C "$p" push --follow-tags origin HEAD:main || fail=1
done

umbrella=$(git remote get-url origin)
echo "== push зонтик → ${umbrella#https://github.com/}"
git push origin main || fail=1

if [ "$fail" -ne 0 ]; then
  echo
  echo " пуш завершился с ошибками — зонтик отправляй ПОВТОРНО только после"
  echo " успешного пуша всех плагинов"
  exit 1
fi
echo "готово: семья на GitHub"
