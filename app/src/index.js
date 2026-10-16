const app = require('./app');
const logger = require('./logger');

const PORT = Number(process.env.PORT) || 3000;
// Kubernetes sends SIGTERM, then waits terminationGracePeriodSeconds.
// We fail readiness first, give the load balancer time to drain, then close.
const DRAIN_SECONDS = Number(process.env.SHUTDOWN_DRAIN_SECONDS) || 10;

const server = app.listen(PORT, () => {
  logger.info('server started', { port: PORT });
});

function shutdown(signal) {
  if (app.locals.shuttingDown) return;
  app.locals.shuttingDown = true;
  logger.info('shutdown requested', { signal, drainSeconds: DRAIN_SECONDS });

  setTimeout(() => {
    server.close(() => {
      logger.info('server closed');
      process.exit(0);
    });
    // Hard stop if open connections refuse to close.
    setTimeout(() => process.exit(1), 5000).unref();
  }, DRAIN_SECONDS * 1000);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
