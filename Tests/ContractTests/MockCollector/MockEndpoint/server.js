const http = require('http');

// No Docker: Using 8181 directly until docker is enabled on macos-15 runners on Github actions
const NO_DOCKER_ENDPOINT = 8181;

// Track all active connections
const connections = new Set();

const server = http.createServer((req, res) => {
  console.log(`Received request: ${req.method} ${req.url}`);
  
  // Parse the path to determine which response to send
  const path = req.url.toLowerCase();
  
  if (path === '/200' || path === '/') {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({
      status: 'OK',
      message: 'Request successful'
    }));
  } else if (path === '/404') {
    res.statusCode = 404;
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({
      status: 'ResourceNotFound',
      message: 'The requested resource was not found'
    }));
  } else if (path === '/500') {
    res.statusCode = 500;
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({
      status: 'InternalServerException',
      message: 'An internal server error occurred'
    }));
  } else {
    // Default to 404 for any other path
    res.statusCode = 404;
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({
      status: 'ResourceNotFound',
      message: 'The requested resource was not found'
    }));
  }
});

// Track new connections
server.on('connection', (connection) => {
  connections.add(connection);
  connection.on('close', () => {
    connections.delete(connection);
  });
});

const PORT = NO_DOCKER_ENDPOINT || 8080; 

// Start the server
const runningServer = server.listen(PORT, () => {
  console.log(`Contract Test Endpoint running on port ${PORT}`);
  console.log('Available endpoints:');
  console.log('  / or /200 - Returns 200 OK');
  console.log('  /404      - Returns 404 ResourceNotFound');
  console.log('  /500      - Returns 500 InternalServerException');
});

// Shutdown timeout in milliseconds (2 seconds)
const SHUTDOWN_TIMEOUT = 2000;

// Graceful shutdown function
function shutdown() {
  console.log('Shutdown initiated');
  
  // Set a timeout to force close if graceful shutdown takes too long
  const forceShutdown = setTimeout(() => {
    console.log(`Forcing shutdown after ${SHUTDOWN_TIMEOUT}ms timeout`);
    process.exit(1);
  }, SHUTDOWN_TIMEOUT);
  
  // Clear the timeout if we close successfully
  forceShutdown.unref();
  
  // First, stop accepting new connections
  runningServer.close(() => {
    console.log('HTTP server closed successfully');
    clearTimeout(forceShutdown);
    process.exit(0);
  });
  
  // Forcibly close any existing connections
  if (connections.size) {
    console.log(`Closing ${connections.size} active connections`);
    for (const connection of connections) {
      connection.end();
      connection.destroy();
    }
  }
}

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received');
  shutdown();
});

// Also handle SIGINT (Ctrl+C) for local development
process.on('SIGINT', () => {
  console.log('SIGINT signal received');
  shutdown();
});
