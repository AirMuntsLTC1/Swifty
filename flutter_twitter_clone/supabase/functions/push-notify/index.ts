// Sends Firebase push notifications for new activity rows and direct/group
// messages. Configure Database Webhooks for INSERT on notifications and
// messages; see README_REALTIME_PUSH_FIX.md.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FCM_SA = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "{}");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WEBHOOK_SECRET = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";
const CHANNEL_ID = "swifs_social_notifications";
const KIND_SWITCH: Record<string, string> = {
  like: "like_notifications",
  comment: "comment_notifications",
  follow: "follow_notifications",
  follow_request: "follow_notifications",
  follow_accept: "follow_notifications",
};

const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
  auth: { persistSession: false },
});

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
  if (!FCM_SA.client_email || !FCM_SA.private_key || !FCM_SA.project_id) {
    throw new Error("FCM_SERVICE_ACCOUNT must be the Firebase service-account JSON with client_email, private_key and project_id");
  }
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
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(input),
  );
  const assertion = `${input}.${b64urlBytes(new Uint8Array(sig))}`;
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const json = await response.json();
  if (!response.ok || !json.access_token) {
    throw new Error("Google OAuth token request failed: " + JSON.stringify(json));
  }
  cached = {
    token: json.access_token,
    exp: now + Number(json.expires_in ?? 3600),
  };
  return cached.token;
}

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
    case "list_add": return { title: "Added to a List", body: `${who} added you to a list` };
    case "list_join": return { title: "New Member", body: `${who} joined your list` };
    case "list_request": return { title: "Join Request", body: `${who} asked to join your list` };
    case "list_request_accepted": return { title: "Request Accepted", body: `${who} accepted your request to join a list` };
    case "list_post": return { title: "New List Post", body: `${who} posted in a list you are on` };
    default: return { title: "New Activity", body: `${who} sent you a notification` };
  }
}

async function allowedRecipients(ids: string[], sender: string | null): Promise<string[]> {
  let list = [...new Set(ids)].filter((id) => id && id !== sender);
  if (list.length === 0) return [];

  if (sender) {
    const { data: blocks, error } = await admin
      .from("blocked_users")
      .select("blocker, blocked")
      .or(`blocker.eq.${sender},blocked.eq.${sender}`);
    if (error) throw error;
    const blocked = new Set<string>();
    for (const row of blocks ?? []) {
      blocked.add(row.blocker === sender ? row.blocked : row.blocker);
    }
    list = list.filter((id) => !blocked.has(id));
  }
  return list;
}

async function settingsFor(ids: string[]) {
  const { data, error } = await admin
    .from("user_settings")
    .select("user_id, push_notifications, like_notifications, comment_notifications, follow_notifications")
    .in("user_id", ids);
  if (error) throw error;
  return new Map((data ?? []).map((row) => [row.user_id, row]));
}

async function sendTo(
  tokens: { token: string; user_id: string }[],
  title: string,
  body: string,
  data: Record<string, string>,
) {
  if (tokens.length === 0) return { sent: 0, failed: 0, removed: 0 };
  const access = await accessToken();
  const url = `https://fcm.googleapis.com/v1/projects/${FCM_SA.project_id}/messages:send`;
  let sent = 0;
  let failed = 0;
  let removed = 0;

  await Promise.all(tokens.map(async ({ token }) => {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${access}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: {
            priority: "HIGH",
            notification: {
              channel_id: CHANNEL_ID,
              tag: data.tag ?? undefined,
              sound: "default",
            },
          },
        },
      }),
    });

    if (response.ok) {
      sent++;
      return;
    }

    const responseText = await response.text();
    failed++;
    // Remove only tokens explicitly reported as unregistered. INVALID_ARGUMENT
    // may indicate a malformed payload and must not erase a valid device token.
    if (responseText.includes("UNREGISTERED")) {
      const { error } = await admin.from("user_devices").delete().eq("token", token);
      if (error) console.error("Could not remove stale FCM token", error);
      else removed++;
    } else {
      console.error("FCM send failed", response.status, responseText);
    }
  }));
  return { sent, failed, removed };
}

