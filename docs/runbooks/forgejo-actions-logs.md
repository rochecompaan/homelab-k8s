# Forgejo Actions: Access job logs via API

> **REHEARSAL ONLY** — The API behavior in this runbook was verified on Forgejo
> `16.0.4-rootless` in an isolated rehearsal clone on 2026-09-12. Production
> runs `15.0.5-rootless`. Update this runbook after you verify the same
> endpoints in production on v16.

## Scope

This runbook gives you the commands to list jobs in a workflow run and to
download their logs. Use it in two cases: the web UI is not accessible, or
you need the raw log content.

Two tool paths are documented: `tea api` for interactive use, and `curl`
with `jq` for scripts. Never pass a token as a command-line argument.

## API routes

| Action | Method | Path |
|---|---|---|
| List jobs in a run | GET | `/api/v1/repos/{OWNER}/{REPO}/actions/runs/{RUN_ID}/jobs` |
| Get job log (plaintext) | GET | `/api/v1/repos/{OWNER}/{REPO}/actions/jobs/{JOB_ID}/logs` |
| Get job log for an attempt | GET | `/api/v1/repos/{OWNER}/{REPO}/actions/jobs/{JOB_ID}/logs?attempt={ATTEMPT}` |
| Get full run log (ZIP) | GET | `/api/v1/repos/{OWNER}/{REPO}/actions/runs/{RUN_ID}/logs` |

Replace each `{...}` placeholder with the actual value before you run the command.

| Placeholder | Meaning |
|---|---|
| `{OWNER}` | Repository owner username |
| `{REPO}` | Repository name |
| `{RUN_ID}` | Global API run ID of the run object (see Run number vs API run ID) |
| `{JOB_ID}` | Job ID from the jobs array (see List jobs below) |
| `{ATTEMPT}` | Attempt number, starting at `1` |

## Run number vs API run ID

The run URL in the web UI ends with a repository-local run number, for
example `.../actions/runs/1`. The web UI resolves that number inside the
repository. The API routes in this runbook resolve `{RUN_ID}` as the global
`id` field of the run object. The two values can differ.

Rehearsal proof: run number `1` in `roche/forgejo-v16-rehearsal-20260912`
has API run ID `207`. If you use the run number as the API run ID, you get
a `404` or the wrong run.

### Resolve a run number to the API run ID

The runs-list response holds one object per run. The field `index_in_repo`
is the repository-local run number. The field `id` is the global API run ID.

#### tea api

```bash
tea api --method GET /repos/{OWNER}/{REPO}/actions/runs \
  | jq -r '.workflow_runs[] | select(.index_in_repo == {RUN_NUMBER}) | .id'
```

#### curl

```bash
curl --silent --show-error \
  -K ~/.forgejo-curl-auth \
  "${FORGEJO_URL}/api/v1/repos/{OWNER}/{REPO}/actions/runs" \
  | jq -r '.workflow_runs[] | select(.index_in_repo == {RUN_NUMBER}) | .id'
```

Replace `{RUN_NUMBER}` with the run number from the web UI URL. Use the
result as `{RUN_ID}` in all commands of this runbook.

## Forgejo 16 jobs-list response shape

Forgejo 16 returns a bare JSON array from the jobs endpoint.

```
GET /api/v1/repos/{OWNER}/{REPO}/actions/runs/{RUN_ID}/jobs
→ [ { "id": 683, "name": "detect-changes", "status": "success", ... }, ... ]
```

Earlier releases returned `{ "jobs": [...] }`. This change breaks the
`tea actions run jobs` command, which expects the object shape. The
`--follow` path in `tea` also needs a job-detail route that v16 does not
provide. Use `tea api` or `curl` with `jq` instead.

## Prerequisites

### tea

Install `tea` and add a login for the Forgejo instance:

```bash
tea login list
```

At least one login must appear with the correct instance URL before you run
`tea api` commands.

### curl and jq

Put your token in a curl config file with mode `0600`. Never pass the token
as a command-line argument or store it in shell history.

```bash
umask 077
builtin printf 'header = "Authorization: token %s"\n' "$(cat /path/to/token-file)" \
  > ~/.forgejo-curl-auth
chmod 0600 ~/.forgejo-curl-auth
```

This example requires Bash. The `builtin` prefix makes sure that the Bash
builtin `printf` runs. An external `printf` process would receive the token
as an argument and would show it in the process list. The builtin keeps the
token out of the process list.

Replace `/path/to/token-file` with the path to a file that holds your API
token. The token file must not be world-readable.

Set the server URL once:

```bash
FORGEJO_URL=https://git.example.com
```

When you no longer need the curl config file, remove it:

```bash
rm -f ~/.forgejo-curl-auth
```

## List jobs in a run

### tea api

```bash
tea api --method GET \
  /repos/{OWNER}/{REPO}/actions/runs/{RUN_ID}/jobs \
  | jq '[.[] | {id, name, status, attempt}]'
```

### curl

```bash
curl --silent --show-error \
  -K ~/.forgejo-curl-auth \
  "${FORGEJO_URL}/api/v1/repos/{OWNER}/{REPO}/actions/runs/{RUN_ID}/jobs" \
  | jq '[.[] | {id, name, status, attempt}]'
```

Each element in the array has an `id` field. Use that value as `{JOB_ID}`
in the commands below.

To get only the IDs and names:

