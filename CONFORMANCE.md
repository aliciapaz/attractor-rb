# Spec Conformance

Upstream spec: [strongdm/attractor](https://github.com/strongdm/attractor)
Pinned commit: `2f892efd63ee7c11f038856b90aae57c067b77c2` (2026-02-20)

## Deliberate Divergences

| Spec Section | Spec Says | Implementation Does | Reason |
|---|---|---|---|
| Appendix A, `default_max_retry` | Default `50` | Default `0` | 50 retries per node is too aggressive for most pipelines; opt-in via graph attr |

## Not Yet Implemented

- `auto_status` synthesis (Appendix C) — engine does not synthesize status.json when handler skips it
- `fidelity` resolution (Section 4.5) — Fidelity class exists but preamble transform is a no-op
- `stack.manager_loop` graceful interrupt — handler polls but has no cancellation mechanism
- `tool_hooks.pre` / `tool_hooks.post` (Appendix A) — not wired into handler execution
- `stack.child_dotfile` / `stack.child_workdir` (Appendix A) — not implemented
- Event stream transport for TUI/web frontends (Section 9.6) — EventEmitter exists but no SSE/socket layer
