const request = require('supertest');
const app = require('../src/app');

describe('Health and readiness', () => {
  afterEach(() => {
    app.locals.shuttingDown = false;
  });

  it('GET /health returns 200 with healthy status', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(res.body.service).toBe('product-catalog');
  });

  it('GET /ready returns 200 while running', async () => {
    const res = await request(app).get('/ready');
    expect(res.statusCode).toBe(200);
  });

  it('GET /ready returns 503 once shutdown has started', async () => {
    app.locals.shuttingDown = true;
    const res = await request(app).get('/ready');
    expect(res.statusCode).toBe(503);
  });
});

describe('Products API', () => {
  it('GET /api/v1/products returns all products', async () => {
    const res = await request(app).get('/api/v1/products');
    expect(res.statusCode).toBe(200);
    expect(res.body.count).toBe(3);
    expect(res.body.products).toHaveLength(3);
  });

  it('GET /api/v1/products?category=electronics filters correctly', async () => {
    const res = await request(app).get('/api/v1/products?category=electronics');
    expect(res.statusCode).toBe(200);
    expect(res.body.count).toBe(2);
    expect(res.body.products.every((p) => p.category === 'electronics')).toBe(true);
  });

  it('GET /api/v1/products?category=unknown returns an empty list', async () => {
    const res = await request(app).get('/api/v1/products?category=unknown');
    expect(res.statusCode).toBe(200);
    expect(res.body.count).toBe(0);
  });

  it('GET /api/v1/products/:id returns a single product', async () => {
    const res = await request(app).get('/api/v1/products/1');
    expect(res.statusCode).toBe(200);
    expect(res.body.name).toBe('Laptop Pro');
  });

  it('GET /api/v1/products/:id with unknown id returns 404', async () => {
    const res = await request(app).get('/api/v1/products/999');
    expect(res.statusCode).toBe(404);
  });

  it('unknown route returns 404 JSON', async () => {
    const res = await request(app).get('/does-not-exist');
    expect(res.statusCode).toBe(404);
    expect(res.body.error).toBe('Route not found');
  });
});
