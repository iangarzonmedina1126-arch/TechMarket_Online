require('dotenv').config();
const express = require('express');
const sql = require('mssql');
const crypto = require('crypto');

const app = express();
app.use(express.json());
app.use(express.static('public'));

const cfg = {
  server: process.env.DB_SERVER || 'localhost',
  port: +(process.env.DB_PORT || 1433),
  database: process.env.DB_NAME || 'TechMarketOnline',
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  connectionTimeout: 60000,   // Azure SQL gratis se "duerme"; despertar puede tardar
  requestTimeout: 60000,
  // Azure SQL exige cifrado: en la nube DB_ENCRYPT=true; en tu PC con SQL Server local, false
  options: { encrypt: process.env.DB_ENCRYPT === 'true', trustServerCertificate: process.env.DB_ENCRYPT !== 'true' }
};
const STAFF_VENTAS = +(process.env.STAFF_VENTAS_ID || 2);
let pool;

/* ---------- utilidades ---------- */
// h = pool (por defecto) o una transaccion; los parametros SIEMPRE van con input() (evita inyeccion SQL)
const run = async (text, p = {}, h) => {
  h = h || pool;
  if (!h) throw bad('La base de datos se está iniciando, intenta de nuevo en un minuto', 503);
  const rq = h.request();
  for (const k in p) rq.input(k, p[k]);
  return (await rq.query(text)).recordset || [];
};
const trans = async fn => {
  if (!pool) throw bad('La base de datos se está iniciando, intenta de nuevo en un minuto', 503);
  const tx = new sql.Transaction(pool);
  await tx.begin();
  try { const r = await fn(tx); await tx.commit(); return r; }
  catch (e) { await tx.rollback().catch(() => {}); throw e; }
};
const hash = s => crypto.createHash('sha256').update(s).digest('hex').toUpperCase(); // igual que HASHBYTES('SHA2_256') del script
const bad = (m, s = 400) => Object.assign(new Error(m), { status: s });
const wrap = f => (req, res) => f(req, res).catch(e => {
  if (e.number === 2627 || e.number === 2601) e = bad('Ya existe un registro con esos datos', 409);
  if (!e.status) console.error(e);
  res.status(e.status || 500).json({ error: e.status ? e.message : 'Error en el servidor' });
});

/* ---------- sesiones en memoria ---------- */
const S = new Map();
const auth = (req, res, next) => {
  const u = S.get((req.headers.authorization || '').slice(7));
  if (!u) return res.status(401).json({ error: 'Debes iniciar sesión' });
  req.u = u; next();
};
const admin = (req, res, next) =>
  req.u.rol === 'admin' ? next() : res.status(403).json({ error: 'Solo administradores' });

/* ---------- público: catálogo ---------- */
app.get('/api/categorias', wrap(async (req, res) => {
  res.json(await run(`SELECT Id_categoria id, Id_categoria_principal padre, Nombre nombre
                      FROM CATEGORIAS WHERE Estado = 1 ORDER BY Id_categoria`));
}));
app.get('/api/productos', wrap(async (req, res) => {
  res.json(await run(`SELECT Id_producto id, Id_categoria ci, Nombre name, Descripcion [desc], Precio price, Stock stock
                      FROM PRODUCTOS WHERE Estado = 1 ORDER BY Id_producto`));
}));

/* ---------- registro / login ---------- */
app.post('/api/registro', wrap(async (req, res) => {
  const { correo = '', password = '', tipo_documento = '', numero_documento = '', telefono = '' } = req.body;
  const c = correo.trim().toLowerCase();
  if (!/^\S+@\S+\.\S+$/.test(c)) throw bad('Correo inválido');
  if (password.length < 6) throw bad('La contraseña necesita al menos 6 caracteres');
  if (!['CC', 'CE', 'NIT', 'TI', 'PAS'].includes(tipo_documento) || !numero_documento.trim()) throw bad('Documento inválido');
  await trans(async tx => {
    const [u] = await run(`INSERT INTO USUARIO (Contrasena_hash, Correo) OUTPUT INSERTED.Id_usuario AS id VALUES (@h, @c)`,
      { h: hash(password), c }, tx);
    await run(`INSERT INTO CLIENTE (Id_usuario, Tipo_documento, Numero_documento, Correo, Telefono) VALUES (@u, @t, @n, @c, @tel)`,
      { u: u.id, t: tipo_documento, n: numero_documento.trim(), c, tel: telefono.trim() }, tx);
  });
  res.json({ ok: true });
}));

