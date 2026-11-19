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
  if ! git -C "$p" push --follow-tags origin HEAD:main; then
    # HTTPS-кредов нет, а SSH-ключ есть — пробуем тот же репо по ssh.
    ssh_url=${url/https:\/\/github.com\//git@github.com:}
    if [ "$ssh_url" != "$url" ]; then
      echo "   ↻ повтор по ssh: ${ssh_url#git@}"
      git -C "$p" push --follow-tags "$ssh_url" HEAD:main || fail=1
    else
      fail=1
    fi
  fi
done

umbrella=$(git remote get-url origin)
echo "== push зонтик → ${umbrella#https://github.com/}"
if ! git push origin main; then
  ssh_url=${umbrella/https:\/\/github.com\//git@github.com:}
  if [ "$ssh_url" != "$umbrella" ] && git push "$ssh_url" main; then
    :
  else
    fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo
  echo " пуш завершился с ошибками — зонтик отправляй ПОВТОРНО только после"
  echo " успешного пуша всех плагинов"
  exit 1
fi
echo "готово: семья на GitHub"
