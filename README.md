# Dynamo Run Board

A one-page view of the Dynamo Review workflow status across every
`handshake-project-dynamo` repo forked into `Harsh-1Byte`.

## Refresh

```
./refresh.sh
```

`collect.sh` pulls PRs + check runs for every fork via `gh`, writes `data.json`.
`build.py` embeds that into `index.html` from `template.html`.
The page is fully self-contained — open `index.html` in any browser.

## Reading it

Each row is one task repo: its latest PR, and the Dynamo Review stages in the
order the workflow runs them. Green passed, red failed, amber still running,
faded skipped. Click a stage to jump to its job log; click the task id for the repo.
Tiles at the top filter; the search box matches task id, category, branch, or PR title.
