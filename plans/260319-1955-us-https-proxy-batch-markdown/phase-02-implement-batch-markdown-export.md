# Phase 2: Implement Batch Markdown Export

**Priority:** High
**Status:** Complete
**Effort:** Medium

<!-- Updated: Validation Session 1 - retry/backoff, input validation, and country consistency -->

## Context

- File: `scripts/urnet-proxy.sh`
- API endpoints: `/network/auth-client`, `/network/clients`

## Requirements

- create 100 US HTTPS proxies in one command
- write output to `.md` file with proxy details
- fail early when requested count exceeds client capacity
- validate `count` as positive integer before any API call
- use provided `country` in proxy descriptions and markdown heading
- retry transient API errors (`429`/`5xx`) with bounded backoff

## Validation Checklist (Closed)

All checklist items closed in Session 2.

1. Closed: positive-integer validation for `count` before any API call.
Validation command: `./scripts/urnet-proxy.sh batch-md abc us /tmp/proxies.md` (expect exit `1` + `count must be a positive integer`)
Validation command: `./scripts/urnet-proxy.sh batch-md 0 us /tmp/proxies.md` (expect exit `1` + `count must be greater than 0`)
2. Closed: country label/description consistency using `${country^^}`.
Validation command: `rg -n "country_upper|HTTPS Proxy #" scripts/urnet-proxy.sh`
3. Closed: bounded retry/backoff for transient failures (`429`/`5xx`/curl transient).
Validation command: `rg -n "is_transient_status|create_proxy_with_retry|Retrying in" scripts/urnet-proxy.sh`

## Todo

- [x] helper request function added
- [x] `batch-md` command added
- [x] max client slot check added
- [x] markdown table output added
- [x] command wired in CLI case block
- [x] positive integer validation added for `count`
- [x] country label/description consistency fixed
- [x] transient retry/backoff added for create API call

## Success Criteria

- `./scripts/urnet-proxy.sh batch-md 100 us us-https-proxies.md` works
- output file contains 100 table rows when capacity allows
- invalid count inputs fail with clear message
- transient API failures are retried and then fail with explicit summary
