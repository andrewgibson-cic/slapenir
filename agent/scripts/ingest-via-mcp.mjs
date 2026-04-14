#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import { readdir, stat, writeFile, unlink } from 'node:fs/promises';
import { extname, join, resolve, relative, basename } from 'node:path';

const SUPPORTED_EXTENSIONS = new Set(['.md', '.pdf', '.docx', '.txt', '.html', '.htm']);

const DB_PATH = process.env.DB_PATH || '/home/agent/.local/share/mcp-knowledge/lancedb';
const CACHE_DIR = process.env.CACHE_DIR || '/home/agent/.cache/huggingface';
const BASE_DIR = process.env.BASE_DIR || '/home/agent/workspace/docs';
const MODEL_NAME = process.env.MODEL_NAME || 'Xenova/all-MiniLM-L6-v2';
const MCP_SERVER_PATH = '/usr/local/lib/node_modules/mcp-local-rag/dist/index.js';

const RE_INGEST = process.argv.includes('--reingest') || process.argv.includes('--force');
const DRY_RUN = process.argv.includes('--dry-run');
const VERBOSE = process.argv.includes('--verbose') || process.argv.includes('-v');
const HELP = process.argv.includes('--help') || process.argv.includes('-h');

function printUsage() {
  console.log(`
Usage: ingest-via-mcp.mjs [OPTIONS] [TARGET_DIRECTORY]

Ingest documents into the MCP knowledge database (LanceDB) via the
mcp-local-rag server using the MCP protocol.

Options:
  --reingest, --force   Re-ingest files already present in the database
  --dry-run             List files that would be ingested without ingesting
  --verbose, -v         Show detailed progress information
  --help, -h            Show this help message

Supported file types: .md, .pdf, .docx, .txt, .html, .htm

Environment variables:
  BASE_DIR    Base directory for relative paths (default: /home/agent/workspace/docs)
  DB_PATH     LanceDB storage path (default: /home/agent/.local/share/mcp-knowledge/lancedb)
  CACHE_DIR   HuggingFace model cache (default: /home/agent/.cache/huggingface)
  MODEL_NAME  Embedding model name (default: Xenova/all-MiniLM-L6-v2)

Examples:
  ingest-via-mcp.mjs                         # Ingest all docs in BASE_DIR
  ingest-via-mcp.mjs /path/to/tickets        # Ingest specific directory
  ingest-via-mcp.mjs --dry-run /path/to/dir  # Preview what would be ingested
  ingest-via-mcp.mjs --reingest --verbose    # Force re-ingest with verbose output
`);
}

let requestId = 0;
let pendingResolve = new Map();
let pendingReject = new Map();

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

function waitForResponse(proc, expectedId, timeoutMs = 120000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pendingResolve.delete(expectedId);
      pendingReject.delete(expectedId);
      reject(new Error(`Timeout (${timeoutMs / 1000}s) waiting for response id=${expectedId}`));
    }, timeoutMs);

    pendingResolve.set(expectedId, (result) => {
      clearTimeout(timer);
      pendingResolve.delete(expectedId);
      pendingReject.delete(expectedId);
      resolve(result);
    });

    pendingReject.set(expectedId, (err) => {
      clearTimeout(timer);
      pendingResolve.delete(expectedId);
      pendingReject.delete(expectedId);
      reject(err);
    });
  });
}

function startResponseListener(proc) {
  let buffer = '';
  const rl = createInterface({ input: proc.stdout });
  rl.on('line', (line) => {
    if (!line.trim()) return;
    try {
      const msg = JSON.parse(line);
      if (msg.id != null) {
        const resolve = pendingResolve.get(msg.id);
        const reject = pendingReject.get(msg.id);
        if (msg.error) {
          if (reject) reject(new Error(msg.error.message || JSON.stringify(msg.error)));
        } else {
          if (resolve) resolve(msg.result);
        }
      }
    } catch {}
  });
}

async function rpc(proc, method, params, timeoutMs) {
  const msg = jsonrpc(method, params);
  const promise = waitForResponse(proc, msg.id, timeoutMs);
  sendMessage(proc, msg);
  return promise;
}

