// Sends Firebase push for new notifications and direct or group messages.
// Called by Supabase database webhooks (see README_FIRST.txt).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FCM_SA = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "{}");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WEBHOOK_SECRET = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";
const CHANNEL_ID = "swifs_social_notifications";

const admin = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

// ---------- Google OAuth for FCM (service account, RS256 JWT) ----------

let cached: { token: string; exp: number } | null = null;

function b64urlBytes(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function b64url(text: string): string {
  return b64urlBytes(new TextEncoder().encode(text));
}

function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out.buffer;
}

async function accessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.exp - 60 > now) return cached.token;

  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: FCM_SA.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const input = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(FCM_SA.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(input));
  const assertion = `${input}.${b64urlBytes(new Uint8Array(sig))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const json = await res.json();
  if (!res.ok) throw new Error("Google sign-in failed: " + JSON.stringify(json));
  cached = { token: json.access_token, exp: now + Number(json.expires_in ?? 3600) };
  return cached.token;
}

// ---------- Helpers ----------

/** Title and text for each activity kind. Titles match the in-app notifications. */
function describe(kind: string, who: string): { title: string; body: string } {
  switch (kind) {
    case "follow": return { title: "New Follower", body: `${who} started following you` };
    case "follow_request": return { title: "Follow Request", body: `${who} wants to follow you` };
    case "follow_accept": return { title: "Request Accepted", body: `${who} accepted your follow request` };
    case "like": return { title: "New Like", body: `${who} liked your post` };
    case "comment": return { title: "New Comment", body: `${who} commented on your post` };
    case "save": return { title: "Post Saved", body: `${who} saved your post` };
    case "story_reaction":
    case "reaction": return { title: "Story Reaction", body: `${who} reacted to your story` };
    case "story_reply": return { title: "Story Reply", body: `${who} replied to your story` };
    default: return { title: "New Activity", body: `${who} sent you a notification` };
  }
}

/** Which user_settings switch controls each notification kind. Kinds not listed only need push_notifications. */
const KIND_SWITCH: Record<string, string> = {
  like: "like_notifications",
  comment: "comment_notifications",
  follow: "follow_notifications",
  follow_request: "follow_notifications",
  follow_accept: "follow_notifications",
};

async function allowedRecipients(ids: string[], sender: string | null): Promise<string[]> {
  let list = [...new Set(ids)].filter((id) => id && id !== sender);
  if (list.length === 0) return [];

  // Users who blocked the sender, or whom the sender blocked, get nothing.
  if (sender) {
    const { data: blocks } = await admin
      .from("blocked_users")
      .select("blocker, blocked")
      .or(`blocker.eq.${sender},blocked.eq.${sender}`);
    const blocked = new Set<string>();
    for (const b of blocks ?? []) {
      blocked.add(b.blocker === sender ? b.blocked : b.blocker);
    }
    list = list.filter((id) => !blocked.has(id));
  }
  return list;
}

async function settingsFor(ids: string[]) {
  const { data } = await admin
    .from("user_settings")
    .select("user_id, push_notifications, like_notifications, comment_notifications, follow_notifications")
    .in("user_id", ids);
  return new Map((data ?? []).map((row) => [row.user_id, row]));
}

async function sendTo(tokens: { token: string; user_id: string }[], title: string, body: string, data: Record<string, string>) {
  if (tokens.length === 0) return { sent: 0, removed: 0 };
  const access = await accessToken();
  const url = `https://fcm.googleapis.com/v1/projects/${FCM_SA.project_id}/messages:send`;
  let sent = 0;
  let removed = 0;

  await Promise.all(tokens.map(async ({ token }) => {
    const res = await fetch(url, {
      method: "POST",
      headers: { Authorization: `Bearer ${access}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: {
            priority: "HIGH",
            notification: { channel_id: CHANNEL_ID, tag: data.tag ?? undefined },
          },
        },
      }),
    });
    if (res.ok) {
      sent++;
      return;
    }
    const text = await res.text();
    // The phone uninstalled the app or the token expired: forget it.
    if (text.includes("UNREGISTERED") || text.includes("INVALID_ARGUMENT")) {
      await admin.from("user_devices").delete().eq("token", token);
      removed++;
    } else {
      console.error("FCM error", res.status, text);
    }
  }));
  return { sent, removed };
}

// ---------- Entry point ----------

Deno.serve(async (req) => {
  if (WEBHOOK_SECRET && req.headers.get("x-webhook-secret") !== WEBHOOK_SECRET) {
    return new Response("forbidden", { status: 403 });
  }

  const payload = await req.json();
  if (payload.type !== "INSERT") return Response.json({ skipped: "not an insert" });

  const record = payload.record ?? {};
  let recipients: string[] = [];
  let sender: string | null = null;
  let title = "Swifs";
  let body = "";
  let data: Record<string, string> = {};
  let kind = "";

  if (payload.table === "notifications") {
    // DMs are pushed from the messages table below, so skip the duplicate row here.
    if (record.type === "message") return Response.json({ skipped: "message row" });
    kind = String(record.type ?? "");
    recipients = [record.user_id];
    sender = record.actor_id ?? null;
    const copy = describe(kind, record.actor_name || record.actor_handle || "Someone");
    title = copy.title;
    body = copy.body;
    // Same tag the phone uses for realtime alerts, so one activity shows once.
    data = { kind, tag: `activity-${record.id}` };
  } else if (payload.table === "messages") {
    sender = record.sender ?? null;
    const { data: senderRow } = await admin
      .from("profiles")
      .select("display_name, username")
      .eq("id", sender)
      .maybeSingle();
    const who = senderRow?.display_name || senderRow?.username || "Someone";

    if (record.group_id) {
      const { data: members } = await admin
        .from("group_members")
        .select("user_id")
        .eq("group_id", record.group_id);
      recipients = (members ?? []).map((m) => m.user_id);
      const { data: group } = await admin
        .from("groups")
        .select("name")
        .eq("id", record.group_id)
        .maybeSingle();
      title = group?.name || "Group message";
    } else {
      recipients = [record.recipient];
    }

    const preview = (record.text ?? "").toString().trim();
    body = preview ? `${who}: ${preview}` : `${who} sent you a message`;
    data = { kind: "message", tag: `message-${record.id}` };
  } else {
    return Response.json({ skipped: `unknown table ${payload.table}` });
  }

  const allowed = await allowedRecipients(recipients, sender);
  if (allowed.length === 0) return Response.json({ sent: 0 });

  // Honour the user's notification switches. A missing row means "on".
  const settings = await settingsFor(allowed);
  const switchName = KIND_SWITCH[kind];
  const wanted = allowed.filter((id) => {
    const s = settings.get(id);
    if (!s) return true;
    if (s.push_notifications === false) return false;
    if (switchName && s[switchName] === false) return false;
    return true;
  });
  if (wanted.length === 0) return Response.json({ sent: 0 });

  const { data: devices } = await admin
    .from("user_devices")
    .select("token, user_id")
    .in("user_id", wanted);

  const result = await sendTo(devices ?? [], title, body, data);
  return Response.json(result);
});
