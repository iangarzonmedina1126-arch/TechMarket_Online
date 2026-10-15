// Ejecuta TechMarket_SQLServer.sql (separando los lotes por GO) sin necesitar SSMS ni sqlcmd.
require('dotenv').config();
const fs = require('fs'), path = require('path'), sql = require('mssql');
const file = process.argv[2] || path.join(__dirname, 'TechMarket_SQLServer.sql');

(async () => {
  const cfg = {
    server: process.env.DB_SERVER || 'localhost', port: +(process.env.DB_PORT || 1433),
    database: 'master', user: process.env.DB_USER, password: process.env.DB_PASSWORD,
    requestTimeout: 120000,
    pool: { max: 1, min: 1, idleTimeoutMillis: 600000 },   // una sola conexión: USE se mantiene entre lotes
    options: { encrypt: process.env.DB_ENCRYPT === 'true', trustServerCertificate: true }
  };
  let pool;
  for (let i = 1; i <= 12 && !pool; i++) {
    try { pool = await new sql.ConnectionPool(cfg).connect(); }
    catch (e) { console.log(`Esperando a SQL Server (${i}/12)...`); await new Promise(r => setTimeout(r, 5000)); }
  }
  if (!pool) { console.error('No se pudo conectar a SQL Server. Revisa .env'); process.exit(1); }

  let text = fs.readFileSync(file, 'utf8');
  const cut = text.indexOf('/* ======================= 6.');   // no ejecutar las consultas de prueba (dejan pedidos extra)
  if (cut > 0) text = text.slice(0, cut);
  const batches = text.split(/^\s*GO\s*$/im).map(b => b.trim()).filter(Boolean);
  let n = 0;
  for (const b of batches) {
    try { await pool.request().batch(b); n++; }
    catch (e) { console.error(`Error en el lote ${n + 1}: ${e.message}`); process.exit(1); }
  }
  console.log(`Listo: ${n} lotes ejecutados. Base TechMarketOnline creada con datos de prueba.`);
  await pool.close();
})();
