// Live disposable-project validation. Run only with the documented opt-in.
// Uses the public anon key for HTTP requests and the logged-in Supabase CLI
// for narrowly scoped test setup/cleanup SQL. No privileged API key is used.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join, resolve } from 'node:path';

const root = resolve(fileURLToPath(new URL('../..', import.meta.url)));
const ref = process.env.SUPABASE_TEST_PROJECT_REF;
const url = process.env.SUPABASE_URL;
const anonKey = process.env.SUPABASE_ANON_KEY;
const cli = join(root, 'node_modules', 'supabase', 'dist', 'supabase.js');
const linkedRefFile = join(root, 'supabase', '.temp', 'project-ref');
const reportFile = join(root, 'supabase', '.temp', 'live_integration_report.json');

assert.equal(process.env.SUPABASE_TEST_DISPOSABLE, '1', 'Explicit disposable-project opt-in is required');
assert.match(ref ?? '', /^[a-z]{20}$/, 'Set SUPABASE_TEST_PROJECT_REF');
assert.equal(url, `https://${ref}.supabase.co`, 'SUPABASE_URL must match the project ref');
assert.ok(anonKey && !anonKey.startsWith('sb_secret_'), 'Set a public SUPABASE_ANON_KEY');
assert.ok(existsSync(cli), 'Install the project-local Supabase CLI first');
assert.equal(readFileSync(linkedRefFile, 'utf8').trim(), ref, 'Linked project ref differs');

const runId = randomBytes(5).toString('hex');
const emailPrefix = `gg-live-${runId}`;
const scenarios = [
  'User cannot self-promote to ADMIN',
  'Signup metadata cannot create ADMIN',
  'Guide cannot self-verify',
  'Unrelated tourist cannot read a private booking',
  'Tourist cannot create a booking for another tourist',
  'Unrelated guide cannot act on a booking',
  'Direct client booking status update is blocked',
  'Valid booking RPC transitions succeed',
  'Invalid booking RPC transition fails',
  'Review before completion fails',
  'Completed-booking owner review succeeds',
  'Duplicate review fails',
  'Ordinary user cannot publish a destination',
  'Trusted ADMIN can publish a destination',
  'Verification document is not publicly readable',
  'Unauthorized private download and signed URL fail',
  'Guide and ADMIN can access verification evidence',
  'Permitted owner operations still work',
].map((name, index) => ({ number: index + 1, name, status: 'UNTESTED' }));

const actors = {};
const created = { destination: null, experience: null, booking: null, files: [] };
const extra = [];

function dbQuery(sql) {
  const result = spawnSync(process.execPath,
    [cli, 'db', 'query', '--linked', '--project-ref', ref, sql],
    { cwd: root, encoding: 'utf8', timeout: 90000 });
  if (result.error || result.status !== 0) {
    throw new Error(`Trusted SQL query failed: ${(result.stderr ?? result.error?.message ?? '').trim().slice(0, 500)}`);
  }
  const output = JSON.parse(result.stdout);
  if (!Array.isArray(output.rows)) throw new Error('CLI query returned no rows array');
  return output.rows;
}

function uuid(value) {
  assert.match(value ?? '', /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i);
  return `'${value}'::uuid`;
}

async function http(path, { method = 'GET', actor, body, headers = {}, raw = false } = {}) {
  const requestHeaders = { apikey: anonKey, Authorization: `Bearer ${actor?.jwt ?? anonKey}`, ...headers };
  let payload;
  if (body !== undefined) {
    if (raw) payload = body;
    else {
      requestHeaders['Content-Type'] = 'application/json';
      payload = JSON.stringify(body);
    }
  }
  const response = await fetch(`${url}${path}`, {
    method, headers: requestHeaders, body: payload, signal: AbortSignal.timeout(30000),
  });
  const contentType = response.headers.get('content-type') ?? '';
  const resultBody = contentType.includes('application/json') ? await response.json() : await response.text();
  return { ok: response.ok, status: response.status, body: resultBody };
}

function detail(response) {
  const value = response.body;
  const message = typeof value === 'object' && value !== null
    ? [value.code ?? value.error_code, value.msg ?? value.message ?? value.error]
      .filter(Boolean).map(String).join(': ')
    : '';
  return `HTTP ${response.status}${message ? ` (${message.slice(0, 120)})` : ''}`;
}