Deno.serve(async (request) => {
  try {
    if (request.method !== "POST") {
      return Response.json({ error: "method_not_allowed" }, { status: 405 });
    }
    if (WEBHOOK_SECRET && request.headers.get("x-webhook-secret") !== WEBHOOK_SECRET) {
      return new Response("forbidden", { status: 403 });
    }

    const payload = await request.json();
    if (payload.type !== "INSERT") {
      return Response.json({ skipped: "not_an_insert" });
    }

    const record = payload.record ?? {};
    let recipients: string[] = [];
    let sender: string | null = null;
    let title = "Swifs";
    let body = "";
    let data: Record<string, string> = {};
    let kind = "";

    if (payload.schema !== "public") {
      return Response.json({ skipped: "not_public_schema" });
    }

    if (payload.table === "notifications") {
      // Direct messages are pushed from messages INSERT to avoid duplicates.
      if (record.type === "message") return Response.json({ skipped: "message_row" });
      kind = String(record.type ?? "activity");
      recipients = record.user_id ? [String(record.user_id)] : [];
      sender = record.actor_id ? String(record.actor_id) : null;
      const copy = describe(kind, record.actor_name || record.actor_handle || "Someone");
      title = copy.title;
      body = copy.body;
      data = {
        kind,
        tag: `activity-${String(record.id ?? crypto.randomUUID())}`,
        notification_id: String(record.id ?? ""),
        sender_id: sender ?? "",
        actor_id: sender ?? "",
        post_id: record.post_id ? String(record.post_id) : "",
      };
    } else if (payload.table === "messages") {
      sender = record.sender ? String(record.sender) : null;
      if (!sender) return Response.json({ skipped: "message_without_sender" });

      const { data: senderRow, error: profileError } = await admin
        .from("profiles")
        .select("display_name, username")
        .eq("id", sender)
        .maybeSingle();
      if (profileError) throw profileError;
      const who = senderRow?.display_name || senderRow?.username || "Someone";

      if (record.group_id) {
        const { data: members, error: memberError } = await admin
          .from("group_members")
          .select("user_id")
          .eq("group_id", record.group_id);
        if (memberError) throw memberError;
        recipients = (members ?? []).map((member) => String(member.user_id));
        const { data: group, error: groupError } = await admin
          .from("groups")
          .select("name")
          .eq("id", record.group_id)
          .maybeSingle();
        if (groupError) throw groupError;
        title = group?.name || "Group message";
      } else {
        recipients = record.recipient ? [String(record.recipient)] : [];
        title = who;
      }

      const preview = String(record.text ?? "").trim();
      body = preview ? `${who}: ${preview}` : `${who} sent you a message`;
      data = {
        kind: "message",
        tag: `message-${String(record.id ?? crypto.randomUUID())}`,
        message_id: String(record.id ?? ""),
        sender_id: sender,
        recipient_id: record.recipient ? String(record.recipient) : "",
        group_id: record.group_id ? String(record.group_id) : "",
      };
    } else {
      return Response.json({ skipped: `unknown_table_${String(payload.table)}` });
    }

    const allowed = await allowedRecipients(recipients, sender);
    if (allowed.length === 0) return Response.json({ sent: 0, reason: "no_allowed_recipients" });

    const settings = await settingsFor(allowed);
    const switchName = KIND_SWITCH[kind];
    const wanted = allowed.filter((id) => {
      const setting = settings.get(id);
      if (!setting) return true;
      if (setting.push_notifications === false) return false;
      if (switchName && setting[switchName] === false) return false;
      return true;
    });
    if (wanted.length === 0) return Response.json({ sent: 0, reason: "disabled_by_settings" });

    const { data: devices, error: deviceError } = await admin
      .from("user_devices")
      .select("token, user_id")
      .in("user_id", wanted);
    if (deviceError) throw deviceError;

    const result = await sendTo(devices ?? [], title, body, data);
    return Response.json(result);
  } catch (error) {
    console.error("push-notify failed", error);
    return Response.json({ error: "push_delivery_failed" }, { status: 500 });
  }
});


