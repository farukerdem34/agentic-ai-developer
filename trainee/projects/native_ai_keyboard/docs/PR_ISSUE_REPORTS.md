# PR — Project - Native AI Keyboard -> Issue Reports, iOS Report Sheet UX, and Edge submit-issue-report

Use the **title** line above in GitHub. Paste the sections below into the PR description.

---

## Objective

Ship **Report a problem** from the iOS host app through Supabase: persist feedback in `public.issue_reports`, optionally notify the project owner via Resend. Improve the in-app sheet (TR/EN copy, daily-limit UX, safe error messages) and add hosted deploy/smoke documentation.

## Architecture & packages

| Layer | Change |
|--------|--------|
| **Supabase DB** | `issue_reports` table; RLS on, no client policies (Edge uses service role). |
| **Edge** | `submit-issue-report` — device Bearer token, UTC rate limit, insert, optional Resend. |
| **iOS host** | `FeedbackReporter` + `ReportProblemSheet` in `ContentView`; App Group daily cap + dev plist bypass. |
| **Docs** | `OPEN_ISSUES.md` (Resend delivery), README checklists, smoke/dev scripts. |

### Backend endpoints

| Method | Path | Auth |
|--------|------|------|
| `POST` | `/functions/v1/register-device` | — (existing) |
| `POST` | `/functions/v1/submit-issue-report` | `Authorization: Bearer <deviceTransformToken>` |

## Tasks

1. Add migration `20250521120000_issue_reports.sql` and deploy `submit-issue-report` Edge function (`verify_jwt = false`; token auth in handler).
2. Wire iOS `FeedbackReporter` to POST report body + device metadata; map 404/500/429 to user-facing `IssueReportL10n` errors (no raw gateway JSON in the sheet).
3. Implement report sheet: vertical `TextField`, locked-state card when local daily cap reached, orange dev banner when `AIKeyboardIssueReportBypassDailyLimit` is true.
4. Document hosted setup (`supabase db push`, secrets, smoke script) and track Resend inbox gap in `docs/OPEN_ISSUES.md`.
5. Add `ISSUE_REPORT_BYPASS_UTC_RATE_LIMIT` Edge secret for same-day server retesting (dev only).

## Checklist

- [ ] `supabase db push` — `issue_reports` exists on hosted project
- [ ] `supabase functions deploy submit-issue-report`
- [ ] `./supabase/scripts/smoke-submit-issue-report.sh` → 201, then 429
- [ ] Device: **Report a problem** → row in `public.issue_reports`
- [ ] After one local report: locked sheet (no disabled field / keyboard trap)
- [ ] Resend secrets optional; if mail missing, see `docs/OPEN_ISSUES.md`
- [ ] Before release: `AIKeyboardIssueReportBypassDailyLimit` = false; remove or disable `ISSUE_REPORT_BYPASS_UTC_RATE_LIMIT`

## Known issue

- **Resend email** may not reach `REPORT_TO_EMAIL` while DB insert succeeds — [`docs/OPEN_ISSUES.md`](./OPEN_ISSUES.md) item 1.

## Related

- Plan: [`../docs/projects/native_ai_keyboard_plan/`](../docs/projects/native_ai_keyboard_plan/README.md)
- Supabase: [`../supabase/README.md`](../supabase/README.md)
- iOS QA: [`../ios-keyboard/README.md`](../ios-keyboard/README.md) — Manual QA: Report a problem