function rows(response) {
  assert.equal(response.ok, true, detail(response));
  assert.ok(Array.isArray(response.body), `Expected a JSON row array, got ${detail(response)}`);
  return response.body;
}

function denied(response) {
  return !response.ok || (Array.isArray(response.body) && response.body.length === 0);
}

async function check(number, operation) {
  const scenario = scenarios[number - 1];
  try {
    await operation();
    scenario.status = 'PASS';
    console.log(`PASS ${number}: ${scenario.name}`);
  } catch (error) {
    scenario.status = 'FAIL';
    scenario.detail = String(error?.message ?? error).slice(0, 250);
    console.error(`FAIL ${number}: ${scenario.name}: ${scenario.detail}`);
    throw error;
  }
}

async function signUp(label, metadata) {
  const email = `${emailPrefix}-${label}@example.com`;
  const password = `${randomBytes(18).toString('base64url')}Aa1!`;
  const response = await http('/auth/v1/signup', {
    method: 'POST', body: { email, password, data: metadata },
  });
  assert.equal(response.ok, true, `Auth signup ${label}: ${detail(response)}`);
  const id = response.body?.user?.id ?? response.body?.id;
  uuid(id);
  actors[label] = { id, email, password, jwt: response.body?.session?.access_token ?? null };
  return actors[label];
}

async function signIn(actor) {
  if (actor.jwt) return;
  const response = await http('/auth/v1/token?grant_type=password', {
    method: 'POST', body: { email: actor.email, password: actor.password },
  });
  assert.equal(response.ok, true, `Auth sign-in: ${detail(response)}`);
  assert.ok(response.body?.access_token, 'Auth sign-in returned no access token');
  actor.jwt = response.body.access_token;
}

function setRole(actor, role) {
  assert.ok(['TOURIST', 'GUIDE', 'ADMIN'].includes(role));
  dbQuery(`update public.profiles set role='${role}' where id=${uuid(actor.id)} returning id;`);
}

function kathmanduDate() {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Kathmandu', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(new Date());
  const get = (part) => parts.find((item) => item.type === part).value;
  return `${get('year')}-${get('month')}-${get('day')}`;
}

async function rpc(actor, bookingId, target) {
  return http('/rest/v1/rpc/transition_booking', {
    method: 'POST', actor, body: { p_booking_id: bookingId, p_target: target },
  });
}

async function upload(bucket, path, actor, mime = 'image/png') {
  // Harmless, valid one-pixel PNG; never use a real identity document.
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLttAAAAABJRU5ErkJggg==', 'base64');
  const response = await http(`/storage/v1/object/${bucket}/${path}`, {
    method: 'POST', actor, body: png, raw: true, headers: { 'Content-Type': mime, 'x-upsert': 'false' },
  });
  if (response.ok) created.files.push({ bucket, path, owner: actor });
  return response;
}