app.post('/api/login', wrap(async (req, res) => {
  const { correo = '', password = '' } = req.body;
  const [u] = await run(
    `SELECT u.Correo, c.Id_cliente cid, s.Id_usuario_staff sid
     FROM USUARIO u
     LEFT JOIN CLIENTE c ON c.Id_usuario = u.Id_usuario
     LEFT JOIN STAFF s ON s.Id_usuario = u.Id_usuario AND s.Estado = 1 AND s.Cargo = 'Administrador'
     WHERE u.Correo = @c AND u.Contrasena_hash = @h AND u.Estado = 1`,
    { c: correo.trim().toLowerCase(), h: hash(password) });
  if (!u) throw bad('Correo o contraseña incorrectos', 401);
  const user = { correo: u.Correo, rol: u.sid ? 'admin' : 'cliente', cid: u.cid || null };
  const token = crypto.randomBytes(24).toString('hex');
  S.set(token, user);
  res.json({ token, user });
}));

/* ---------- cliente: direcciones y compra ---------- */
app.get('/api/ubicaciones', auth, wrap(async (req, res) => {
  if (!req.u.cid) throw bad('Solo los clientes tienen direcciones', 403);
  res.json(await run(`SELECT Id_ubicacion id, Direccion_linea dir, Ciudad ciudad, Departamento depto
                      FROM UBICACION WHERE Id_cliente = @c`, { c: req.u.cid }));
}));
app.post('/api/ubicaciones', auth, wrap(async (req, res) => {
  if (!req.u.cid) throw bad('Solo los clientes tienen direcciones', 403);
  const { dir = '', ciudad = '', depto = '', cp = '', ref = '' } = req.body;
  if (!dir.trim() || !ciudad.trim() || !depto.trim()) throw bad('Completa dirección, ciudad y departamento');
  const [r] = await run(`INSERT INTO UBICACION (Id_cliente, Direccion_linea, Ciudad, Departamento, Codigo_postal, Referencia)
                         OUTPUT INSERTED.Id_ubicacion AS id VALUES (@c, @d, @ci, @de, @cp, @r)`,
    { c: req.u.cid, d: dir.trim(), ci: ciudad.trim(), de: depto.trim(), cp: cp.trim(), r: ref.trim() });
  res.json({ id: r.id });
}));

// Crea PEDIDOS + DETALLE_DE_PEDIDO (el disparador descuenta el stock) + VENTAS + PAGO en UNA transacción
app.post('/api/pedidos', auth, wrap(async (req, res) => {
  if (!req.u.cid) throw bad('Solo los clientes pueden comprar', 403);
  const { id_ubicacion, metodo_pago, items } = req.body;
  if (!Array.isArray(items) || !items.length) throw bad('El carrito está vacío');
  if (!['Tarjeta', 'Transferencia', 'Efectivo'].includes(metodo_pago)) throw bad('Método de pago inválido');

  const out = await trans(async tx => {
    const [ub] = await run(`SELECT 1 x FROM UBICACION WHERE Id_ubicacion = @u AND Id_cliente = @c`,
      { u: id_ubicacion, c: req.u.cid }, tx);
    if (!ub) throw bad('Dirección inválida');

    let total = 0; const lines = [];
    for (const it of items) {
      const n = +it.cantidad;
      const [p] = await run(`SELECT Precio, Stock, Nombre FROM PRODUCTOS WITH (UPDLOCK) WHERE Id_producto = @i AND Estado = 1`,
        { i: it.id_producto }, tx);
      if (!p) throw bad('Un producto ya no está disponible');
      if (!Number.isInteger(n) || n < 1 || n > p.Stock) throw bad('Stock insuficiente de ' + p.Nombre);
      total += p.Precio * n; lines.push({ id: it.id_producto, n, precio: p.Precio });
    }
    const [pe] = await run(`INSERT INTO PEDIDOS (Id_cliente, Id_ubicacion, Estado, Total)
                            OUTPUT INSERTED.Id_pedido AS id VALUES (@c, @u, 'Pendiente', @t)`,
      { c: req.u.cid, u: id_ubicacion, t: total }, tx);
    for (const l of lines)
      await run(`INSERT INTO DETALLE_DE_PEDIDO (Id_pedido, Id_producto, Cantidad, Precio_unitario) VALUES (@p, @i, @n, @pr)`,
        { p: pe.id, i: l.id, n: l.n, pr: l.precio }, tx);
    const comp = 'FAC-' + String(pe.id).padStart(3, '0');
    const [v] = await run(`INSERT INTO VENTAS (Id_pedido, Id_cliente, Id_usuario_staff, Numero_comprobante, Total)
                           OUTPUT INSERTED.Id_venta AS id VALUES (@p, @c, @s, @n, @t)`,
      { p: pe.id, c: req.u.cid, s: STAFF_VENTAS, n: comp, t: total }, tx);
    await run(`INSERT INTO PAGO (Id_venta, Metodo_pago, Monto_pagado, Estado_pago) VALUES (@v, @m, @t, @e)`,
      { v: v.id, m: metodo_pago, t: total, e: metodo_pago === 'Efectivo' ? 'Pendiente' : 'Pagado' }, tx);
    return { pedido: pe.id, comprobante: comp, total };
  });
  res.json(out);
}));

