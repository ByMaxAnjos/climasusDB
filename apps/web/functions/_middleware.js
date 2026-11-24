// Login/senha (HTTP Basic Auth) para todo o site no Cloudflare Pages.
// Credenciais vêm de variáveis de ambiente do projeto Pages (Settings →
// Variables and Secrets): AUTH_USER e AUTH_PASS. Sem elas, o site fica
// bloqueado (fail closed).
// ponytail: Basic Auth com um único usuário; trocar por Cloudflare Access
// (Zero Trust, login por e-mail) se precisar de várias contas/logout.

const enc = new TextEncoder();

function safeEqual(a, b) {
  const x = enc.encode(a);
  const y = enc.encode(b);
  if (x.byteLength !== y.byteLength) return false;
  return crypto.subtle.timingSafeEqual(x, y);
}

function unauthorized() {
  return new Response("Acesso restrito ao climasusDB.", {
    status: 401,
    headers: { "WWW-Authenticate": 'Basic realm="climasusDB", charset="UTF-8"' },
  });
}

export async function onRequest({ request, env, next }) {
  const { AUTH_USER, AUTH_PASS } = env;
  if (!AUTH_USER || !AUTH_PASS) return unauthorized();

  const header = request.headers.get("Authorization") || "";
  const [scheme, encoded] = header.split(" ");
  if (scheme !== "Basic" || !encoded) return unauthorized();

  let decoded;
  try {
    decoded = new TextDecoder().decode(Uint8Array.from(atob(encoded), (c) => c.charCodeAt(0)));
  } catch {
    return unauthorized();
  }
  const i = decoded.indexOf(":");
  if (i < 0) return unauthorized();

  const userOk = safeEqual(decoded.slice(0, i), AUTH_USER);
  const passOk = safeEqual(decoded.slice(i + 1), AUTH_PASS);
  if (!(userOk && passOk)) return unauthorized();

  return next();
}
