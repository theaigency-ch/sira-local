import express from "express";
import Redis from "ioredis";

const app = express();
const PORT = process.env.PORT || 8081;
const REDIS_URL = process.env.REDIS_URL || "redis://redis-sira:6379";
const QDRANT_URL = process.env.QDRANT_URL || "http://qdrant:6333";

const redis = new Redis(REDIS_URL);

app.get("/healthz", (_req, res) => res.send("ok"));

app.get("/check", async (_req, res) => {
  try {
    const [rp, qr] = await Promise.all([
      redis.ping(),
      fetch(`${QDRANT_URL}/readyz`).then(r => r.text())
    ]);
    res.json({ redis_ping: rp, qdrant_readyz: qr });
  } catch (e) {
    res.status(500).json({ error: String(e) });
  }
});

app.listen(PORT, () => console.log(`SiraNet dev on :${PORT}`));
