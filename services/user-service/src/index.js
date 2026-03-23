//123
const express = require('express');
const promClient = require('prom-client');
const winston = require('winston');

const app = express();
const PORT = process.env.PORT || 3000;

// Prometheus metrics
const register = promClient.register;
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code']
});

const httpRequestTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

// Logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.Console(),
  ],
});

app.use(express.json());

// Middleware for metrics
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.route?.path || req.path, status_code: res.statusCode });
    httpRequestTotal.inc({ method: req.method, route: req.route?.path || req.path, status_code: res.statusCode });
  });
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'user-service', version: process.env.VERSION || '1.0.0' });
});

// Readiness check
app.get('/ready', (req, res) => {
  // In production, check database connectivity
  res.json({ ready: true });
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// API endpoints
app.get('/api/users', (req, res) => {
  logger.info('Fetching users');
  res.json({
    users: [
      { id: 1, name: 'Alice', email: 'alice@example.com' },
      { id: 2, name: 'Bob', email: 'bob@example.com' }
    ]
  });
});

app.get('/api/users/:id', (req, res) => {
  const userId = req.params.id;
  logger.info(`Fetching user ${userId}`);

  if (userId === '1') {
    res.json({ id: 1, name: 'Alice', email: 'alice@example.com' });
  } else {
    res.status(404).json({ error: 'User not found' });
  }
});

app.post('/api/users', (req, res) => {
  const { name, email } = req.body;
  logger.info(`Creating user: ${name}`);

  // Validation
  if (!name || !email) {
    return res.status(400).json({ error: 'Name and email required' });
  }

  res.status(201).json({ id: 3, name, email });
});

// Only start server if not in test mode
let server;
if (process.env.NODE_ENV !== 'test') {
  server = app.listen(PORT, () => {
    logger.info(`User service listening on port ${PORT}`);
  });

  // Graceful shutdown
  process.on('SIGTERM', () => {
    logger.info('SIGTERM received, shutting down gracefully');
    server.close(() => {
      logger.info('Server closed');
      process.exit(0);
    });
  });
}

module.exports = app;
