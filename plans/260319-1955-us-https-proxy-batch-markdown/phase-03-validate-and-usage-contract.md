# Phase 3: Validate and Usage Contract

**Priority:** Medium
**Status:** Complete
**Effort:** Small

<!-- Updated: Validation Session 1 - output security and partial-failure contract -->

## Context

- File: `scripts/urnet-proxy.sh`
- Validation target: no syntax errors, clear command surface

## Requirements

- script must pass `bash -n`
- script help must describe new command
- output contract must be explicit (`.md` file path)
- markdown output file permissions must be restricted (`chmod 600`)
- failure contract must state partial file behavior on mid-run errors

## Validation Checklist (Closed)

All checklist items closed in Session 2.

1. Closed: secure markdown output mode (`chmod 600`).
Validation command: `rg -n "chmod 600" scripts/urnet-proxy.sh`
Validation command (live): `./scripts/urnet-proxy.sh batch-md 1 us /tmp/us-https-proxies.md && stat -c '%a %n' /tmp/us-https-proxies.md` (expect mode `600`)
2. Closed: partial-failure contract in help and runtime output.
Validation command: `./scripts/urnet-proxy.sh help | sed -n '1,120p'`
Validation command: `rg -n "Partial file kept intentionally|on mid-run failure" scripts/urnet-proxy.sh`
3. Closed: baseline command-surface validation rerun.
Validation command: `bash -n scripts/urnet-proxy.sh`
Validation command: `./scripts/urnet-proxy.sh batch-md abc us /tmp/proxies.md` (expect exit `1`)
Validation command: `./scripts/urnet-proxy.sh batch-md 0 us /tmp/proxies.md` (expect exit `1`)

## Todo

- [x] syntax check completed
- [x] command help includes `batch-md`
- [x] `.env.example` aligns with script variables
- [x] output permission check added to validation checklist
- [x] partial failure contract documented in help/output text

## Success Criteria

- no shell parse errors
- user can run with `.env` + one command
- output markdown defaults to restricted file permissions
- failure behavior is deterministic and documented

## Unresolved Questions

- none

## Risks / Ambiguities

- No implementation blocker found.
- Runtime proof of `429`/`5xx` retry behavior is nondeterministic without controllable upstream failures or fault injection.
