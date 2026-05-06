const express = require("express");
const { Pool } = require("pg");
const cors = require("cors");
const client = require("prom-client");

const app = express();
app.use(cors());
app.use(express.json());

client.collectDefaultMetrics({ timeout: 5000 });

const pool = new Pool({
  host: process.env.DB_HOST || "localhost",
  user: "postgres",
  password: "postgres",
  database: "fintech",
  port: 5432,
});

app.get("/api/health", (req, res) => {
  res.json({ status: "ok" });
});

app.get("/api/users", async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM users");
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post("/api/users", async (req, res) => {
  const { name } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ error: "Name is required" });
  }

  try {
    const result = await pool.query(
      "INSERT INTO users(name) VALUES($1) RETURNING *",
      [name.trim()]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/metrics", async (req, res) => {
  try {
    res.set("Content-Type", client.register.contentType);
    res.end(await client.register.metrics());
  } catch (err) {
    res.status(500).end(err.message);
  }
});

const port = Number(process.env.API_PORT || 3000);
app.listen(port, () => console.log(`Backend running on port ${port}`));