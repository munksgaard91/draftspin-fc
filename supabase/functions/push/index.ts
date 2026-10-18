// @ts-nocheck
// Serverfunktion "push": sender en web push-besked til alle en brugers enheder.
// Kaldes kun fra databasen (pg_net) med den delte hemmelighed i x-push-secret.
// Svarer straks med 202 og sender bagefter, så leveringen ikke afhænger af pg_nets tålmodighed.
import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

async function send(cfg, user_id, title, body, tag) {
  webpush.setVapidDetails(cfg.subject, cfg.vapid_public, cfg.vapid_private);
  const subs = (await admin.from("push_subs").select("id,endpoint,p256dh,auth").eq("user_id", user_id)).data || [];
  const payload = JSON.stringify({ title: title || "DraftSpin FC", body: body || "", tag: tag || "draftspin" });
  const gone = [], codes = [];
  await Promise.all(subs.map(async (s) => {
    try {
      await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 300, urgency: "high" });
      codes.push(201);
    } catch (e) {
      codes.push(e.statusCode || 0);
      if (e.statusCode === 404 || e.statusCode === 410) gone.push(s.id);
    }
  }));
  if (gone.length) await admin.from("push_subs").delete().in("id", gone);
  console.log("push", user_id, "abonnementer", subs.length, "statuskoder", codes.join(","));
}

Deno.serve(async (req) => {
  try {
    const cfgRows = (await admin.from("push_config").select("key,value")).data || [];
    const cfg = Object.fromEntries(cfgRows.map((r) => [r.key, r.value]));
    if (!cfg.secret || req.headers.get("x-push-secret") !== cfg.secret) return new Response("forbidden", { status: 403 });
    const { user_id, title, body, tag } = await req.json();
    if (!user_id) return new Response("bad request", { status: 400 });
    const work = send(cfg, user_id, title, body, tag).catch((e) => console.log("push fejl", String(e && e.message || e)));
    if (typeof EdgeRuntime !== "undefined" && EdgeRuntime.waitUntil) EdgeRuntime.waitUntil(work); else await work;
    return new Response("accepted", { status: 202 });
  } catch (e) {
    console.log("push fejl", String(e && e.message || e));
    return new Response("error", { status: 500 });
  }
});
