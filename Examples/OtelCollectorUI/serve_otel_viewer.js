#!/usr/bin/env node
const express = require('express');
const path = require('path');
const open = require('open');

const app = express();
const port = 3000;

// Enable CORS
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  next();
});

// Serve static files from Examples directory
const examplesDir = path.join(__dirname, '..');
app.use(express.static(examplesDir));

app.listen(port, () => {
  const url = `http://localhost:${port}/OtelCollectorUI/otel-timeline-viewer.html`;
  console.log(`OTEL Timeline Viewer running at http://localhost:${port}`);
  console.log(`Open ${url} in your browser`);
  console.log('Press Ctrl+C to stop the server');

  // Try to open browser automatically
  open(url).catch(() => {});
});