async function run() {
  const migrated = dbQuery("select count(*)::int as count from supabase_migrations.schema_migrations where version in ('20261007000100','20261007000200','20261007000300');");
  assert.equal(migrated[0].count, 3, 'All three approved migrations must be present');
  const authSettings = await http('/auth/v1/settings');
  assert.equal(authSettings.ok, true, `Cannot read Auth settings: ${detail(authSettings)}`);
  assert.equal(authSettings.body?.mailer_autoconfirm, true,
    'Temporarily disable Confirm email on this disposable project before live signup tests');

  // Signup is through the real Auth HTTP endpoint. Confirmation, when the
  // hosted project's default email verification is on, is a trusted test SQL
  // operation against only these disposable fake identities.
  const tourist = await signUp('tourist', {});
  const guide = await signUp('guide', { requested_role: 'GUIDE' });
  const other = await signUp('spoof', { requested_role: 'ADMIN' });
  const profiles = dbQuery(`select id,role from public.profiles where id in (${uuid(tourist.id)},${uuid(guide.id)},${uuid(other.id)});`);
  assert.equal(profiles.length, 3, 'Auth trigger did not create all profiles');
  assert.equal(profiles.find((p) => p.id === tourist.id)?.role, 'TOURIST');
  assert.equal(profiles.find((p) => p.id === guide.id)?.role, 'GUIDE');
  assert.equal(profiles.find((p) => p.id === other.id)?.role, 'TOURIST');
  const guideRows = dbQuery(`select verification_status from public.guide_profiles where user_id=${uuid(guide.id)};`);
  assert.equal(guideRows[0]?.verification_status, 'PENDING', 'GUIDE must start pending');
  dbQuery(`update auth.users set email_confirmed_at=coalesce(email_confirmed_at,now()) where id in (${uuid(tourist.id)},${uuid(guide.id)},${uuid(other.id)});`);
  await Promise.all([signIn(tourist), signIn(guide), signIn(other)]);

  await check(1, async () => {
    const attempt = await http(`/rest/v1/profiles?id=eq.${tourist.id}&select=id,role`, {
      method: 'PATCH', actor: tourist, body: { role: 'ADMIN' }, headers: { Prefer: 'return=representation' },
    });
    assert.ok(denied(attempt), `Self-promotion accepted: ${detail(attempt)}`);
    assert.equal(dbQuery(`select role from public.profiles where id=${uuid(tourist.id)};`)[0].role, 'TOURIST');
  });
  await check(2, async () => {
    assert.equal(dbQuery(`select role from public.profiles where id=${uuid(other.id)};`)[0].role, 'TOURIST');
  });
  await check(3, async () => {
    const attempt = await http(`/rest/v1/guide_profiles?user_id=eq.${guide.id}&select=user_id,verification_status`, {
      method: 'PATCH', actor: guide, body: { verification_status: 'VERIFIED' }, headers: { Prefer: 'return=representation' },
    });
    assert.ok(denied(attempt), `Self-verification accepted: ${detail(attempt)}`);
    assert.equal(dbQuery(`select verification_status from public.guide_profiles where user_id=${uuid(guide.id)};`)[0].verification_status, 'PENDING');
  });

  const slug = `gg-live-${runId}`;
  const destinationPayload = { slug, name_en: 'Integration Test', name_ne: 'परीक्षण', district: 'Test', province: 'Test', is_published: true };
  await check(13, async () => {
    const attempt = await http('/rest/v1/destinations?select=id', {
      method: 'POST', actor: tourist, body: destinationPayload, headers: { Prefer: 'return=representation' },
    });
    assert.ok(denied(attempt), `Tourist publication accepted: ${detail(attempt)}`);
    assert.equal(dbQuery(`select count(*)::int as count from public.destinations where slug='${slug}';`)[0].count, 0);
  });

  setRole(other, 'ADMIN'); // Trusted SQL, never a client request.
  await check(14, async () => {
    const createdDestination = await http('/rest/v1/destinations?select=id,is_published', {
      method: 'POST', actor: other, body: destinationPayload, headers: { Prefer: 'return=representation' },
    });
    created.destination = rows(createdDestination)[0]?.id;
    uuid(created.destination);
    assert.equal(rows(createdDestination)[0].is_published, true);
    const publicRead = await http(`/rest/v1/destinations?id=eq.${created.destination}&select=id`);
    assert.equal(rows(publicRead).length, 1, 'Published destination is not publicly readable');
  });

  const experience = await http('/rest/v1/experiences?select=id', {
    method: 'POST', actor: other,
    body: { destination_id: created.destination, title_en: 'Integration Test', title_ne: 'परीक्षण', is_published: true },
    headers: { Prefer: 'return=representation' },
  });
  created.experience = rows(experience)[0]?.id;
  uuid(created.experience);

  const area = await http('/rest/v1/guide_service_areas', {
    method: 'POST', actor: guide, body: { guide_id: guide.id, destination_id: created.destination },
  });
  assert.equal(area.ok, true, `Guide service area: ${detail(area)}`);
  const request = await http('/rest/v1/guide_verification_requests?select=id,status', {
    method: 'POST', actor: guide, body: { guide_id: guide.id }, headers: { Prefer: 'return=representation' },
  });
  const verificationId = rows(request)[0]?.id;
  uuid(verificationId);
  const selfApprove = await http(`/rest/v1/guide_verification_requests?id=eq.${verificationId}&select=id`, {
    method: 'PATCH', actor: guide, body: { status: 'VERIFIED' }, headers: { Prefer: 'return=representation' },
  });
  assert.ok(denied(selfApprove), `Guide approved own request: ${detail(selfApprove)}`);
  const approval = await http(`/rest/v1/guide_verification_requests?id=eq.${verificationId}&select=id,status`, {
    method: 'PATCH', actor: other, body: { status: 'VERIFIED' }, headers: { Prefer: 'return=representation' },
  });
  assert.equal(rows(approval)[0]?.status, 'VERIFIED', 'ADMIN approval failed');
  assert.equal(dbQuery(`select verification_status from public.guide_profiles where user_id=${uuid(guide.id)};`)[0].verification_status, 'VERIFIED');
  extra.push('Guide request, denied self-approval, and ADMIN approval synchronized');

  setRole(other, 'TOURIST');
  const bookingPayload = {
    tourist_id: tourist.id, guide_id: guide.id, destination_id: created.destination,
    experience_id: created.experience, requested_date: kathmanduDate(), party_size: 2,
    message: 'Disposable integration test',
  };
  await check(5, async () => {
    const attempt = await http('/rest/v1/bookings?select=id', {
      method: 'POST', actor: tourist, body: { ...bookingPayload, tourist_id: other.id },
      headers: { Prefer: 'return=representation' },
    });
    assert.ok(denied(attempt), `Booking impersonation accepted: ${detail(attempt)}`);
  });
  const booking = await http('/rest/v1/bookings?select=id,status', {
    method: 'POST', actor: tourist, body: bookingPayload, headers: { Prefer: 'return=representation' },
  });
  created.booking = rows(booking)[0]?.id;
  uuid(created.booking);
  assert.equal(rows(booking)[0].status, 'REQUESTED');
  await check(4, async () => {
    const attempt = await http(`/rest/v1/bookings?id=eq.${created.booking}&select=id`, { actor: other });
    assert.equal(rows(attempt).length, 0, 'Unrelated tourist read private booking');
  });
  setRole(other, 'GUIDE');
  dbQuery(`insert into public.guide_profiles(user_id) values (${uuid(other.id)});`);
  await check(6, async () => {
    const attempt = await rpc(other, created.booking, 'ACCEPTED');
    assert.ok(!attempt.ok, `Unrelated guide transitioned booking: ${detail(attempt)}`);
    assert.equal(dbQuery(`select status from public.bookings where id=${uuid(created.booking)};`)[0].status, 'REQUESTED');
  });
  setRole(other, 'ADMIN');
  await check(7, async () => {
    const attempt = await http(`/rest/v1/bookings?id=eq.${created.booking}&select=id,status`, {
      method: 'PATCH', actor: guide, body: { status: 'COMPLETED' }, headers: { Prefer: 'return=representation' },
    });
    assert.ok(denied(attempt), `Direct status manipulation accepted: ${detail(attempt)}`);
    assert.equal(dbQuery(`select status from public.bookings where id=${uuid(created.booking)};`)[0].status, 'REQUESTED');
  });
  await check(9, async () => {
    const attempt = await rpc(tourist, created.booking, 'COMPLETED');
    assert.ok(!attempt.ok, `Invalid transition accepted: ${detail(attempt)}`);
    assert.equal(dbQuery(`select status from public.bookings where id=${uuid(created.booking)};`)[0].status, 'REQUESTED');
  });
  await check(10, async () => {
    const attempt = await http('/rest/v1/reviews?select=id', {
      method: 'POST', actor: tourist, body: { booking_id: created.booking, rating: 5 },
      headers: { Prefer: 'return=representation' },
    });
    assert.ok(denied(attempt), `Early review accepted: ${detail(attempt)}`);
  });
  await check(8, async () => {
    assert.equal((await rpc(guide, created.booking, 'ACCEPTED')).body?.status, 'ACCEPTED');
    assert.equal((await rpc(tourist, created.booking, 'CONFIRMED')).body?.status, 'CONFIRMED');
    assert.equal((await rpc(guide, created.booking, 'COMPLETED')).body?.status, 'COMPLETED');
  });
  await check(11, async () => {
    const response = await http('/rest/v1/reviews?select=id,guide_id', {
      method: 'POST', actor: tourist,
      body: { booking_id: created.booking, rating: 5, comment: 'Disposable test' },
      headers: { Prefer: 'return=representation' },
    });
    assert.equal(rows(response)[0]?.guide_id, guide.id, 'Review guide was not derived from booking');
  });
  await check(12, async () => {
    const response = await http('/rest/v1/reviews?select=id', {
      method: 'POST', actor: tourist, body: { booking_id: created.booking, rating: 4 },
      headers: { Prefer: 'return=representation' },
    });
    assert.ok(!response.ok, `Duplicate review accepted: ${detail(response)}`);
  });

  const verificationPath = `${guide.id}/${runId}.png`;
  const verificationUpload = await upload('guide-verification', verificationPath, guide);
  assert.equal(verificationUpload.ok, true, `Guide verification upload: ${detail(verificationUpload)}`);
  await check(15, async () => {
    const publicRead = await http(`/storage/v1/object/public/guide-verification/${verificationPath}`);
    assert.ok(!publicRead.ok, `Private document has a public URL: ${detail(publicRead)}`);
    assert.equal(dbQuery("select public from storage.buckets where id='guide-verification';")[0].public, false);
  });
  await check(16, async () => {
    const anonRead = await http(`/storage/v1/object/authenticated/guide-verification/${verificationPath}`);
    const unrelatedRead = await http(`/storage/v1/object/authenticated/guide-verification/${verificationPath}`, { actor: tourist });
    const unrelatedSign = await http(`/storage/v1/object/sign/guide-verification/${verificationPath}`, {
      method: 'POST', actor: tourist, body: { expiresIn: 60 },
    });
    assert.ok(!anonRead.ok && !unrelatedRead.ok && !unrelatedSign.ok,
      `Unauthorized Storage access: ${detail(anonRead)}, ${detail(unrelatedRead)}, ${detail(unrelatedSign)}`);
  });
  await check(17, async () => {
    const ownerRead = await http(`/storage/v1/object/authenticated/guide-verification/${verificationPath}`, { actor: guide });
    const adminRead = await http(`/storage/v1/object/authenticated/guide-verification/${verificationPath}`, { actor: other });
    const signed = await http(`/storage/v1/object/sign/guide-verification/${verificationPath}`, {
      method: 'POST', actor: guide, body: { expiresIn: 60 },
    });
    assert.ok(ownerRead.ok && adminRead.ok && signed.ok && signed.body?.signedURL,
      `Authorized Storage access: ${detail(ownerRead)}, ${detail(adminRead)}, ${detail(signed)}`);
    // Storage's raw API returns a path relative to its /storage/v1 base.
    assert.ok(signed.body.signedURL.startsWith('/object/sign/'), 'Unexpected signed URL path');
    const signedUrl = new URL(`/storage/v1${signed.body.signedURL}`, url);
    const signedRead = await fetch(signedUrl, { signal: AbortSignal.timeout(30000) });
    assert.ok(signedRead.ok, `Authorized signed URL failed: HTTP ${signedRead.status}`);
  });
  await check(18, async () => {
    const profileUpdate = await http(`/rest/v1/profiles?id=eq.${tourist.id}&select=id,preferred_language`, {
      method: 'PATCH', actor: tourist, body: { preferred_language: 'ne' }, headers: { Prefer: 'return=representation' },
    });
    assert.equal(rows(profileUpdate)[0]?.preferred_language, 'ne');
    const guideUpdate = await http(`/rest/v1/guide_profiles?user_id=eq.${guide.id}&select=user_id,bio`, {
      method: 'PATCH', actor: guide, body: { bio: 'Disposable test guide' }, headers: { Prefer: 'return=representation' },
    });
    assert.equal(rows(guideUpdate)[0]?.bio, 'Disposable test guide');
    const favorite = await http('/rest/v1/favorites?select=id', {
      method: 'POST', actor: tourist, body: { user_id: tourist.id, destination_id: created.destination },
      headers: { Prefer: 'return=representation' },
    });
    const favoriteId = rows(favorite)[0]?.id;
    uuid(favoriteId);
    const duplicate = await http('/rest/v1/favorites?select=id', {
      method: 'POST', actor: tourist, body: { user_id: tourist.id, destination_id: created.destination },
      headers: { Prefer: 'return=representation' },
    });
    assert.ok(!duplicate.ok, 'Duplicate favorite accepted');
    const favoriteDelete = await http(`/rest/v1/favorites?id=eq.${favoriteId}`, { method: 'DELETE', actor: tourist });
    assert.ok(favoriteDelete.ok, `Owner favorite deletion: ${detail(favoriteDelete)}`);
    const avatarPath = `${tourist.id}/${runId}.png`;
    const avatarUpload = await upload('avatars', avatarPath, tourist);
    assert.ok(avatarUpload.ok, `Owner avatar upload: ${detail(avatarUpload)}`);
    const avatarRead = await http(`/storage/v1/object/public/avatars/${avatarPath}`);
    assert.ok(avatarRead.ok, `Public avatar read: ${detail(avatarRead)}`);
    const mediaPath = `${created.destination}/${runId}.png`;
    const ordinaryMedia = await upload('destination-media', mediaPath, tourist);
    assert.ok(!ordinaryMedia.ok, `Ordinary destination upload succeeded: ${detail(ordinaryMedia)}`);
    const adminMedia = await upload('destination-media', mediaPath, other);
    assert.ok(adminMedia.ok, `ADMIN destination upload: ${detail(adminMedia)}`);
    const mediaRead = await http(`/storage/v1/object/authenticated/destination-media/${mediaPath}`);
    assert.ok(mediaRead.ok, `Published destination media read: ${detail(mediaRead)}`);
  });
}

