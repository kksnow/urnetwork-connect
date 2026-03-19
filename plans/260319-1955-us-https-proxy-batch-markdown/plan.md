# Plan: 100 US HTTPS Proxies to Markdown (ck:plan)

**Date:** 2026-03-19
**Status:** Complete
**Primary File:** `scripts/urnet-proxy.sh`

## Goal

Ship a repeatable workflow that:
- reads `AUTH_CODE` from `.env`
- creates 100 US HTTPS proxies via URnetwork API
- writes proxy outputs to a Markdown file

## Approach

Update existing script instead of creating a new tool:
- extend `scripts/urnet-proxy.sh` with `batch-md`
- add `.env` loading and auth bootstrap from `AUTH_CODE`
- keep `.env` out of git and add `.env.example`

## Phases

| # | Phase | Status | Priority |
|---|---|---|---|
| 1 | [Add env + secret handling](phase-01-add-env-and-secret-handling.md) | Complete | High |
| 2 | [Implement batch markdown export](phase-02-implement-batch-markdown-export.md) | Complete | High |
| 3 | [Validate and usage contract](phase-03-validate-and-usage-contract.md) | Complete | Medium |

## Progress Snapshot

- phase status: `3/3` complete
- phase todo checkboxes: `17/17` complete
- open todo items: none

## Constraints

- Network client cap is 128 per account network
- Markdown output contains sensitive proxy/auth data
- Keep changes minimal and script-focused

## Success Criteria

- `.env.example` exists with `AUTH_CODE`
- `scripts/urnet-proxy.sh batch-md 100 us <file>.md` is available
- script loads `.env` automatically
- syntax check passes (`bash -n`)

## Validation Log

### Session 1 - 2026-03-19
**Trigger:** `/ck:plan --validate plans/260319-1955-us-https-proxy-batch-markdown/plan.md`
**Questions asked:** 5

#### Questions & Answers

1. **[Risks]** How should sensitive proxy credentials in Markdown output be handled by default?
   - Options: Keep current behavior and rely on user discipline | Write file with restricted permissions (`chmod 600`) and warn in output (Recommended) | Remove auth token column from export
   - **Answer:** Write file with restricted permissions (`chmod 600`) and warn in output
   - **Rationale:** Markdown contains reusable auth tokens; default secure file permissions reduce accidental disclosure risk.

2. **[Tradeoffs]** What failure strategy should batch creation use for transient API issues (`429`/`5xx`)?
   - Options: Fail immediately on first error | Add bounded retries with backoff and final fail (Recommended) | Continue silently and skip failed rows
   - **Answer:** Add bounded retries with backoff and final fail
   - **Rationale:** Avoids brittle failure for temporary API instability while preserving correctness.

3. **[Assumptions]** Should `batch-md` validate numeric input before arithmetic and loops?
   - Options: Trust shell arithmetic errors | Enforce positive integer count before API calls (Recommended)
   - **Answer:** Enforce positive integer count before API calls
   - **Rationale:** Prevents malformed input from producing confusing shell errors or partial execution.

4. **[Scope]** Should country handling stay US-specific or remain generic where possible?
   - Options: Keep US-only labels and descriptions | Keep command generic and use provided country value in labels/description (Recommended)
   - **Answer:** Keep command generic and use provided country value in labels/description
   - **Rationale:** Command already accepts country argument; behavior and output should stay consistent with that surface.

5. **[Architecture]** How should partial output be handled when batch job fails mid-run?
   - Options: Keep partial file and exit with explicit failure summary (Recommended) | Delete output file on error | Best-effort continue until count reached
   - **Answer:** Keep partial file and exit with explicit failure summary
   - **Rationale:** Preserves created proxies for recovery/audit while maintaining non-zero exit for automation.

#### Confirmed Decisions
- Output security: write markdown with restricted permissions and explicit warning.
- Reliability: add bounded retry/backoff for transient API failures.
- Input safety: validate `count` as positive integer pre-flight.
- Consistency: use passed `country` in description/output text.
- Failure contract: keep partial file, but fail command with clear summary.

#### Action Items
- [x] Update Phase 2 requirements and steps for retry/backoff, numeric validation, and country label consistency.
- [x] Update Phase 3 usage contract for partial-file failure semantics and output permission checks.

#### Impact on Phases
- Phase 2: add resilience and input validation requirements.
- Phase 3: extend validation checklist for security and failure-contract behavior.

### Session 2 - 2026-03-19
**Execution:** `/ck:cook --auto plans/260319-1955-us-https-proxy-batch-markdown/plan.md`

#### Completed
- Added positive integer `count` validation before `batch-md` auth/API flow.
- Added country-consistent heading + proxy description using `${country^^}`.
- Added bounded retry/backoff for transient create errors (`429`/`5xx`) and curl transient failures.
- Added markdown output permission hardening with `chmod 600`.
- Added explicit partial-failure contract in runtime output + help text.
- Hardened output path handling with symlink rejection.

#### Validation
- `bash -n scripts/urnet-proxy.sh` passed.
- `./scripts/urnet-proxy.sh help` includes updated `batch-md` contract text.
- `./scripts/urnet-proxy.sh batch-md abc` fails early with clear count error.
- `./scripts/urnet-proxy.sh batch-md 0` fails early with clear count error.
- `go test ./...` could not run in this environment (`go: command not found`).

#### Residual Risk
- End-to-end runtime validation against live transient API failures (`429`/`5xx`) needs controllable fault conditions.
