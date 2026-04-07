import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v5.2.0/index.ts";

const ENABLE_BANKING_BASE_URL = "https://api.enablebanking.com";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "Content-Type, Authorization, x-client-info, apikey",
};

/**
 * Build a signed JWT for EnableBanking API authentication.
 *
 * The token uses RS256 with the private key stored in the
 * ENABLE_BANKING_PRIVATE_KEY env var. Lifetime is capped at 30 minutes
 * per the EnableBanking spec.
 */
async function buildJwt(): Promise<string> {
  const privateKeyPem = Deno.env.get("ENABLE_BANKING_PRIVATE_KEY");
  const appId = Deno.env.get("ENABLE_BANKING_APP_ID");

  if (!privateKeyPem) {
    throw new Error("ENABLE_BANKING_PRIVATE_KEY is not configured");
  }
  if (!appId) {
    throw new Error("ENABLE_BANKING_APP_ID is not configured");
  }

  const privateKey = await importPKCS8(privateKeyPem, "RS256");

  const now = Math.floor(Date.now() / 1000);

  return new SignJWT({})
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(appId)
    .setAudience("enablebanking.com")
    .setIssuedAt(now)
    .setExpirationTime(now + 30 * 60) // 30 minutes
    .sign(privateKey);
}

/**
 * Forward a request to the EnableBanking API, injecting the signed JWT.
 */
async function proxyRequest(
  method: string,
  path: string,
  body?: unknown,
): Promise<Response> {
  const jwt = await buildJwt();

  const url = `${ENABLE_BANKING_BASE_URL}${path}`;

  const headers: Record<string, string> = {
    Authorization: `Bearer ${jwt}`,
    "Content-Type": "application/json",
  };

  const init: RequestInit = { method, headers };

  if (body !== undefined && method !== "GET") {
    init.body = JSON.stringify(body);
  }

  const upstream = await fetch(url, init);

  const responseBody = await upstream.text();
  const contentType = upstream.headers.get("content-type") ?? "application/json";

  return new Response(responseBody, {
    status: upstream.status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": contentType,
    },
  });
}

/**
 * Return a JSON error response with CORS headers.
 */
function errorResponse(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

/**
 * Route the incoming request to the correct EnableBanking endpoint based on
 * the `action` field (read from either the query string or the JSON body).
 */
async function handleRequest(req: Request): Promise<Response> {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  try {
    const url = new URL(req.url);
    let action = url.searchParams.get("action");

    // Parse body once — we may need it for both action detection and payload.
    let body: Record<string, unknown> | undefined;
    if (req.method === "POST") {
      try {
        body = await req.json();
      } catch {
        return errorResponse(400, "Invalid JSON body");
      }
      if (!action && body?.action) {
        action = String(body.action);
      }
    }

    if (!action) {
      return errorResponse(400, "Missing required parameter: action");
    }

    switch (action) {
      // ---------------------------------------------------------------
      // 1. List available banks
      // ---------------------------------------------------------------
      case "list_banks": {
        const country = url.searchParams.get("country") ?? body?.country;
        if (!country) {
          return errorResponse(400, "Missing required parameter: country");
        }
        return proxyRequest("GET", `/aspsps?country=${encodeURIComponent(String(country))}`);
      }

      // ---------------------------------------------------------------
      // 2. Create a bank auth session (requisition)
      // ---------------------------------------------------------------
      case "create_session": {
        if (!body) {
          return errorResponse(400, "POST body is required for create_session");
        }
        // Strip the action field before forwarding — EnableBanking doesn't expect it.
        const { action: _discarded, ...payload } = body;
        return proxyRequest("POST", "/sessions", payload);
      }

      // ---------------------------------------------------------------
      // 3. Get session status / accounts after auth
      // ---------------------------------------------------------------
      case "get_session": {
        const sessionId =
          url.searchParams.get("session_id") ?? body?.session_id;
        if (!sessionId) {
          return errorResponse(400, "Missing required parameter: session_id");
        }
        return proxyRequest("GET", `/sessions/${encodeURIComponent(String(sessionId))}`);
      }

      // ---------------------------------------------------------------
      // 4. Fetch transactions for an account
      // ---------------------------------------------------------------
      case "get_transactions": {
        const accountId =
          url.searchParams.get("account_id") ?? body?.account_id;
        if (!accountId) {
          return errorResponse(400, "Missing required parameter: account_id");
        }
        const dateFrom =
          url.searchParams.get("date_from") ?? body?.date_from;
        const dateTo = url.searchParams.get("date_to") ?? body?.date_to;

        let path = `/accounts/${encodeURIComponent(String(accountId))}/transactions`;
        const qs: string[] = [];
        if (dateFrom) qs.push(`date_from=${encodeURIComponent(String(dateFrom))}`);
        if (dateTo) qs.push(`date_to=${encodeURIComponent(String(dateTo))}`);
        if (qs.length > 0) path += `?${qs.join("&")}`;

        return proxyRequest("GET", path);
      }

      // ---------------------------------------------------------------
      // 5. Fetch balances for an account
      // ---------------------------------------------------------------
      case "get_balances": {
        const accountId =
          url.searchParams.get("account_id") ?? body?.account_id;
        if (!accountId) {
          return errorResponse(400, "Missing required parameter: account_id");
        }
        return proxyRequest(
          "GET",
          `/accounts/${encodeURIComponent(String(accountId))}/balances`,
        );
      }

      default:
        return errorResponse(
          400,
          `Unknown action: ${action}. Valid actions: list_banks, create_session, get_session, get_transactions, get_balances`,
        );
    }
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : "Internal server error";
    console.error("[bank-sync] Unhandled error:", err);
    return errorResponse(500, message);
  }
}

serve(handleRequest);
