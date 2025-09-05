// Bootstrap Keycloak: enable realm and ensure the public SPA client exists.
// Runs at server startup; logs warnings on failure but never crashes the app.

const qs = require('querystring');

const CONFIG = {
  adminUser: process.env.KEYCLOAK_ADMIN_USERNAME || 'admin',
  adminPass: process.env.KEYCLOAK_ADMIN_PASSWORD || '',
  realm: process.env.KEYCLOAK_REALM || 'dms-realm',
  clientId: process.env.KEYCLOAK_CLIENT_ID || process.env.APP_CLIENT_ID || 'dms-app',
  dmsHost: process.env.DMS_HOSTNAME || 'dms.dmsin.local',
  // Use internal Keycloak URL inside the Docker network to avoid TLS issues
  kcInternalBase: process.env.KEYCLOAK_INTERNAL_BASE || 'http://keycloak:8080',
};

async function getAdminToken() {
  if (!CONFIG.adminPass) throw new Error('Missing KEYCLOAK_ADMIN_PASSWORD');
  const url = `${CONFIG.kcInternalBase}/realms/master/protocol/openid-connect/token`;
  const body = qs.stringify({
    grant_type: 'password',
    client_id: 'admin-cli',
    username: CONFIG.adminUser,
    password: CONFIG.adminPass,
  });
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body,
  });
  if (!res.ok) throw new Error(`token_error ${res.status}`);
  const data = await res.json();
  return data.access_token;
}

async function fetchJson(url, opts = {}) {
  const res = await fetch(url, opts);
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`http_${res.status}`);
  return res.json();
}

async function enableRealm(token) {
  const url = `${CONFIG.kcInternalBase}/admin/realms/${encodeURIComponent(CONFIG.realm)}`;
  const realm = await fetchJson(url, { headers: { authorization: `Bearer ${token}` } });
  if (!realm) {
    console.warn(`[bootstrap] Realm '${CONFIG.realm}' not found; skipping enable.`);
    return;
  }
  if (realm.enabled) {
    console.log(`[bootstrap] Realm '${CONFIG.realm}' already enabled.`);
    return;
  }
  realm.enabled = true;
  const res = await fetch(url, {
    method: 'PUT',
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(realm),
  });
  if (!res.ok) throw new Error(`enable_realm_${res.status}`);
  console.log(`[bootstrap] Enabled realm '${CONFIG.realm}'.`);
}

async function ensureClient(token) {
  const searchUrl = `${CONFIG.kcInternalBase}/admin/realms/${encodeURIComponent(CONFIG.realm)}/clients?clientId=${encodeURIComponent(CONFIG.clientId)}`;
  const list = await fetchJson(searchUrl, { headers: { authorization: `Bearer ${token}` } }) || [];
  const redirectUris = [`https://${CONFIG.dmsHost}/*`];
  const webOrigins = [`https://${CONFIG.dmsHost}`];

  if (Array.isArray(list) && list.length > 0) {
    const existing = list[0];
    const detailUrl = `${CONFIG.kcInternalBase}/admin/realms/${encodeURIComponent(CONFIG.realm)}/clients/${existing.id}`;
    const detail = await fetchJson(detailUrl, { headers: { authorization: `Bearer ${token}` } });
    if (!detail) return;

    let changed = false;
    const desired = {
      publicClient: true,
      protocol: 'openid-connect',
      standardFlowEnabled: true,
      directAccessGrantsEnabled: false,
      redirectUris,
      webOrigins,
      attributes: { 'pkce.code.challenge.method': 'S256' },
    };
    for (const [k, v] of Object.entries(desired)) {
      // shallow compare for arrays
      const same = Array.isArray(v)
        ? Array.isArray(detail[k]) && v.length === detail[k].length && v.every((x, i) => x === detail[k][i])
        : detail[k] === v || JSON.stringify(detail[k]) === JSON.stringify(v);
      if (!same) { detail[k] = v; changed = true; }
    }
    if (detail.clientId !== CONFIG.clientId) { /* unlikely */ detail.clientId = CONFIG.clientId; changed = true; }
    if (changed) {
      const res = await fetch(detailUrl, {
        method: 'PUT',
        headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
        body: JSON.stringify(detail),
      });
      if (!res.ok) throw new Error(`update_client_${res.status}`);
      console.log(`[bootstrap] Updated client '${CONFIG.clientId}'.`);
    } else {
      console.log(`[bootstrap] Client '${CONFIG.clientId}' already up-to-date.`);
    }
    return;
  }

  const createUrl = `${CONFIG.kcInternalBase}/admin/realms/${encodeURIComponent(CONFIG.realm)}/clients`;
  const payload = {
    clientId: CONFIG.clientId,
    name: 'DMS Demo App',
    protocol: 'openid-connect',
    publicClient: true,
    standardFlowEnabled: true,
    directAccessGrantsEnabled: false,
    redirectUris,
    webOrigins,
    attributes: { 'pkce.code.challenge.method': 'S256' },
  };
  const res = await fetch(createUrl, {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (res.status !== 201) throw new Error(`create_client_${res.status}`);
  console.log(`[bootstrap] Created client '${CONFIG.clientId}'.`);
}

async function run() {
  try {
    const token = await getAdminToken();
    await enableRealm(token);
    await ensureClient(token);
  } catch (e) {
    console.warn('[bootstrap] Keycloak bootstrap skipped:', e.message);
  }
}

module.exports = { run };

// If invoked directly (e.g., node scripts/bootstrap-keycloak.js), run immediately
if (require.main === module) {
  run();
}
