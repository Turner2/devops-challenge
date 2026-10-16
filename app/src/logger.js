// Minimal structured logger.
// Every line is one JSON object on stdout, so Fluent Bit ships it to
// CloudWatch Logs as-is and Logs Insights can filter on fields like
// `level`, `status` or `durationMs` without any parsing rules.

const LEVELS = { debug: 10, info: 20, warn: 30, error: 40 };
const minLevel = LEVELS[process.env.LOG_LEVEL] || LEVELS.info;
const silent = process.env.NODE_ENV === 'test';

function log(level, message, fields = {}) {
  if (silent || LEVELS[level] < minLevel) return;
  const line = {
    timestamp: new Date().toISOString(),
    level,
    service: 'product-catalog',
    version: process.env.APP_VERSION || 'dev',
    message,
    ...fields,
  };
  const out = level === 'error' ? process.stderr : process.stdout;
  out.write(`${JSON.stringify(line)}\n`);
}

// Express middleware: one access-log line per request.
function requestLogger(req, res, next) {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    if (req.path === '/health') return; // probes every few seconds would drown real traffic
    const durationMs = Number(process.hrtime.bigint() - start) / 1e6;
    log(res.statusCode >= 500 ? 'error' : 'info', 'request', {
      method: req.method,
      path: req.originalUrl,
      status: res.statusCode,
      durationMs: Math.round(durationMs * 100) / 100,
    });
  });
  next();
}

module.exports = {
  debug: (m, f) => log('debug', m, f),
  info: (m, f) => log('info', m, f),
  warn: (m, f) => log('warn', m, f),
  error: (m, f) => log('error', m, f),
  requestLogger,
};
