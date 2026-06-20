# {{INVESTIGATION_ID}} — Instrumentation Log

> Chronological narrative. One entry per probe added/removed or per significant observation.
> Append-only — never rewrite history; if a hypothesis is wrong, add a new entry that says so.

<!-- Entry format:

## HH:MM — [add probe pN | observe | hypothesis update | remove probe pN]

**Probe:** pN at `path/to/file.ext:42` capturing `[vars]`
**Run:** [what was reproduced]
**Reading:** [excerpt from runtime.jsonl, with line ref]
**Outcome:** confirms H1 | eliminates H1 | inconclusive — [why]
**Next:** [add probe pN+1 | refine H2 | conclude on H1]

-->

## Forwarding remote logs (when the bug is not local)

If the affected process runs on a remote host, forward its log stream into the local Yaga log server:

```bash
PORT=$(jq -r .port server.json)
ssh user@host 'tail -F /var/log/app.log' \
  | while IFS= read -r line; do
      curl -s -X POST "http://127.0.0.1:${PORT}/log" \
        -H 'content-type: application/json' \
        --data-binary "{\"msg\": $(jq -Rs . <<< "$line")}"
    done
```

If forwarding is not possible, paste excerpts here under a `## HH:MM — pasted` entry and call them out in `findings.md`.