async function cleanup() {
  const warnings = [];
  if (actors.spoof?.jwt) {
    try { setRole(actors.spoof, 'ADMIN'); } catch (error) { warnings.push(`ADMIN cleanup role: ${error.message}`); }
  }
  for (const file of [...created.files].reverse()) {
    const actor = file.bucket === 'avatars' ? file.owner : actors.spoof;
    if (!actor?.jwt) { warnings.push(`No cleanup JWT for ${file.bucket}`); continue; }
    try {
      const response = await http(`/storage/v1/object/${file.bucket}`, {
        method: 'DELETE', actor, body: { prefixes: [file.path] },
      });
      if (!response.ok) warnings.push(`Storage cleanup ${file.bucket}: ${detail(response)}`);
    } catch (error) { warnings.push(`Storage cleanup ${file.bucket}: ${error.message}`); }
  }
  try {
    const ids = dbQuery(`select id from auth.users where email like '${emailPrefix}-%@example.com';`).map((row) => uuid(row.id));
    if (ids.length) {
      const inList = ids.join(',');
      const statements = [
        `delete from public.reviews where booking_id in (select id from public.bookings where tourist_id in (${inList}) or guide_id in (${inList}));`,
        `delete from public.bookings where tourist_id in (${inList}) or guide_id in (${inList});`,
        `delete from public.guide_verification_requests where guide_id in (${inList});`,
        `delete from public.favorites where user_id in (${inList});`,
        `delete from public.guide_service_areas where guide_id in (${inList});`,
        `delete from public.experiences where destination_id in (select id from public.destinations where slug='gg-live-${runId}');`,
        `delete from public.destinations where slug='gg-live-${runId}';`,
        `delete from auth.users where id in (${inList});`,
      ];
      for (const statement of statements) dbQuery(statement);
    }
  } catch (error) { warnings.push(`SQL cleanup: ${error.message}`); }
  return warnings;
}

let fatal = null;
try {
  await run();
} catch (error) {
  fatal = String(error?.message ?? error).slice(0, 500);
  console.error(`Integration run stopped: ${fatal}`);
}
const cleanupWarnings = await cleanup();
const summary = {
  projectRef: ref, runId, timestamp: new Date().toISOString(),
  scenarios, extra, fatal, cleanupWarnings,
  totals: {
    passed: scenarios.filter((item) => item.status === 'PASS').length,
    failed: scenarios.filter((item) => item.status === 'FAIL').length,
    untested: scenarios.filter((item) => item.status === 'UNTESTED').length,
  },
};
writeFileSync(reportFile, `${JSON.stringify(summary, null, 2)}\n`);
console.log(`Results: ${summary.totals.passed} passed, ${summary.totals.failed} failed, ${summary.totals.untested} untested`);
console.log(`Cleanup warnings: ${cleanupWarnings.length}. Report: supabase/.temp/live_integration_report.json`);
if (fatal || cleanupWarnings.length) process.exitCode = 1;