```bash
curl --silent --show-error \
  -K ~/.forgejo-curl-auth \
  "${FORGEJO_URL}/api/v1/repos/{OWNER}/{REPO}/actions/runs/{RUN_ID}/jobs" \
  | jq -r '.[] | "\(.id)\t\(.name)"'
```

## Get job log (plaintext)

The response is plain text with one log line per row.

### Latest attempt — tea api

```bash
tea api --method GET \
  /repos/{OWNER}/{REPO}/actions/jobs/{JOB_ID}/logs
```

### Latest attempt — curl

```bash
curl --silent --show-error \
  -K ~/.forgejo-curl-auth \
  "${FORGEJO_URL}/api/v1/repos/{OWNER}/{REPO}/actions/jobs/{JOB_ID}/logs"
```

### Specific attempt — tea api

```bash
tea api --method GET \
  "/repos/{OWNER}/{REPO}/actions/jobs/{JOB_ID}/logs?attempt={ATTEMPT}"
```

### Specific attempt — curl

```bash
curl --silent --show-error \
  -K ~/.forgejo-curl-auth \
  "${FORGEJO_URL}/api/v1/repos/{OWNER}/{REPO}/actions/jobs/{JOB_ID}/logs?attempt={ATTEMPT}"
```

Attempts start at `1`. If you omit `?attempt=`, the server returns the
latest attempt log.

## Get the full run log (ZIP)

The response is a ZIP file that contains one log entry per job.

### curl

```bash
curl --silent --show-error \
  -K ~/.forgejo-curl-auth \
  "${FORGEJO_URL}/api/v1/repos/{OWNER}/{REPO}/actions/runs/{RUN_ID}/logs" \
  -o "run-${RUN_ID}.zip"
unzip -l "run-${RUN_ID}.zip"
```

### tea api

```bash
tea api --method GET \
  /repos/{OWNER}/{REPO}/actions/runs/{RUN_ID}/logs \
  > "run-${RUN_ID}.zip"
```

After you download the ZIP, verify that it opens correctly:

```bash
unzip -tqq "run-${RUN_ID}.zip"
```

## Authentication

Private repositories require a valid token.

| Condition | HTTP status |
|---|---|
| No token | 404 |
| Invalid token | 401 |
| Valid token, run ID of a different repository | 404 |
| Valid token, job ID of a different repository | 404 |
| Valid token, correct repository and IDs | 200 |

A missing token returns `404`, not `401`. Do not treat a `404` as proof that
a run or job does not exist. If a request returns `404` unexpectedly, add a
valid token and retry.

## One-command pipeline: list jobs then fetch the first log

```bash
FIRST_JOB=$(curl --silent --show-error \
  -K ~/.forgejo-curl-auth \
  "${FORGEJO_URL}/api/v1/repos/{OWNER}/{REPO}/actions/runs/{RUN_ID}/jobs" \
  | jq -r '.[0].id')
curl --silent --show-error \
  -K ~/.forgejo-curl-auth \
  "${FORGEJO_URL}/api/v1/repos/{OWNER}/{REPO}/actions/jobs/${FIRST_JOB}/logs"
```

## Verification evidence (rehearsal, 2026-09-12)

The following results came from the isolated v16 rehearsal clone.
They are not production evidence.

- Jobs endpoint: HTTP `200`, top-level type `array`, five jobs for run `204`.
- Job log endpoint: HTTP `200`, `Content-Type: text/plain; charset=utf-8`,
  `13808` bytes.
- Same endpoint with `?attempt=1`: HTTP `200`, content identical to
  latest-attempt response.
- Run log endpoint: HTTP `200`, `Content-Type: application/zip`, `44978`
  bytes, five ZIP entries, `unzip -tqq` passed.
- Missing token: job log `404`, run log `404`.
- Invalid token: job log `401`, run log `401`.
- Valid token, cross-repository run ID on the jobs-list route: `404`.

### Run-number and cross-repository checks (final review wave)

These checks ran against the same isolated clone through a localhost
port-forward. No historical workflow ran again.

- Runs list for `roche/forgejo-v16-rehearsal-20260912`: run number
  (`index_in_repo`) `1` resolved to API run ID `207`.
- Run number `1` used directly as the API run ID in that repository: `404`.
- Positive control, rehearsal job log with matching repository: HTTP `200`,
  `text/plain`, 362 bytes, marker `FORGEJO_REHEARSAL_PROTOCOL_OK` present.
- Positive control, rehearsal run ZIP with matching repository: HTTP `200`,
  `application/zip`, 421 bytes, one entry, `unzip -tqq` passed.
- Positive control, `roche/croprun` run `204` ZIP with matching repository:
  HTTP `200`, `application/zip`, 44978 bytes, five entries, `unzip -tqq` passed.
- Mismatched repository/job ID: job ID `683` of `roche/croprun` on the
  plaintext-log route of the rehearsal repository returned `404`. The body
  was a JSON error object with no log content.
- Reverse case: job ID `698` of the rehearsal repository on the
  plaintext-log route of `roche/croprun` returned `404`. The body was a
  JSON error object with no log content.
- Mismatched repository/run ID: run ID `204` of `roche/croprun` on the ZIP
  route of the rehearsal repository returned `404`. The body was a JSON
  error object with no log content.
- Reverse case: run ID `207` of the rehearsal repository on the ZIP route
  of `roche/croprun` returned `404`. The body was a JSON error object with
  no log content.
- Recheck on both log routes: missing token `404`, invalid token `401`.