/* ---------- administrador ---------- */
const prodBody = b => {
  const d = { ci: +b.ci, name: String(b.name || '').trim(), desc: String(b.desc || '').trim(),
              price: +b.price, stock: +b.stock, min: b.min === '' || b.min == null ? 2 : +b.min, estado: b.estado == 0 ? 0 : 1 };
  if (!d.name || !(d.price > 0) || !Number.isInteger(d.stock) || d.stock < 0 || !Number.isInteger(d.ci) || !Number.isInteger(d.min) || d.min < 0)
    throw bad('Revisa nombre, categoría, precio, stock y stock mínimo');
  return d;
};
app.get('/api/admin/productos', auth, admin, wrap(async (req, res) => {
  res.json(await run(`SELECT p.Id_producto id, p.Id_categoria ci, p.Nombre name, p.Descripcion [desc], p.Precio price,
                             p.Stock stock, p.Estado estado, i.Stock_minimo min
                      FROM PRODUCTOS p LEFT JOIN INVENTARIO i ON i.Id_producto = p.Id_producto ORDER BY p.Id_producto`));
}));
app.post('/api/admin/productos', auth, admin, wrap(async (req, res) => {
  const d = prodBody(req.body);
  await trans(async tx => {
    const [p] = await run(`INSERT INTO PRODUCTOS (Id_categoria, Nombre, Precio, Stock, Descripcion, Estado)
                           OUTPUT INSERTED.Id_producto AS id VALUES (@ci, @n, @pr, @s, @d, @e)`,
      { ci: d.ci, n: d.name, pr: d.price, s: d.stock, d: d.desc, e: d.estado }, tx);
    await run(`INSERT INTO INVENTARIO (Id_producto, Stock_minimo, Stock_maximo) VALUES (@i, @m, @x)`,
      { i: p.id, m: d.min, x: Math.max(50, d.min, d.stock) }, tx);
  });
  res.json({ ok: true });
}));
app.put('/api/admin/productos/:id', auth, admin, wrap(async (req, res) => {
  const d = prodBody(req.body), id = +req.params.id;
  await trans(async tx => {
    await run(`UPDATE PRODUCTOS SET Id_categoria=@ci, Nombre=@n, Precio=@pr, Stock=@s, Descripcion=@d, Estado=@e WHERE Id_producto=@i`,
      { ci: d.ci, n: d.name, pr: d.price, s: d.stock, d: d.desc, e: d.estado, i: id }, tx);
    await run(`UPDATE INVENTARIO SET Stock_minimo=@m, Stock_maximo=CASE WHEN Stock_maximo < @m THEN @m ELSE Stock_maximo END,
               Fecha_ultima_actualizacion=GETDATE() WHERE Id_producto=@i`, { m: d.min, i: id }, tx);
  });
  res.json({ ok: true });
}));
app.delete('/api/admin/productos/:id', auth, admin, wrap(async (req, res) => {
  // baja lógica: el producto puede tener historial en DETALLE_DE_PEDIDO
  await run(`UPDATE PRODUCTOS SET Estado = 0 WHERE Id_producto = @i`, { i: +req.params.id });
  res.json({ ok: true });
}));
app.get('/api/admin/ventas', auth, admin, wrap(async (req, res) => {
  res.json(await run(`SELECT TOP 100 Id_venta, Numero_comprobante, CONVERT(VARCHAR(10), Fecha_venta, 23) Fecha, Cliente, Producto,
                      Cantidad, Total_linea, Total_venta, Metodo_pago, Estado_pago FROM vw_ventas_detalle ORDER BY Id_venta DESC`));
}));

/* ---------- arranque ---------- */
// Abre el puerto primero (los hostings lo exigen) y conecta a la BD con reintentos.
const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`TechMarket listo en http://localhost:${port}`));
(async () => {
  for (let i = 1; i <= 8; i++) {
    try { pool = await sql.connect(cfg); console.log('Conectado a SQL Server'); return; }
    catch (e) { console.error(`Conexión a la BD (${i}/8) falló: ${e.message}`); await new Promise(r => setTimeout(r, 15000)); }
  }
  console.error('No se pudo conectar a la base de datos. Revisa las variables de entorno y el firewall.');
})();
