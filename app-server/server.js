const express = require('express');
const { MongoClient } = require('mongodb');

const app = express();
const port = 3000;

// --- MongoDB Configuration ---
// Use environment variables provided by Docker Compose for security and flexibility
const mongoUrl = process.env.MONGO_URL || 'mongodb://mongo:mongopassword@mongodb:27017/bpdata?authSource=admin';
const client = new MongoClient(mongoUrl);

let db;

// --- API Routes ---
app.get('/api/health', (req, res) => {
  const mongoConnected = db ? true : false;
  res.json({
    status: 'ok',
    nodeVersion: process.version,
    mongoConnected: mongoConnected,
    message: 'Application server is running.'
  });
});

app.get('/api/data', async (req, res) => {
  if (!db) {
    return res.status(503).json({ error: 'Database connection not established.' });
  }
  try {
    // Example: insert a document and then find all documents
    const collection = db.collection('visits');
    await collection.insertOne({ source: 'app-server', date: new Date() });
    const documents = await collection.find({}).sort({date: -1}).limit(10).toArray();
    res.json(documents);
  } catch (err) {
    console.error('Error interacting with MongoDB:', err);
    res.status(500).json({ error: 'Failed to retrieve data from database.' });
  }
});

// --- Start Server and Connect to DB ---
app.listen(port, async () => {
  console.log(`Application server listening on port ${port}`);
  try {
    await client.connect();
    db = client.db(); // The database name is specified in the connection string
    console.log('Successfully connected to MongoDB.');
  } catch (err) {
    console.error('Failed to connect to MongoDB. The app will run without DB access.', err);
  }
});