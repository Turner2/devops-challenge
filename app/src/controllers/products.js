const products = [
  { id: '1', name: 'Laptop Pro', category: 'electronics', price: 1299.99, stock: 42 },
  { id: '2', name: 'Wireless Mouse', category: 'electronics', price: 29.99, stock: 150 },
  { id: '3', name: 'Standing Desk', category: 'furniture', price: 499.99, stock: 20 },
];

const getAllProducts = (req, res) => {
  const { category } = req.query;
  const result = category
    ? products.filter(p => p.category === category)
    : products;
  res.status(200).json({ count: result.length, products: result });
};

const getProductById = (req, res) => {
  const product = products.find(p => p.id === req.params.id);
  if (!product) {
    return res.status(404).json({ error: `Product ${req.params.id} not found` });
  }
  res.status(200).json(product);
};

module.exports = { getAllProducts, getProductById };