async function collectFiles(dir, ignorePatterns = []) {
  const files = [];
  const queue = [resolve(dir)];
  const defaultIgnore = [
    '.git', 'node_modules', '.svn', '.hg', '__pycache__',
    '.DS_Store', 'Thumbs.db', '.env',
  ];
  const ignore = new Set([...defaultIgnore, ...ignorePatterns]);

  while (queue.length > 0) {
    const current = queue.shift();
    let entries;
    try {
      entries = await readdir(current, { withFileTypes: true });
    } catch (err) {
      if (VERBOSE) console.error(`  [warn] Cannot read ${current}: ${err.message}`);
      continue;
    }
    for (const entry of entries) {
      if (ignore.has(entry.name)) continue;
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

async function getIngestedFiles(proc) {
  try {
    const result = await rpc(proc, 'tools/call', {
      name: 'list_files',
      arguments: {},
    }, 30000);
    const text = result?.content?.[0]?.text;
    if (!text) return new Set();
    let parsed;
    try {
      parsed = JSON.parse(text);
    } catch {
      return new Set();
    }
    const files = parsed?.files || parsed?.documents || [];
    return new Set(
      files
        .filter(f => typeof f === 'string' || f.ingested === true)
        .map(f => typeof f === 'string' ? f : f.path || f.filePath || f.name)
    );
  } catch {
    return new Set();
  }
}

async function main() {
  if (HELP) {
    printUsage();
    process.exit(0);
  }

  const positionalArgs = process.argv.slice(2).filter(a => !a.startsWith('-'));
  const targetDir = positionalArgs[0] || BASE_DIR;

  console.log('=== MCP Knowledge Ingest ===');
  console.log(`Target:    ${targetDir}`);
  console.log(`BASE_DIR:  ${BASE_DIR}`);
  console.log(`DB_PATH:   ${DB_PATH}`);
  if (RE_INGEST) console.log('Mode:      Force re-ingest');
  if (DRY_RUN) console.log('Mode:      Dry run (no ingestion)');
  console.log('');

  const dirStat = await stat(targetDir).catch(() => null);
  if (!dirStat || !dirStat.isDirectory()) {
    console.error(`Error: Directory not found: ${targetDir}`);
    process.exit(1);
  }

  const files = await collectFiles(targetDir);
  const total = files.length;
  console.log(`Found ${total} supported file(s)`);
  console.log('');

  if (total === 0) {
    console.log('No supported files to process.');
    process.exit(0);
  }

  if (DRY_RUN) {
    console.log('Files that would be ingested:');
    for (const f of files) {
      const rel = relative(targetDir, f);
      console.log(`  ${rel}`);
    }
    console.log(`\nTotal: ${total} file(s)`);
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
    MCP_SERVER_PATH,
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

  startResponseListener(proc);

  try {
    await rpc(proc, 'initialize', {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'slapenir-ingest', version: '2.0.0' },
    }, 30000);
    sendMessage(proc, notification('notifications/initialized'));
    if (VERBOSE) console.error('MCP handshake complete');
  } catch (err) {
    console.error(`MCP handshake failed: ${err.message}`);
    proc.kill();
    process.exit(1);
  }

  let ingestedSet = new Set();
  if (!RE_INGEST) {
    if (VERBOSE) console.error('Checking already-ingested files...');
    ingestedSet = await getIngestedFiles(proc);
    if (VERBOSE) console.error(`Found ${ingestedSet.size} previously ingested file(s)`);
  }

  const toIngest = RE_INGEST
    ? files
    : files.filter(f => {
        const rel = relative(targetDir, f);
        return !ingestedSet.has(f) && !ingestedSet.has(rel) && !ingestedSet.has(basename(f));
      });

  const skipped = files.length - toIngest.length;
  if (skipped > 0) {
    console.log(`Skipping ${skipped} already-ingested file(s)`);
  }

  if (toIngest.length === 0) {
    console.log('All files already ingested. Use --reingest to force re-ingestion.');
    try { await rpc(proc, 'shutdown', {}, 5000); } catch {}
    proc.kill();
    process.exit(0);
  }

  console.log(`Ingesting ${toIngest.length} file(s)...\n`);

  let succeeded = 0;
  let failed = 0;
  const failedFiles = [];

  for (let i = 0; i < toIngest.length; i++) {
    const filePath = toIngest[i];
    const label = `[${i + 1}/${toIngest.length}]`;
    const rel = relative(targetDir, filePath);
    process.stdout.write(`  ${label} ${rel}... `);

    try {
      const result = await rpc(proc, 'tools/call', {
        name: 'ingest_file',
        arguments: { filePath },
      });
      const text = result?.content?.[0]?.text;
      let parsed;
      try { parsed = text ? JSON.parse(text) : null; } catch { parsed = null; }
      if (parsed && parsed.chunkCount !== undefined) {
        console.log(`OK (${parsed.chunkCount} chunks)`);
      } else {
        console.log(`OK`);
      }
      succeeded++;
    } catch (err) {
      console.log(`FAILED: ${err.message}`);
      failedFiles.push(rel);
      failed++;
    }
  }

  try {
    await rpc(proc, 'shutdown', {}, 5000);
  } catch {}
  proc.kill();

  console.log('');
  console.log('=== Summary ===');
  console.log(`Total:     ${total}`);
  console.log(`Skipped:   ${skipped}`);
  console.log(`Ingested:  ${succeeded}`);
  console.log(`Failed:    ${failed}`);

  if (failedFiles.length > 0) {
    console.log('\nFailed files:');
    for (const f of failedFiles) {
      console.log(`  - ${f}`);
    }
  }

  if (failed > 0) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(`Fatal: ${err.message}`);
  process.exit(1);
});
