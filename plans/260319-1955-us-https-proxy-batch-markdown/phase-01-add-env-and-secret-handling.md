# Phase 1: Add Env and Secret Handling

**Priority:** High
**Status:** Complete
**Effort:** Small

## Context

- Files: `.env.example`, `.gitignore`, `scripts/urnet-proxy.sh`
- Requirement: main secret file is `.env`, committed template is `.env.example`

## Requirements

- add `.env.example` with `AUTH_CODE`
- ensure `.env` is gitignored
- keep command usable with either `AUTH_CODE` or `URNETWORK_JWT`

## Implementation Steps

1. Add `.env` loading at script startup
2. Add `AUTH_CODE` fallback in auth logic
3. Add `.env` and `!.env.example` in `.gitignore`
4. Create `.env.example` template

## Todo

- [x] `.env` loader added
- [x] `AUTH_CODE` fallback added
- [x] `.gitignore` updated
- [x] `.env.example` created

## Success Criteria

- user can run script without passing auth code in CLI
- secrets are not committed by default
