const request = require('supertest');
const app = require('../src/index');

describe('Health Check', () => {
  it('GET /health → 200 with healthy status', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(res.body.service).toBe('product-catalog');
  });
});

describe('Products API', () => {
  it('GET /api/v1/products → returns all products', async () => {
    const res = await request(app).get('/api/v1/products');
    expect(res.statusCode).toBe(200);
    expect(res.body.products).toHaveLength(3);
  });

  it('GET /api/v1/products?category=electronics → filters correctly', async () => {
    const res = await request(app).get('/api/v1/products?category=electronics');
    expect(res.statusCode).toBe(200);
    expect(res.body.products.every(p => p.category === 'electronics')).toBe(true);
  });

  it('GET /api/v1/products/:id → returns single product', async () => {
    const res = await request(app).get('/api/v1/products/1');
    expect(res.statusCode).toBe(200);
    expect(res.body.name).toBe('Laptop Pro');
  });

  it('GET /api/v1/products/:id with bad id → 404', async () => {
    const res = await request(app).get('/api/v1/products/999');
    expect(res.statusCode).toBe(404);
  });
});
