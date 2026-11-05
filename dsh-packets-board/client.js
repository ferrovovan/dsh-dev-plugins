/**
 * «Борт пакетов» — половина клиента: вкладка правого сайдбара «Пакеты».
 * Регистрирует тип вкладки (sidebarRightTabs) и тело/заголовок в
 * keyed-слотах sidebar.right.pane.tab{.title}; данные — роут хоста.
 */
window.__ModuleLoader__.load({
  id: '@local/dsh-packets-board',
  factory(require) {
    const React = require('react')
    const h = React.createElement
    const TAB_ID = '@local/dsh-packets-board/board'
    const TAB_KIND = 'packetsBoard'
    const ROUTE = '/api/master-packets'

    const statusStyle = (status) => ({
      padding: '4px',
      color: /сдан|готов|closed|done/i.test(status || '')
        ? 'var(--dsw-alias-success, #2e7d32)'
        : /в работ|in.?progress/i.test(status || '')
          ? 'var(--dsw-alias-warning, #f9a825)'
          : 'var(--dsw-alias-text-tertiary, #90a4ae)',
    })

    function BoardBody() {
      const [data, setData] = React.useState(null)
      const [error, setError] = React.useState(null)
      const load = React.useCallback(() => {
        fetch(ROUTE, { headers: { accept: 'application/json' } })
          .then((response) => (response.ok ? response.json() : Promise.reject(new Error('HTTP ' + response.status))))
          .then((value) => { setData(value); setError(null) })
          .catch((cause) => setError(String(cause && cause.message ? cause.message : cause)))
      }, [])
      React.useEffect(() => {
        load()
        const timer = setInterval(load, 30_000)
        return () => clearInterval(timer)
      }, [load])

      if (error) {
        return h('div', { style: { padding: 12, color: 'var(--dsw-alias-danger, #c62828)', fontSize: 12 } },
          'Борт недоступен: ' + error + ' (проверьте авторизацию роута — INTERNAL.md)')
      }
      if (!data) return h('div', { style: { padding: 12, fontSize: 12 } }, 'Загрузка…')

      return h('div', { style: { padding: 8, overflow: 'auto', fontSize: 12 } },
        h('div', { style: { display: 'flex', gap: 8, alignItems: 'center', marginBottom: 8 } },
          h('button', { onClick: load }, 'Обновить'),
          h('span', null, 'пакетов: ' + (data.packets || []).length + ' · сессий: ' + (data.agents || []).length)),
        data.error ? h('div', { style: { color: 'var(--dsw-alias-danger, #c62828)' } }, data.error) : null,
        h('table', { style: { width: '100%', borderCollapse: 'collapse' } },
          h('thead', null, h('tr', null, ['пакет', 'статус', 'модель', 'бюджет м', 'зона'].map((title) => h('th', { style: { textAlign: 'left', padding: 4 } }, title)))),
          h('tbody', null, (data.packets || []).map((packet) => h('tr', { key: packet.dir },
            h('td', { style: { padding: 4 } }, packet.package || packet.dir),
            h('td', { style: statusStyle(packet.status) }, packet.status || '—'),
            h('td', { style: { padding: 4 } }, packet.model || '—'),
            h('td', { style: { padding: 4 } }, packet.budget_m || '—'),
            h('td', { style: { padding: 4, maxWidth: 150, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' } }, packet.zone_write || '—'))))))
    }

    function BoardTitle() { return h('span', null, 'Пакеты') }

    return {
      inject: ['slots', 'sidebarRightTabs'],
      apply(ctx) {
        ctx.effect(() => ctx.sidebarRightTabs.register({
          id: TAB_ID, kind: TAB_KIND, priority: 'extension', title: () => 'Пакеты',
        }), 'packets-board.tab')
        ctx.effect(() => ctx.slots.register({ name: 'sidebar.right.pane.tab', key: TAB_ID }, BoardBody), 'packets-board.body')
        ctx.effect(() => ctx.slots.register({ name: 'sidebar.right.pane.tab.title', key: TAB_ID }, BoardTitle), 'packets-board.title')
      },
    }
  },
})
