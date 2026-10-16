const express = require('express');
const productRoutes = require('./routes/products');
const logger = require('./logger');

const app = express();

app.disable('x-powered-by');
app.use(express.json());
app.use(logger.requestLogger);

// Liveness: the process is up and able to answer.
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    service: 'product-catalog',
    version: process.env.APP_VERSION || 'dev',
    timestamp: new Date().toISOString(),
  });
});

// Readiness: flips to 503 while the pod is shutting down, so Kubernetes
// stops sending it new traffic before the process exits.
app.get('/ready', (req, res) => {
  if (app.locals.shuttingDown) {
    return res.status(503).json({ status: 'shutting-down' });
  }
  return res.status(200).json({ status: 'ready' });
});

app.use('/api/v1/products', productRoutes);

app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

app.use((err, req, res, next) => {
  logger.error('unhandled error', { error: err.message, stack: err.stack });
  res.status(500).json({ error: 'Internal server error' });
});

module.exports = app;
