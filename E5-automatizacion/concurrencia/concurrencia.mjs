// TC-10 · Pruebas de concurrencia de la HU-410 (Newman ejecuta en secuencia; esto dispara en paralelo).
// Uso: node E5-automatizacion/concurrencia/concurrencia.mjs   (BASE_URL opcional, por defecto http://localhost:4010)
// Sale con código 1 si alguna validación falla.
import { randomUUID } from 'node:crypto';

const BASE = process.env.BASE_URL || 'http://localhost:4010';
const N = Number(process.env.N || 10);
const TOK = 'tok_app_norte';
const BUSINESS = { business: { commercialName: 'Tienda Concurrente', nit: '1234567K', address: 'Zona 1, Guatemala', phone: '55551234', paymentMethods: ['qr'] } };

let failures = 0;
const check = (ok, msg, detail = '') => { console.log(`${ok ? '  ✔' : '  ✘'} ${msg}${ok ? '' : `  → ${detail}`}`); if (!ok) failures++; };

async function call(method, path, { token = TOK, headers = {}, body } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(body ? { 'Content-Type': 'application/json' } : {}), ...headers },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json = null; try { json = await res.json(); } catch { /* sin cuerpo */ }
  return { status: res.status, json };
}
async function approvedVerification(document) {
  const s = await call('POST', '/v1/identity/sessions', { headers: { 'X-Device-Id': `conc-${randomUUID()}` } });
  if (s.status !== 201) throw new Error(`No se pudo crear la sesión: ${s.status}`);
  await call('POST', `/v1/_sandbox/sessions/${s.json.providerSessionId}/complete`, { token: null, body: { scenario: 'approved', ...(document ? { document } : {}) } });
  return s.json.verificationId;
}
const signup = (vid, key) => call('POST', '/v1/signups', { headers: { 'Verification-Id': vid, 'Idempotency-Key': key }, body: BUSINESS });
const count = (rs, code) => rs.filter(r => r.status === code).length;
const statuses = rs => JSON.stringify(rs.map(r => r.status));

console.log(`Ambiente: ${BASE} · ${N} solicitudes simultáneas por prueba\n`);

console.log('TC-10.1 · Misma verificación y misma Idempotency-Key en paralelo (CA-10)');
{
  const vid = await approvedVerification();
  const key = randomUUID();
  const rs = await Promise.all(Array.from({ length: N }, () => signup(vid, key)));
  const ids = new Set(rs.filter(r => r.status < 300).map(r => r.json.signupId));
  check(rs.every(r => r.status === 201), 'Todas responden 201 (la respuesta original)', statuses(rs));
  check(ids.size === 1, 'Todas apuntan a la misma alta', `${ids.size} signupId distintos`);
}

console.log('\nTC-10.2 · Misma verificación con llaves distintas en paralelo (CA-06)');
{
  const vid = await approvedVerification();
  const rs = await Promise.all(Array.from({ length: N }, () => signup(vid, randomUUID())));
  check(count(rs, 201) === 1, 'Exactamente una solicitud crea el alta', `${count(rs, 201)} respuestas 201: ${statuses(rs)}`);
  check(count(rs, 409) === N - 1, 'El resto responde 409 VERIFICATION_ALREADY_USED', statuses(rs));
}

console.log('\nTC-10.3 · Mismo CUI (persona B) con dos verificaciones en paralelo en el mismo comercio (CA-07)');
{
  const [v1, v2] = await Promise.all([approvedVerification('B'), approvedVerification('B')]);
  const rs = await Promise.all([signup(v1, randomUUID()), signup(v2, randomUUID())]);
  const ids = new Set(rs.filter(r => r.status < 300).map(r => r.json.signupId));
  check(ids.size === 1, 'Ambas solicitudes devuelven la misma alta (nunca dos altas para el mismo CUI)', `${ids.size} signupId distintos: ${statuses(rs)}`);
  check(count(rs, 201) === 1 && count(rs, 200) === 1, 'Una crea (201) y la otra reutiliza (200)', statuses(rs));
}

console.log('\nTC-12 · Sesiones simultáneas con el mismo dispositivo (CA-08)');
{
  const dev = `conc-dev-${randomUUID()}`;
  const rs = await Promise.all(Array.from({ length: 6 }, () => call('POST', '/v1/identity/sessions', { headers: { 'X-Device-Id': dev } })));
  check(count(rs, 201) <= 3, 'Como máximo 3 sesiones creadas', `${count(rs, 201)} sesiones creadas: ${statuses(rs)}`);
}

console.log(`\n${failures === 0 ? 'Todas las validaciones pasaron' : `${failures} validación(es) fallaron`}`);
process.exit(failures === 0 ? 0 : 1);
