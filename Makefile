# Сборка = проверки. Плагины plain JS, транспиляции нет.
REPOS := dsh-rashod-live dsh-packets-board dsh-mailbox dsh-wave-gate-tool dsh-codex-board

.PHONY: check $(REPOS)
check: $(REPOS)
$(REPOS):
	@echo "== $@"; $(MAKE) -C $@ check
