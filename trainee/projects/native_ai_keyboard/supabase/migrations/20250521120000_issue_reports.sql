-- Issue reports from the iOS host app.
-- Edge `submit-issue-report` inserts via service role; host never writes this table directly.
-- RLS enabled with no policies: anon/authenticated PostgREST cannot insert if the table is exposed.

create table if not exists public.issue_reports (
  id uuid primary key default gen_random_uuid(),
  device_id text not null,
  body text not null,
  created_at timestamptz not null default now(),
  app_version text,
  build text,
  os_version text,
  locale_identifier text,
  preferred_languages text
);

create index if not exists issue_reports_device_id_created_at_idx
  on public.issue_reports (device_id, created_at desc);

alter table public.issue_reports enable row level security;

-- No policies: only service role (Edge) bypasses RLS for inserts.
