const express = require('express');
const path = require('path');
const cors = require('cors');
const { Pool } = require('pg');
const { createRemoteJWKSet, jwtVerify } = require('jose');

const { run: bootstrapKeycloak } = require('./scripts/bootstrap-keycloak');
const app = express();
const port = 3000;

// --- Config ---
const KEYCLOAK_REALM = process.env.KEYCLOAK_REALM || 'dms-realm';
const KEYCLOAK_ISSUER_URL = process.env.KEYCLOAK_ISSUER_URL || `https://${process.env.KEYCLOAK_HOSTNAME || 'sso.localhost'}/realms/${KEYCLOAK_REALM}`;
const KEYCLOAK_CLIENT_ID = process.env.KEYCLOAK_CLIENT_ID || 'dms-app';

// --- Postgres Connection ---
// Expect standard libpq env vars: PGHOST, PGUSER, PGPASSWORD, PGDATABASE
const pool = new Pool();

// Ensure table exists on startup
async function ensureSchema() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS submissions (
      id SERIAL PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      zip TEXT NOT NULL,
      phone TEXT NOT NULL,
      notes TEXT,
      created_at TIMESTAMPTZ DEFAULT now()
    );
  `);
}

// --- Auth (Keycloak JWT) ---
const jwksUri = new URL(`${KEYCLOAK_ISSUER_URL}/protocol/openid-connect/certs`);
const JWKS = createRemoteJWKSet(jwksUri);

async function verifyToken(authorizationHeader) {
  if (!authorizationHeader || !authorizationHeader.startsWith('Bearer ')) {
    throw new Error('missing_bearer');
  }
  const token = authorizationHeader.substring('Bearer '.length);
  const { payload } = await jwtVerify(token, JWKS, {
    issuer: KEYCLOAK_ISSUER_URL,
    audience: KEYCLOAK_CLIENT_ID,
  });
  return payload;
}

function authRequired(req, res, next) {
  verifyToken(req.headers['authorization'])
    .then((payload) => {
      req.user = payload;
      next();
    })
    .catch((err) => {
      const code = err.message === 'missing_bearer' ? 401 : 403;
      res.status(code).json({ error: 'unauthorized' });
    });
}

// --- Middleware ---
app.use(express.json());
app.use(cors({ origin: true, credentials: true }));

// --- Health ---
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', db: true, node: process.version });
  } catch (e) {
    res.json({ status: 'degraded', db: false, node: process.version });
  }
});

// --- Runtime frontend config ---
app.get('/config.json', (req, res) => {
  res.json({
    keycloak: {
      realm: KEYCLOAK_REALM,
      issuerUrl: KEYCLOAK_ISSUER_URL,
      clientId: KEYCLOAK_CLIENT_ID,
    },
  });
});

// --- API: Submissions ---
app.get('/api/submissions', authRequired, async (req, res) => {
  const sub = req.user.sub;
  const { rows } = await pool.query(
    'SELECT id, name, zip, phone, notes, created_at FROM submissions WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50',
    [sub]
  );
  res.json(rows);
});

app.post('/api/submissions', authRequired, async (req, res) => {
  const { name, zip, phone, notes } = req.body || {};
  if (!name || !zip || !phone) {
    return res.status(400).json({ error: 'name, zip, phone are required' });
  }
  const sub = req.user.sub;
  const { rows } = await pool.query(
    'INSERT INTO submissions (user_id, name, zip, phone, notes) VALUES ($1, $2, $3, $4, $5) RETURNING id, created_at',
    [sub, name, zip, phone, notes || null]
  );
  res.status(201).json({ id: rows[0].id, created_at: rows[0].created_at });
});

// --- Static frontend (React SPA) ---
const staticDir = path.join(__dirname, 'app');
app.use(express.static(staticDir));

// Fallback to index.html for SPA routes
app.get('*', (req, res, next) => {
  if (req.path.startsWith('/api/')) return next();
  if (req.path === '/config.json') return next();
  res.sendFile(path.join(staticDir, 'index.html'));
});

// --- Start Server ---
app.listen(port, async () => {
  console.log(`Application server listening on port ${port}`);
  try {
    await ensureSchema();
    console.log('Postgres schema ensured.');
  } catch (err) {
    console.error('Failed to initialize Postgres schema:', err);
  }
  // Run Keycloak bootstrap in background; don't block the server
  bootstrapKeycloak().catch(() => {});
});
