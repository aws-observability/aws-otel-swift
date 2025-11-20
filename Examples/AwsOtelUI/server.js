#!/usr/bin/env node
const express = require('express');
const path = require('path');
const fs = require('fs');
const open = require('open');
const compression = require('compression');
const zlib = require('zlib');
// Use the official OpenTelemetry protobuf root
const root = require('@opentelemetry/otlp-transformer/build/src/generated/root');

const TraceService = root.opentelemetry.proto.collector.trace.v1.ExportTraceServiceRequest;
const LogService = root.opentelemetry.proto.collector.logs.v1.ExportLogsServiceRequest;

console.log('Using official OpenTelemetry protobuf definitions');

// Helper function to extract data from protobuf buffer
function extractReadableData(buffer, service) {
  try {
    const decoded = service.decode(buffer);
    return {
      decoded: decoded.toJSON(),
      extractedStrings: [],
    };
  } catch (err) {
    return {
      error: err.message,
      extractedStrings: [],
      hex: buffer.toString('hex').substring(0, 200),
    };
  }
}

const app = express();
const port = 3000;

// Enable gzip compression
app.use(compression());

// Parse JSON payloads with increased size limit
app.use(express.json({ limit: '50mb' }));
app.use(express.raw({ type: 'application/x-protobuf', limit: '50mb' }));
app.use(express.text({ type: 'text/*', limit: '50mb' }));

// Middleware to handle gzip decompression
app.use((req, res, next) => {
  if (req.get('Content-Encoding') === 'gzip' && Buffer.isBuffer(req.body)) {
    // Check if data is actually gzipped (starts with gzip magic number)
    // Currently, otel-swift upstream will still set gzip header even if the environment
    // does not support the gzip library (for example, on iPhone simulator).
    if (req.body.length >= 2 && req.body[0] === 0x1f && req.body[1] === 0x8b) {
      zlib.gunzip(req.body, (err, decompressed) => {
        if (err) {
          console.error('Gzip decompression error:', err);
          return res.status(400).send('Invalid gzip data');
        }
        req.body = decompressed;
        next();
      });
    } else {
      // Data claims to be gzipped but isn't - process as-is
      next();
    }
  } else {
    next();
  }
});

// Enable CORS
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

// OTEL API endpoints
app.post('/v1/traces', (req, res) => {
  let eventCount = 0;
  
  try {
    if (Buffer.isBuffer(req.body)) {
      const decoded = TraceService.decode(req.body);
      const json = decoded.toJSON();
      eventCount = json.resourceSpans?.reduce((total, rs) => 
        total + (rs.scopeSpans?.reduce((scopeTotal, ss) => 
          scopeTotal + (ss.spans?.length || 0), 0) || 0), 0) || 0;
    }
  } catch (err) {
    // Ignore decode errors for logging
  }
  
  console.log(`[${new Date().toISOString()}] POST /v1/traces - Events: ${eventCount}, Size: ${req.body?.length || 0} bytes`);
  
  // Enable this to verify the batch and retry logic is
  // Inject retryable faults 20% of the time
  // if (Math.random() < 0.2) {
  //   const errorCode = Math.random() < 0.5 ? 500 : 503;
  //   console.log(`Injecting fault: ${errorCode} for traces`);
  //   return res.status(errorCode).send('Server Error');
  // }

  const outDir = path.join(__dirname, 'out');
  if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
  }

  let data;
  try {
    if (Buffer.isBuffer(req.body)) {
      const decoded = TraceService.decode(req.body);
      data = JSON.stringify(decoded.toJSON());
    } else {
      data = JSON.stringify(req.body);
    }
  } catch (err) {
    console.log('Error decoding traces:', err.message);
    if (Buffer.isBuffer(req.body)) {
      const extracted = extractReadableData(req.body, TraceService);
      data = JSON.stringify({
        type: 'protobuf_trace_data_error',
        ...extracted,
      });
    } else {
      data = JSON.stringify(req.body);
    }
  }

  fs.appendFileSync(path.join(outDir, 'traces.jsonl'), data + '\n');
  res.status(200).send('OK');
});

app.post('/v1/logs', (req, res) => {
  let eventCount = 0;
  
  try {
    if (Buffer.isBuffer(req.body)) {
      const decoded = LogService.decode(req.body);
      const json = decoded.toJSON();
      eventCount = json.resourceLogs?.reduce((total, rl) => 
        total + (rl.scopeLogs?.reduce((scopeTotal, sl) => 
          scopeTotal + (sl.logRecords?.length || 0), 0) || 0), 0) || 0;
    }
  } catch (err) {
    // Ignore decode errors for logging
  }
  
  console.log(`[${new Date().toISOString()}] POST /v1/logs - Events: ${eventCount}, Size: ${req.body?.length || 0} bytes`);
  
  // Enable this to verify the batch and retry logic is
  // Inject retryable faults 20% of the time
  // if (Math.random() < 0.2) {
  //   const errorCode = Math.random() < 0.5 ? 500 : 503;
  //   console.log(`Injecting fault: ${errorCode} for logs`);
  //   return res.status(errorCode).send('Server Error');
  // }

  const outDir = path.join(__dirname, 'out');
  if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
  }

  let data;
  try {
    if (Buffer.isBuffer(req.body)) {
      const decoded = LogService.decode(req.body);
      data = JSON.stringify(decoded.toJSON());
    } else {
      data = JSON.stringify(req.body);
    }
  } catch (err) {
    console.log('Error decoding logs:', err.message);
    if (Buffer.isBuffer(req.body)) {
      const extracted = extractReadableData(req.body, LogService);
      data = JSON.stringify({
        type: 'protobuf_log_data_error',
        ...extracted,
      });
    } else {
      data = JSON.stringify(req.body);
    }
  }

  fs.appendFileSync(path.join(outDir, 'logs.jsonl'), data + '\n');
  res.status(200).send('OK');
});

// Serve static files from Examples directory
const examplesDir = path.join(__dirname, './');
app.use(express.static(examplesDir));

app.listen(port, () => {
  const url = `http://localhost:${port}/`;
  console.log(`OTEL Timeline Viewer running at http://localhost:${port}`);
  console.log(`Open ${url} in your browser`);
  console.log('Press Ctrl+C to stop the server');

  // Try to open browser automatically
  open(url).catch(() => {});
});
