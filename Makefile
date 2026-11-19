# Сборка = проверки. Плагины plain JS, транспиляции нет.
REPOS := dsh-rashod-live dsh-packets-board dsh-mailbox dsh-wave-gate-tool dsh-codex-board dsh-promt-studio dsh-word-basket

.PHONY: check family $(REPOS)
check: $(REPOS)
$(REPOS):
	@if [ ! -f $@/Makefile ]; then echo "== $@ ⊘ подмодуль не инициализирован — пропуск"; exit 0; fi; echo "== $@"; $(MAKE) -C $@ check
family:
	@bash scripts/check-family.sh
