// Statiske tests af appen: syntaks, version, filer der refereres findes, og kendte faldgruber.
const html = await Deno.readTextFile(new URL("../index.html", import.meta.url));
const root = new URL("../", import.meta.url);
const ok = (c: boolean, msg: string) => { if (!c) throw new Error(msg); };
const exists = async (p: string) => { try { await Deno.stat(new URL(p, root)); return true; } catch { return false; } };

Deno.test("index.html: scriptet kan parses", () => {
  const i = html.lastIndexOf("<script>"), j = html.lastIndexOf("</script>");
  new Function(html.slice(i + 8, j));
});

Deno.test("versionen står som f.eks. 0.3.2.0 (beta)", () => {
  const m = html.match(/name="app-version" content="([^"]+)"/);
  ok(!!m && /^\d+(\.\d+){2,3}( \(beta\))?$/.test(m[1]), "app-version mangler eller har forkert format");
});

Deno.test("lokale billeder og ikoner, som appen peger på, findes", async () => {
  const refs = new Set<string>();
  for (const m of html.matchAll(/(?:src|href)="((?:badges|icons)\/[^"?#]+)"/g)) refs.add(m[1]);
  for (const m of html.matchAll(/['"](badges\/[A-Za-z0-9_-]+\.(?:png|svg))['"]/g)) refs.add(m[1]);
  for (const f of ["favicon.png", "favicon.ico", "apple-touch-icon.png", "manifest.webmanifest", "sw.js"]) refs.add(f);
  const missing: string[] = [];
  for (const r of refs) if (!(await exists(r))) missing.push(r);
  ok(missing.length === 0, "mangler: " + missing.join(", "));
});

Deno.test("manifestet: navn og ikoner", async () => {
  const m = JSON.parse(await Deno.readTextFile(new URL("manifest.webmanifest", root)));
  ok(m.name === "PL Draft" && m.short_name === "PL Draft", "navn skal være PL Draft");
  for (const ic of m.icons) ok(await exists(ic.src), "ikon mangler: " + ic.src);
});

Deno.test("appen er kun på engelsk (ingen danske tegn i synlige tekster)", () => {
  const i = html.lastIndexOf("<script>"), j = html.lastIndexOf("</script>");
  // kommentarer må gerne være på dansk; vi fjerner dem før tjek
  const code = html.slice(i + 8, j).replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/[^\n]*/g, "");
  const hits = [...code.matchAll(/["'`][^"'`\n]*[æøåÆØÅ][^"'`\n]*["'`]/g)].map((m) => m[0]).filter((s) => !/runde|røde|gule|scoret/.test(s));
  ok(hits.length === 0, "danske tekster: " + hits.slice(0, 5).join(" | "));
});

Deno.test("rekordtabellerne i Hall of Fame har ikke ratings-visning eller testdata", () => {
  ok(!html.includes("show_ratings?'<span"), "ratings vises igen");
  ok(!/Demo FC/.test(html), "demodata i appen");
});

Deno.test("migrationerne har unikke, stigende numre (027 mangler fra tidligere og er med vilje tilladt)", async () => {
  const names: string[] = [];
  for await (const f of Deno.readDir(new URL("supabase/migrations/", root))) if (f.name.endsWith(".sql")) names.push(f.name);
  names.sort();
  names.forEach((n, i) => { if (i > 0) ok(Number(n.slice(0, 3)) > Number(names[i - 1].slice(0, 3)), `dublet eller forkert rækkefølge ved ${n}`); });
});
