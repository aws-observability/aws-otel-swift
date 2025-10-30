#!/usr/bin/env node
const express = require('express');
const path = require('path');
const fs = require('fs');
const open = require('open');
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

// Parse JSON payloads with increased size limit
app.use(express.json({ limit: '50mb' }));
app.use(express.raw({ type: 'application/x-protobuf', limit: '50mb' }));
app.use(express.text({ type: 'text/*', limit: '50mb' }));

// Enable CORS
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  next();
});

// OTEL API endpoints
app.post('/v1/traces', (req, res) => {
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
