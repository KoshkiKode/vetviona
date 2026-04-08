const express = require('express');
const mysql = require('mysql2');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const cors = require('cors');

const app = express();
const PORT = 3000;
const SECRET_KEY = 'your-secret-key'; // Use env in production

app.use(cors());
app.use(express.json());

const db = mysql.createConnection({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'ancestry',
});

db.connect((err) => {
  if (err) throw err;
  console.log('Connected to database');

  // Create tables if not exist
  db.query(`
    CREATE TABLE IF NOT EXISTS users (
      id INT AUTO_INCREMENT PRIMARY KEY,
      username VARCHAR(255) UNIQUE,
      password VARCHAR(255)
    )
  `\);
  db.query(`
    CREATE TABLE IF NOT EXISTS persons (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT,
      person_data JSON,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  `\);
});

// Register
app.post('/register', async (req, res) => {
  const { username, password } = req.body;
  const hashedPassword = await bcrypt.hash(password, 10);
  db.query('INSERT INTO users (username, password) VALUES (?, ?)', [username, hashedPassword], (err) => {
    if (err) return res.status(400).json({ error: 'User exists' });
    res.json({ message: 'User created' });
  });
});

// Login
app.post('/login', (req, res) => {
  const { username, password } = req.body;
  db.query('SELECT * FROM users WHERE username = ?', [username], async (err, results) => {
    if (err || results.length === 0) return res.status(401).json({ error: 'Invalid credentials' });
    const user = results[0];
    if (!(await bcrypt.compare(password, user.password))) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    const token = jwt.sign({ id: user.id }, SECRET_KEY);
    res.json({ token });
  });
});

// Middleware to verify token
const authenticate = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'No token' });
  jwt.verify(token, SECRET_KEY, (err, decoded) => {
    if (err) return res.status(401).json({ error: 'Invalid token' });
    req.userId = decoded.id;
    next();
  });
};

// Sync persons
app.post('/sync', authenticate, (req, res) => {
  const { persons } = req.body;
  db.query('DELETE FROM persons WHERE user_id = ?', [req.userId]);
  const values = persons.map(person => [req.userId, JSON.stringify(person)]);
  db.query('INSERT INTO persons (user_id, person_data) VALUES ?', [values], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'Synced' });
  });
});

// Get persons
app.get('/persons', authenticate, (req, res) => {
  db.query('SELECT person_data FROM persons WHERE user_id = ?', [req.userId], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    const persons = results.map(row => JSON.parse(row.person_data));
    res.json(persons);
  });
});

app.listen(PORT, () => {
  console.log('Server running on port ' + PORT);
});
