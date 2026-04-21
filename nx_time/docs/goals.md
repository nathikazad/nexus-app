## 5. Client-side derivation (informative)

Server-owned fields per goal: `daily_state` (action goals), `streak`
(action goals), `period_value` (expense goals), and the passthrough
config. Everything else the UI shows is computed client-side from
those fields plus the local action / expense store.

### Top-right label / hero values

The client filters its local store by `model_type`, re-evaluates
`filter` over `attrs`, groups by `attrs[selected_attribute]::date`,
and formats per the display-units convention.

### Status (`on_track | at_risk | missed`)

Action goals (`target.op = >=`):

```text
hits    := count(daily_state where state == 'hit')
pending := count(daily_state where state == 'pending')
needed  := cadence == 'daily' ? 7 : target.value

remaining := max(0, needed - hits)
if remaining == 0:                  status = on_track
elif remaining <= pending:          status = at_risk
else:                               status = missed
```

Expense goals (`target.op = <=`):

```text
pace := target.value × (days_elapsed / days_in_month)
if period_value > target.value:     status = missed
elif period_value > pace:           status = at_risk
else:                               status = on_track
```

### Progress / days_left

- `progress` = `min(1, period_value / target.value)` (expense) or
  `min(1, hits / needed)` (action).
- `days_left` = remaining days in the period from
  `daily_state[*].date` (action) or month length minus elapsed
  (expense).

### Trend chart

Bar height = `successes / expected`; colour = `hit`. Same render for
every goal type because `(successes, expected)` always share a unit
within a bucket (see §3).
