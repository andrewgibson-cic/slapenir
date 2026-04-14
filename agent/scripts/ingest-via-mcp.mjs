#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import { readdir, stat } from 'node:fs/promises';
import { extname, join, resolve } from 'node:path';

const SUPPORTED_EXTENSIONS = new Set(['.md', '.pdf', '.docx', '.txt']);

const DB_PATH = process.env.DB_PATH || '/home/agent/.local/share/mcp-knowledge/lancedb';
const CACHE_DIR = process.env.CACHE_DIR || '/home/agent/.cache/huggingface';
const BASE_DIR = process.env.BASE_DIR || '/home/agent/workspace/docs';
const MODEL_NAME = process.env.MODEL_NAME || 'Xenova/all-MiniLM-L6-v2';

let requestId = 0;

function jsonrpc(method, params = {}) {
  return {
    jsonrpc: '2.0',
    id: ++requestId,
    method,
    params,
  };
}

function notification(method, params = {}) {
  return {
    jsonrpc: '2.0',
    method,
    params,
  };
}

function sendMessage(proc, message) {
  const data = JSON.stringify(message) + '\n';
  proc.stdin.write(data);
}

function waitForResponse(proc, expectedId) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(new Error(`Timeout waiting for response id=${expectedId}`));
    }, 120000);

    const rl = createInterface({ input: proc.stdout });
    const onLine = (line) => {
      if (!line.trim()) return;
      try {
        const msg = JSON.parse(line);
        if (msg.id === expectedId) {
          clearTimeout(timeout);
          rl.removeListener('line', onLine);
          if (msg.error) {
            reject(new Error(msg.error.message || JSON.stringify(msg.error)));
          } else {
            resolve(msg.result);
          }
        }
      } catch {
        // ignore non-JSON lines (shouldn't happen on stdout but be safe)
      }
    };
    rl.on('line', onLine);
  });
}

async function rpc(proc, method, params) {
  const msg = jsonrpc(method, params);
  const promise = waitForResponse(proc, msg.id);
  sendMessage(proc, msg);
  return promise;
}

async function collectFiles(dir) {
  const files = [];
  const queue = [resolve(dir)];
  while (queue.length > 0) {
    const current = queue.shift();
    let entries;
    try {
      entries = await readdir(current, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      const fullPath = join(current, entry.name);
      if (entry.isDirectory()) {
        queue.push(fullPath);
      } else if (entry.isFile() && SUPPORTED_EXTENSIONS.has(extname(entry.name).toLowerCase())) {
        files.push(fullPath);
      }
    }
  }
  return files.sort();
}

async function main() {
  const targetDir = process.argv[2] || BASE_DIR;

  console.log('=== MCP Knowledge Ingest (via ingest_file) ===');
  console.log(`Target:  ${targetDir}`);
  console.log(`BASE_DIR: ${BASE_DIR}`);
  console.log(`DB_PATH:  ${DB_PATH}`);
  console.log('');

  const dirStat = await stat(targetDir).catch(() => null);
  if (!dirStat || !dirStat.isDirectory()) {
    console.error(`Error: Directory not found: ${targetDir}`);
    process.exit(1);
  }

  const files = await collectFiles(targetDir);
  const total = files.length;
  console.log(`Found ${total} file(s)`);
  console.log('');

  if (total === 0) {
    console.log('No supported files to process.');
    process.exit(0);
  }

  const env = {
    ...process.env,
    BASE_DIR,
    DB_PATH,
    CACHE_DIR,
    MODEL_NAME,
    HF_HUB_OFFLINE: '1',
    HF_HOME: CACHE_DIR,
    TRANSFORMERS_CACHE: CACHE_DIR,
  };

  const proc = spawn('node', [
    '--experimental-vm-modules',
    '/usr/local/lib/node_modules/mcp-local-rag/dist/server-main.js',
  ], {
    env,
    stdio: ['pipe', 'pipe', 'inherit'],
    cwd: targetDir,
  });

  proc.on('error', (err) => {
    console.error(`Failed to spawn mcp-local-rag: ${err.message}`);
    process.exit(1);
  });

  proc.on('exit', (code) => {
    if (code && code !== 0) {
      console.error(`mcp-local-rag exited with code ${code}`);
    }
  });

  // MCP handshake
  try {
    await rpc(proc, 'initialize', {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'slapenir-ingest', version: '1.0.0' },
    });
    sendMessage(proc, notification('notifications/initialized'));
    console.error('MCP handshake complete');
  } catch (err) {
    console.error(`MCP handshake failed: ${err.message}`);
    proc.kill();
    process.exit(1);
  }

  let succeeded = 0;
  let failed = 0;

  for (let i = 0; i < files.length; i++) {
    const filePath = files[i];
    const label = `[${i + 1}/${total}]`;
    process.stdout.write(`  ${label} ${filePath}... `);

    try {
      const result = await rpc(proc, 'tools/call', {
        name: 'ingest_file',
        arguments: { filePath },
      });
      const text = result?.content?.[0]?.text;
      let parsed;
      try {
        parsed = text ? JSON.parse(text) : null;
      } catch {
        parsed = null;
      }
      if (parsed && parsed.chunkCount !== undefined) {
        console.log(`OK (${parsed.chunkCount} chunks)`);
      } else {
        console.log(`OK`);
      }
      succeeded++;
    } catch (err) {
      console.log(`FAILED: ${err.message}`);
      failed++;
    }
  }

  // Clean shutdown
  try {
    await rpc(proc, 'shutdown', {});
  } catch {
    // shutdown may not respond, that's ok
  }
  proc.kill();

  console.log('');
  console.log('=== Summary ===');
  console.log(`Total:     ${total}`);
  console.log(`Succeeded: ${succeeded}`);
  console.log(`Failed:    ${failed}`);

  if (failed > 0) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(`Fatal: ${err.message}`);
  process.exit(1);
});
