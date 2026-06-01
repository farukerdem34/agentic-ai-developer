/**
 * Issue reports from the iOS host app.
 * Auth: Bearer device token (same as `transform`). Inserts into `issue_reports` via service role.
 * Optional Resend email after insert; HTTP 201 even when mail fails.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function verifyDeviceToken(
  authHeader: string | null,
): Promise<{ ok: true; deviceId: string } | { ok: false; status: number; code: string; message: string }> {
  const m = authHeader?.match(/^Bearer\s+(.+)$/i);
  const token = m?.[1]?.trim() ?? "";
  if (!token) {
    return { ok: false, status: 401, code: "UNAUTHORIZED", message: "Missing Bearer token" };
  }
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) {
    return { ok: false, status: 500, code: "SERVER_ERROR", message: "Missing Supabase env" };
  }
  const supabase = createClient(url, key);
  const { data, error } = await supabase.from("devices").select("device_id").eq("device_token", token).maybeSingle();
  if (error) {
    return { ok: false, status: 500, code: "SERVER_ERROR", message: error.message };
  }
  if (!data?.device_id) {
    return { ok: false, status: 401, code: "UNAUTHORIZED", message: "Invalid token" };
  }
  return { ok: true, deviceId: data.device_id };
}

function utcDayStartIso(): string {
  const d = new Date();
  d.setUTCHours(0, 0, 0, 0);
  return d.toISOString();
}

async function sendOwnerEmail(opts: {
  deviceId: string;
  body: string;
  appVersion: string | null;
  build: string | null;
  osVersion: string | null;
  localeIdentifier: string | null;
  preferredLanguages: string | null;
}): Promise<{ sent: boolean; detail?: string }> {
  const apiKey = Deno.env.get("RESEND_API_KEY")?.trim();
  const fromRaw = Deno.env.get("RESEND_FROM")?.trim();
  const from = fromRaw && fromRaw.length > 0 ? fromRaw : "onboarding@resend.dev";
  const toRaw = Deno.env.get("REPORT_TO_EMAIL")?.trim() ?? "";
  const to = toRaw.split(/[,;\s]+/).map((s) => s.trim()).find((s) => s.includes("@")) ?? "";

  if (!apiKey || !to) {
    return { sent: false, detail: "RESEND_API_KEY or REPORT_TO_EMAIL not set (Dashboard → Edge → Secrets)" };
  }

  const usingTestFrom = /onboarding@resend\.dev/i.test(from);

  const subject = `[AI Keyboard] Issue report (${opts.deviceId.slice(0, 8)}…)`;
  const text =
    `device_id: ${opts.deviceId}\n` +
    `app_version: ${opts.appVersion ?? ""}\n` +
    `build: ${opts.build ?? ""}\n` +
    `os: ${opts.osVersion ?? ""}\n` +
    `locale: ${opts.localeIdentifier ?? ""}\n` +
    `languages: ${opts.preferredLanguages ?? ""}\n\n` +
    `${opts.body}`;

  const html =
    `<p><strong>device_id</strong> ${escapeHtml(opts.deviceId)}</p>` +
    `<p><strong>app</strong> ${escapeHtml(opts.appVersion ?? "")} (${escapeHtml(opts.build ?? "")})<br/>` +
    `<strong>OS</strong> ${escapeHtml(opts.osVersion ?? "")}<br/>` +
    `<strong>locale</strong> ${escapeHtml(opts.localeIdentifier ?? "")}<br/>` +
    `<strong>languages</strong> ${escapeHtml(opts.preferredLanguages ?? "")}</p>` +
    `<pre style="white-space:pre-wrap">${escapeHtml(opts.body)}</pre>`;

  const payload = { from, to: [to], subject, text, html };

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  const raw = await res.text();
  if (!res.ok) {
    const hint = usingTestFrom
      ? " Tip: with onboarding@resend.dev, Resend often only delivers to the inbox you used to sign up for Resend — set REPORT_TO_EMAIL to that address, or verify a domain and set RESEND_FROM."
      : "";
    console.warn("[submit-issue-report] Resend error", res.status, raw.slice(0, 500));
    return { sent: false, detail: `Resend HTTP ${res.status}: ${raw.slice(0, 400)}${hint}` };
  }

  let resendId: string | undefined;
  try {
    const j = JSON.parse(raw) as { id?: string; message?: string; name?: string };
    if (typeof j.id === "string" && j.id.length > 0) resendId = j.id;
    if (j.name === "validation_error" || (j.message && !j.id)) {
      console.warn("[submit-issue-report] Resend body error", raw.slice(0, 400));
      return { sent: false, detail: `Resend: ${j.message ?? raw.slice(0, 400)}` };
    }
  } catch {
    // non-JSON success body — still treat as sent if HTTP ok
  }

  const okDetail = [
    resendId ? `resend_id=${resendId}` : "resend_ok",
    usingTestFrom
      ? "If inbox is empty: test sender may only deliver to your Resend account email — match REPORT_TO_EMAIL or verify a domain."
      : "",
  ].filter(Boolean).join(" | ");

  console.log("[submit-issue-report] mail sent", { to, from, resendId });
  return { sent: true, detail: okDetail };
}

function escapeHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: { code: "METHOD_NOT_ALLOWED", message: "POST only" } }, 405);

  const auth = await verifyDeviceToken(req.headers.get("Authorization"));
  if (!auth.ok) {
    return json({ error: { code: auth.code, message: auth.message } }, auth.status);
  }
  const deviceId = auth.deviceId;

  let body: Record<string, unknown>;
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    return json({ error: { code: "INVALID_INPUT", message: "Invalid JSON" } }, 400);
  }

  const reportBody = String(body?.body ?? "").trim();
  if (reportBody.length < 10) {
    return json({ error: { code: "INVALID_INPUT", message: "body must be at least 10 characters" } }, 400);
  }

  const appVersion = typeof body.appVersion === "string" ? body.appVersion.trim() : null;
  const build = typeof body.build === "string" ? body.build.trim() : null;
  const osVersion = typeof body.osVersion === "string" ? body.osVersion.trim() : null;
  const localeIdentifier = typeof body.localeIdentifier === "string" ? body.localeIdentifier.trim() : null;
  const preferredLanguages = typeof body.preferredLanguages === "string" ? body.preferredLanguages.trim() : null;

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) {
    return json({ error: { code: "SERVER_ERROR", message: "Missing Supabase env" } }, 500);
  }
  const supabase = createClient(url, key);

  // Dev-only secret; omit in production (see `docs/OPEN_ISSUES.md` and ios-keyboard README).
  const bypassUtcRate = (Deno.env.get("ISSUE_REPORT_BYPASS_UTC_RATE_LIMIT") ?? "").trim().toLowerCase() === "true";

  const dayStart = utcDayStartIso();
  const { count, error: cntErr } = await supabase
    .from("issue_reports")
    .select("id", { count: "exact", head: true })
    .eq("device_id", deviceId)
    .gte("created_at", dayStart);

  if (cntErr) {
    return json({ error: { code: "SERVER_ERROR", message: cntErr.message } }, 500);
  }
  if (!bypassUtcRate && (count ?? 0) >= 1) {
    return json({ error: { code: "RATE_LIMITED", message: "One report per device per UTC day" } }, 429);
  }

  const { data: inserted, error: insErr } = await supabase
    .from("issue_reports")
    .insert({
      device_id: deviceId,
      body: reportBody,
      app_version: appVersion,
      build,
      os_version: osVersion,
      locale_identifier: localeIdentifier,
      preferred_languages: preferredLanguages,
    })
    .select("id")
    .maybeSingle();

  if (insErr) {
    return json({ error: { code: "SERVER_ERROR", message: insErr.message } }, 500);
  }

  // Best-effort notification; row is already persisted above.
  const mail = await sendOwnerEmail({
    deviceId,
    body: reportBody,
    appVersion,
    build,
    osVersion,
    localeIdentifier,
    preferredLanguages,
  });
  if (!mail.sent) {
    console.warn("[submit-issue-report] mail not sent:", mail.detail ?? "(no detail)");
  }

  return json(
    {
      ok: true,
      id: inserted?.id,
      mailSent: mail.sent,
      mailDetail: mail.detail,
    },
    201,
  );
});
