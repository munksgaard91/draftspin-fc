// Push-beskeder er fjernet (2026-10-23). Funktionen findes kun, fordi den ikke kan slettes herfra; den gør ingenting.
Deno.serve(() => new Response("gone", { status: 410 }));
