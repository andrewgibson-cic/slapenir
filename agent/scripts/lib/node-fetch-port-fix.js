const http = require("node:http");
const https = require("node:https");

function patchedFetch(input, init) {
  const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
  const parsedUrl = new URL(url);
  const isHttps = parsedUrl.protocol === "https:";
  const lib = isHttps ? https : http;

  const method = (init?.method || (input instanceof Request ? input.method : "GET")).toUpperCase();
  const headers = {};
  if (init?.headers) {
    if (init.headers instanceof Headers) {
      init.headers.forEach((v, k) => { headers[k] = v; });
    } else if (typeof init.headers === "object") {
      Object.entries(init.headers).forEach(([k, v]) => { headers[k] = v; });
    }
  }
  if (input instanceof Request && input.headers) {
    input.headers.forEach((v, k) => { headers[k] = v; });
  }

  const body = init?.body || (input instanceof Request ? undefined : undefined);

  return new Promise((resolve, reject) => {
    const opts = {
      hostname: parsedUrl.hostname,
      port: parseInt(parsedUrl.port) || (isHttps ? 443 : 80),
      path: parsedUrl.pathname + parsedUrl.search,
      method,
      headers,
    };

    const req = lib.request(opts, (res) => {
      const readable = new ReadableStream({
        start(controller) {
          res.on("data", (chunk) => {
            controller.enqueue(new Uint8Array(chunk.buffer, chunk.byteOffset, chunk.byteLength));
          });
          res.on("end", () => controller.close());
          res.on("error", (err) => controller.error(err));
        },
        cancel() {
          res.destroy();
        }
      });

      const response = new Response(readable, {
        status: res.statusCode,
        statusText: res.statusMessage,
        headers: Object.entries(res.headers).map(([k, v]) => [k, Array.isArray(v) ? v.join(", ") : v]),
      });
      Object.defineProperty(response, "url", { value: url });
      resolve(response);
    });
    req.on("error", reject);
    if (body) {
      if (typeof body === "string") req.write(body);
      else if (body instanceof ArrayBuffer || ArrayBuffer.isView(body)) req.write(Buffer.from(body));
      else if (body.pipe) body.pipe(req);
      else req.write(JSON.stringify(body));
    }
    req.end();
  });
}

globalThis.fetch = patchedFetch;
