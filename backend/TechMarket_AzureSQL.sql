/* =====================================================================
   TechMarket Online - Script para AZURE SQL DATABASE
   La base de datos se crea desde el portal de Azure; este script crea
   tablas, datos, vista, procedimiento y disparador DENTRO de esa base.
   Ejecutar conectado a la base "TechMarketOnline" (SSMS), todo de una vez.
   ===================================================================== */
/* ======================= 1. TABLAS ======================= */
CREATE TABLE USUARIO (
    Id_usuario      INT IDENTITY(1,1) CONSTRAINT PK_USUARIO PRIMARY KEY,
    Contrasena_hash VARCHAR(64)  NOT NULL,                 -- SHA-256, nunca texto plano
    Correo          VARCHAR(255) NOT NULL CONSTRAINT UQ_USUARIO_Correo UNIQUE,
    Fecha_registro  DATE         NOT NULL CONSTRAINT DF_USUARIO_Fecha DEFAULT GETDATE(),
    Estado          BIT          NOT NULL CONSTRAINT DF_USUARIO_Estado DEFAULT 1
);

CREATE TABLE PROVEEDOR (
    Id_proveedor         INT IDENTITY(1,1) CONSTRAINT PK_PROVEEDOR PRIMARY KEY,
    Numero_documento_nit VARCHAR(30)  NOT NULL CONSTRAINT UQ_PROVEEDOR_NIT UNIQUE,
    Nombre_empresa       VARCHAR(255) NOT NULL,
    Persona_contacto     VARCHAR(255),
    Telefono             VARCHAR(20),
    Correo               VARCHAR(255),
    Direccion            VARCHAR(255),
    Estado               BIT NOT NULL CONSTRAINT DF_PROVEEDOR_Estado DEFAULT 1
);

CREATE TABLE STAFF (
    Id_usuario_staff INT IDENTITY(1,1) CONSTRAINT PK_STAFF PRIMARY KEY,
    Id_usuario       INT NOT NULL CONSTRAINT UQ_STAFF_Usuario UNIQUE,   -- liga el staff con su cuenta
    Cargo            VARCHAR(50) NOT NULL,
    Telefono         VARCHAR(20),
    Fecha_ingreso    DATE NOT NULL CONSTRAINT DF_STAFF_Fecha DEFAULT GETDATE(),
    Estado           BIT  NOT NULL CONSTRAINT DF_STAFF_Estado DEFAULT 1,
    CONSTRAINT FK_STAFF_USUARIO FOREIGN KEY (Id_usuario) REFERENCES USUARIO(Id_usuario),
    CONSTRAINT CK_STAFF_Cargo CHECK (Cargo IN ('Administrador','Vendedor','Soporte','Bodega'))
);

CREATE TABLE CATEGORIAS (
    Id_categoria           INT IDENTITY(1,1) CONSTRAINT PK_CATEGORIAS PRIMARY KEY,
    Id_categoria_principal INT NULL,                                    -- autorreferencia (subcategorias)
    Nombre                 VARCHAR(100) NOT NULL,
    Descripcion            VARCHAR(255),
    Estado                 BIT NOT NULL CONSTRAINT DF_CATEGORIAS_Estado DEFAULT 1,
    CONSTRAINT FK_CATEGORIAS_PADRE FOREIGN KEY (Id_categoria_principal) REFERENCES CATEGORIAS(Id_categoria)
);

CREATE TABLE CLIENTE (
    Id_cliente       INT IDENTITY(1,1) CONSTRAINT PK_CLIENTE PRIMARY KEY,
    Id_usuario       INT NOT NULL CONSTRAINT UQ_CLIENTE_Usuario UNIQUE,
    Tipo_documento   VARCHAR(5)  NOT NULL,
    Numero_documento VARCHAR(30) NOT NULL,
    Correo           VARCHAR(255) NOT NULL,
    Telefono         VARCHAR(20),
    Fecha_registro   DATE NOT NULL CONSTRAINT DF_CLIENTE_Fecha DEFAULT GETDATE(),
    Estado           BIT  NOT NULL CONSTRAINT DF_CLIENTE_Estado DEFAULT 1,
    CONSTRAINT FK_CLIENTE_USUARIO FOREIGN KEY (Id_usuario) REFERENCES USUARIO(Id_usuario),
    CONSTRAINT UQ_CLIENTE_Doc UNIQUE (Tipo_documento, Numero_documento),
    CONSTRAINT CK_CLIENTE_TipoDoc CHECK (Tipo_documento IN ('CC','CE','NIT','TI','PAS'))
);

CREATE TABLE PRODUCTOS (
    Id_producto  INT IDENTITY(1,1) CONSTRAINT PK_PRODUCTOS PRIMARY KEY,
    Id_categoria INT NOT NULL,
    Nombre       VARCHAR(150) NOT NULL,
    Precio       DECIMAL(12,2) NOT NULL,
    Stock        INT NOT NULL CONSTRAINT DF_PRODUCTOS_Stock DEFAULT 0,
    Descripcion  VARCHAR(255),
    Estado       BIT NOT NULL CONSTRAINT DF_PRODUCTOS_Estado DEFAULT 1,
    CONSTRAINT FK_PRODUCTOS_CATEGORIA FOREIGN KEY (Id_categoria) REFERENCES CATEGORIAS(Id_categoria),
    CONSTRAINT CK_PRODUCTOS_Precio CHECK (Precio > 0),
    CONSTRAINT CK_PRODUCTOS_Stock  CHECK (Stock >= 0)
);

CREATE TABLE PEDIDOS_PROVEEDOR (
    Id_pedido_proveedor INT IDENTITY(1,1) CONSTRAINT PK_PEDIDOS_PROV PRIMARY KEY,
    Id_proveedor        INT NOT NULL,
    Id_usuario_staff    INT NOT NULL,
    Fecha_orden         DATE NOT NULL CONSTRAINT DF_PEDPROV_Fecha DEFAULT GETDATE(),
    Estado_pedido       VARCHAR(20) NOT NULL,
    Costo_total         DECIMAL(12,2) NOT NULL,
    CONSTRAINT FK_PEDPROV_PROVEEDOR FOREIGN KEY (Id_proveedor)     REFERENCES PROVEEDOR(Id_proveedor),
    CONSTRAINT FK_PEDPROV_STAFF     FOREIGN KEY (Id_usuario_staff) REFERENCES STAFF(Id_usuario_staff),
    CONSTRAINT CK_PEDPROV_Estado CHECK (Estado_pedido IN ('Pendiente','Recibido','Cancelado')),
    CONSTRAINT CK_PEDPROV_Costo  CHECK (Costo_total >= 0)
);

CREATE TABLE UBICACION (
    Id_ubicacion    INT IDENTITY(1,1) CONSTRAINT PK_UBICACION PRIMARY KEY,
    Id_cliente      INT NOT NULL,
    Direccion_linea VARCHAR(255) NOT NULL,
    Ciudad          VARCHAR(100) NOT NULL,
    Departamento    VARCHAR(100) NOT NULL,
    Codigo_postal   VARCHAR(10),
    Referencia      VARCHAR(255),
    CONSTRAINT FK_UBICACION_CLIENTE FOREIGN KEY (Id_cliente) REFERENCES CLIENTE(Id_cliente)
);

CREATE TABLE PEDIDOS (
    Id_pedido    INT IDENTITY(1,1) CONSTRAINT PK_PEDIDOS PRIMARY KEY,
    Id_cliente   INT NOT NULL,
    Id_ubicacion INT NOT NULL,
    Fecha_pedido DATE NOT NULL CONSTRAINT DF_PEDIDOS_Fecha DEFAULT GETDATE(),
    Estado       VARCHAR(20) NOT NULL,
    Total        DECIMAL(12,2) NOT NULL,
    CONSTRAINT FK_PEDIDOS_CLIENTE   FOREIGN KEY (Id_cliente)   REFERENCES CLIENTE(Id_cliente),
    CONSTRAINT FK_PEDIDOS_UBICACION FOREIGN KEY (Id_ubicacion) REFERENCES UBICACION(Id_ubicacion),
    CONSTRAINT CK_PEDIDOS_Estado CHECK (Estado IN ('Pendiente','Enviado','Entregado','Cancelado')),
    CONSTRAINT CK_PEDIDOS_Total  CHECK (Total >= 0)
);

CREATE TABLE VENTAS (
    Id_venta           INT IDENTITY(1,1) CONSTRAINT PK_VENTAS PRIMARY KEY,
    Id_pedido          INT NOT NULL CONSTRAINT UQ_VENTAS_Pedido UNIQUE,   -- una venta por pedido
    Id_cliente         INT NOT NULL,
    Id_usuario_staff   INT NOT NULL,
    Numero_comprobante VARCHAR(30) NOT NULL CONSTRAINT UQ_VENTAS_Comprobante UNIQUE,
    Fecha_venta        DATE NOT NULL CONSTRAINT DF_VENTAS_Fecha DEFAULT GETDATE(),
    Total              DECIMAL(12,2) NOT NULL,
    CONSTRAINT FK_VENTAS_PEDIDO  FOREIGN KEY (Id_pedido)        REFERENCES PEDIDOS(Id_pedido),
    CONSTRAINT FK_VENTAS_CLIENTE FOREIGN KEY (Id_cliente)       REFERENCES CLIENTE(Id_cliente),
    CONSTRAINT FK_VENTAS_STAFF   FOREIGN KEY (Id_usuario_staff) REFERENCES STAFF(Id_usuario_staff),
    CONSTRAINT CK_VENTAS_Total CHECK (Total >= 0)
);

CREATE TABLE INVENTARIO (
    Id_inventario              INT IDENTITY(1,1) CONSTRAINT PK_INVENTARIO PRIMARY KEY,
    Id_producto                INT NOT NULL CONSTRAINT UQ_INVENTARIO_Producto UNIQUE,
    Stock_minimo               INT NOT NULL,
    Stock_maximo               INT NOT NULL,
    Fecha_ultima_actualizacion DATE NOT NULL CONSTRAINT DF_INV_Fecha DEFAULT GETDATE(),
    CONSTRAINT FK_INVENTARIO_PRODUCTO FOREIGN KEY (Id_producto) REFERENCES PRODUCTOS(Id_producto),
    CONSTRAINT CK_INVENTARIO_Rango CHECK (Stock_minimo >= 0 AND Stock_maximo >= Stock_minimo)
);

CREATE TABLE DETALLE_DE_PEDIDO (
    Id_detalle_pedido INT IDENTITY(1,1) CONSTRAINT PK_DETALLE PRIMARY KEY,
    Id_pedido         INT NOT NULL,
    Id_producto       INT NOT NULL,
    Cantidad          INT NOT NULL,
    Precio_unitario   DECIMAL(12,2) NOT NULL,
    Total AS (Cantidad * Precio_unitario) PERSISTED,                      -- columna calculada
    CONSTRAINT FK_DETALLE_PEDIDO   FOREIGN KEY (Id_pedido)   REFERENCES PEDIDOS(Id_pedido),
    CONSTRAINT FK_DETALLE_PRODUCTO FOREIGN KEY (Id_producto) REFERENCES PRODUCTOS(Id_producto),
    CONSTRAINT UQ_DETALLE_PedProd  UNIQUE (Id_pedido, Id_producto),
    CONSTRAINT CK_DETALLE_Cant   CHECK (Cantidad > 0),
    CONSTRAINT CK_DETALLE_Precio CHECK (Precio_unitario > 0)
);

CREATE TABLE PAGO (
    Id_pago      INT IDENTITY(1,1) CONSTRAINT PK_PAGO PRIMARY KEY,
    Id_venta     INT NOT NULL,
    Metodo_pago  VARCHAR(20) NOT NULL,
    Monto_pagado DECIMAL(12,2) NOT NULL,
    Fecha_pago   DATE NOT NULL CONSTRAINT DF_PAGO_Fecha DEFAULT GETDATE(),
    Estado_pago  VARCHAR(20) NOT NULL,
    CONSTRAINT FK_PAGO_VENTA FOREIGN KEY (Id_venta) REFERENCES VENTAS(Id_venta),
    CONSTRAINT CK_PAGO_Metodo CHECK (Metodo_pago IN ('Tarjeta','Efectivo','Transferencia')),
    CONSTRAINT CK_PAGO_Estado CHECK (Estado_pago IN ('Pagado','Pendiente','Rechazado')),
    CONSTRAINT CK_PAGO_Monto  CHECK (Monto_pagado > 0)
);

CREATE TABLE DEVOLUCION (
    Id_devolucion     INT IDENTITY(1,1) CONSTRAINT PK_DEVOLUCION PRIMARY KEY,
    Id_venta          INT NOT NULL,
    Id_cliente        INT NOT NULL,
    Id_usuario_staff  INT NOT NULL,
    Motivo            VARCHAR(255) NOT NULL,
    Monto_reembolsado DECIMAL(12,2) NOT NULL,
    Fecha_devolucion  DATE NOT NULL CONSTRAINT DF_DEVOL_Fecha DEFAULT GETDATE(),
    Estado            VARCHAR(20) NOT NULL,
    CONSTRAINT FK_DEVOL_VENTA   FOREIGN KEY (Id_venta)         REFERENCES VENTAS(Id_venta),
    CONSTRAINT FK_DEVOL_CLIENTE FOREIGN KEY (Id_cliente)       REFERENCES CLIENTE(Id_cliente),
    CONSTRAINT FK_DEVOL_STAFF   FOREIGN KEY (Id_usuario_staff) REFERENCES STAFF(Id_usuario_staff),
    CONSTRAINT CK_DEVOL_Estado CHECK (Estado IN ('Pendiente','Procesada','Rechazada')),
    CONSTRAINT CK_DEVOL_Monto  CHECK (Monto_reembolsado >= 0)
);

CREATE TABLE SERVICIO_AL_CLIENTE (
    Id_ticket        INT IDENTITY(1,1) CONSTRAINT PK_TICKET PRIMARY KEY,
    Id_cliente       INT NOT NULL,
    Id_usuario_staff INT NOT NULL,
    Id_venta         INT NULL,
    Asunto           VARCHAR(255) NOT NULL,
    Descripcion      VARCHAR(500),
    Prioridad        VARCHAR(10) NOT NULL,
    Estado           VARCHAR(10) NOT NULL,
    Fecha_apertura   DATE NOT NULL CONSTRAINT DF_TICKET_Apertura DEFAULT GETDATE(),
    Fecha_cierre     DATE NULL,
    CONSTRAINT FK_TICKET_CLIENTE FOREIGN KEY (Id_cliente)       REFERENCES CLIENTE(Id_cliente),
    CONSTRAINT FK_TICKET_STAFF   FOREIGN KEY (Id_usuario_staff) REFERENCES STAFF(Id_usuario_staff),
    CONSTRAINT FK_TICKET_VENTA   FOREIGN KEY (Id_venta)         REFERENCES VENTAS(Id_venta),
    CONSTRAINT CK_TICKET_Prioridad CHECK (Prioridad IN ('Alta','Media','Baja')),
    CONSTRAINT CK_TICKET_Estado    CHECK (Estado IN ('Abierto','Cerrado')),
    CONSTRAINT CK_TICKET_Fechas    CHECK (Fecha_cierre IS NULL OR Fecha_cierre >= Fecha_apertura)
);
GO

/* ======================= 2. DATOS DE PRUEBA ======================= */
-- Usuarios (1-3 clientes, 4-5 staff). Las claves se guardan como hash SHA-256.
INSERT INTO USUARIO (Contrasena_hash, Correo) VALUES
 (CONVERT(VARCHAR(64),HASHBYTES('SHA2_256','123456'),2),   'juan@gmail.com'),
 (CONVERT(VARCHAR(64),HASHBYTES('SHA2_256','654321'),2),   'maria@gmail.com'),
 (CONVERT(VARCHAR(64),HASHBYTES('SHA2_256','abc123'),2),   'carlos@gmail.com'),
 (CONVERT(VARCHAR(64),HASHBYTES('SHA2_256','admin123'),2), 'admin@techmarket.co'),
 (CONVERT(VARCHAR(64),HASHBYTES('SHA2_256','vende123'),2), 'vendedor@techmarket.co');

INSERT INTO PROVEEDOR (Numero_documento_nit, Nombre_empresa, Persona_contacto, Telefono, Correo, Direccion) VALUES
 ('900123456-1','Tecnologia Colombia','Pedro Gomez','3001112233','pedro@tecnologia.com','Calle 10 # 20-30'),
 ('901234567-2','Distribuciones ABC','Laura Martinez','3004445566','laura@abc.com','Carrera 15 # 45-60');

INSERT INTO STAFF (Id_usuario, Cargo, Telefono) VALUES
 (4,'Administrador','3101234567'),
 (5,'Vendedor','3107654321');

INSERT INTO CATEGORIAS (Id_categoria_principal, Nombre, Descripcion) VALUES
 (NULL,'Tecnologia','Productos tecnologicos'),
 (1,'Computadores','Computadores y portatiles'),
 (1,'Accesorios','Accesorios para computadores');

INSERT INTO CLIENTE (Id_usuario, Tipo_documento, Numero_documento, Correo, Telefono) VALUES
 (1,'CC','1001234567','juan@gmail.com','3001112233'),
 (2,'CC','1007654321','maria@gmail.com','3004445566'),
 (3,'CC','1009876543','carlos@gmail.com','3007778899');

INSERT INTO PRODUCTOS (Id_categoria, Nombre, Precio, Stock, Descripcion) VALUES
 (2,'Portatil Lenovo',2500000,10,'Portatil para uso personal'),
 (2,'Portatil HP',2200000,8,'Portatil para trabajo'),
 (3,'Mouse Inalambrico',80000,25,'Mouse inalambrico USB'),
 (3,'Teclado USB',120000,15,'Teclado USB para computador');

INSERT INTO PEDIDOS_PROVEEDOR (Id_proveedor, Id_usuario_staff, Estado_pedido, Costo_total) VALUES
 (1,1,'Pendiente',5000000),
 (2,2,'Recibido',2500000);

INSERT INTO UBICACION (Id_cliente, Direccion_linea, Ciudad, Departamento, Codigo_postal, Referencia) VALUES
 (1,'Calle 20 # 15-30','Bogota','Cundinamarca','110111','Casa blanca'),
 (2,'Carrera 10 # 25-40','Bogota','Cundinamarca','110221','Apartamento 302'),
 (3,'Calle 50 # 30-20','Medellin','Antioquia','050001','Casa esquina');

INSERT INTO PEDIDOS (Id_cliente, Id_ubicacion, Estado, Total) VALUES
 (1,1,'Pendiente',2580000),
 (2,2,'Entregado',2320000),
 (3,3,'Enviado',120000);

INSERT INTO VENTAS (Id_pedido, Id_cliente, Id_usuario_staff, Numero_comprobante, Total) VALUES
 (1,1,2,'FAC-001',2580000),
 (2,2,2,'FAC-002',2320000),
 (3,3,1,'FAC-003',120000);

INSERT INTO INVENTARIO (Id_producto, Stock_minimo, Stock_maximo) VALUES
 (1,2,20),(2,2,15),(3,5,50),(4,5,30);

-- El disparador (se crea mas abajo) descuenta stock; aqui el stock inicial ya es el real.
INSERT INTO DETALLE_DE_PEDIDO (Id_pedido, Id_producto, Cantidad, Precio_unitario) VALUES
 (1,1,1,2500000),(1,3,1,80000),
 (2,2,1,2200000),(2,3,1,80000),
 (3,4,1,120000);

INSERT INTO PAGO (Id_venta, Metodo_pago, Monto_pagado, Estado_pago) VALUES
 (1,'Tarjeta',2580000,'Pagado'),
 (2,'Efectivo',2320000,'Pagado'),
 (3,'Transferencia',120000,'Pagado');

INSERT INTO DEVOLUCION (Id_venta, Id_cliente, Id_usuario_staff, Motivo, Monto_reembolsado, Estado) VALUES
 (2,2,1,'Producto defectuoso',80000,'Procesada');

INSERT INTO SERVICIO_AL_CLIENTE (Id_cliente, Id_usuario_staff, Id_venta, Asunto, Descripcion, Prioridad, Estado, Fecha_cierre) VALUES
 (1,1,1,'Consulta sobre pedido','El cliente solicita informacion sobre su pedido','Alta','Cerrado',GETDATE()),
 (2,2,2,'Solicitud de devolucion','El cliente solicita devolver un producto','Media','Abierto',NULL);
GO

/* ======================= 3. VISTA ======================= */
CREATE VIEW vw_ventas_detalle AS
SELECT v.Id_venta, v.Numero_comprobante, v.Fecha_venta,
       c.Correo AS Cliente, pr.Nombre AS Producto, d.Cantidad,
       d.Total AS Total_linea, v.Total AS Total_venta,
       pg.Metodo_pago, pg.Estado_pago
FROM VENTAS v
JOIN CLIENTE c            ON c.Id_cliente  = v.Id_cliente
JOIN DETALLE_DE_PEDIDO d  ON d.Id_pedido   = v.Id_pedido
JOIN PRODUCTOS pr         ON pr.Id_producto = d.Id_producto
LEFT JOIN PAGO pg         ON pg.Id_venta   = v.Id_venta;
GO

/* ======================= 4. DISPARADOR =======================
   Al insertar un detalle de pedido descuenta el stock del producto
   y actualiza la fecha en INVENTARIO. Si no hay stock, el CHECK
   (Stock >= 0) falla y se revierte toda la operacion. */
CREATE TRIGGER trg_detalle_descuenta_stock
ON DETALLE_DE_PEDIDO AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE p SET p.Stock = p.Stock - i.Cant
    FROM PRODUCTOS p
    JOIN (SELECT Id_producto, SUM(Cantidad) AS Cant FROM inserted GROUP BY Id_producto) i
      ON i.Id_producto = p.Id_producto;

    UPDATE inv SET Fecha_ultima_actualizacion = GETDATE()
    FROM INVENTARIO inv
    JOIN inserted i ON i.Id_producto = inv.Id_producto;
END
GO

/* ======================= 5. PROCEDIMIENTO ALMACENADO =======================
   Registra un pedido de un producto (lo que hace "Finalizar compra"). */
CREATE PROCEDURE sp_registrar_pedido
    @Id_cliente   INT,
    @Id_ubicacion INT,
    @Id_producto  INT,
    @Cantidad     INT,
    @Id_pedido    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @precio DECIMAL(12,2), @stock INT;

        SELECT @precio = Precio, @stock = Stock
        FROM PRODUCTOS WITH (UPDLOCK) WHERE Id_producto = @Id_producto AND Estado = 1;

        IF @precio IS NULL THROW 50001, 'El producto no existe o esta inactivo.', 1;
        IF @Cantidad <= 0 OR @Cantidad > @stock THROW 50002, 'Cantidad invalida o stock insuficiente.', 1;
        IF NOT EXISTS (SELECT 1 FROM UBICACION WHERE Id_ubicacion = @Id_ubicacion AND Id_cliente = @Id_cliente)
            THROW 50003, 'La ubicacion no pertenece al cliente.', 1;

        INSERT INTO PEDIDOS (Id_cliente, Id_ubicacion, Estado, Total)
        VALUES (@Id_cliente, @Id_ubicacion, 'Pendiente', @precio * @Cantidad);
        SET @Id_pedido = SCOPE_IDENTITY();

        INSERT INTO DETALLE_DE_PEDIDO (Id_pedido, Id_producto, Cantidad, Precio_unitario)
        VALUES (@Id_pedido, @Id_producto, @Cantidad, @precio);   -- el disparador descuenta el stock
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

/* ======================= 6. CONSULTAS DE VERIFICACION ======================= */
-- 6.1 Registros por tabla (esperado: 5,2,2,3,3,4,2,3,3,3,4,5,3,1,2)
SELECT 'USUARIO' Tabla, COUNT(*) Filas FROM USUARIO UNION ALL
SELECT 'PROVEEDOR', COUNT(*) FROM PROVEEDOR UNION ALL
SELECT 'STAFF', COUNT(*) FROM STAFF UNION ALL
SELECT 'CATEGORIAS', COUNT(*) FROM CATEGORIAS UNION ALL
SELECT 'CLIENTE', COUNT(*) FROM CLIENTE UNION ALL
SELECT 'PRODUCTOS', COUNT(*) FROM PRODUCTOS UNION ALL
SELECT 'PEDIDOS_PROVEEDOR', COUNT(*) FROM PEDIDOS_PROVEEDOR UNION ALL
SELECT 'UBICACION', COUNT(*) FROM UBICACION UNION ALL
SELECT 'PEDIDOS', COUNT(*) FROM PEDIDOS UNION ALL
SELECT 'VENTAS', COUNT(*) FROM VENTAS UNION ALL
SELECT 'INVENTARIO', COUNT(*) FROM INVENTARIO UNION ALL
SELECT 'DETALLE_DE_PEDIDO', COUNT(*) FROM DETALLE_DE_PEDIDO UNION ALL
SELECT 'PAGO', COUNT(*) FROM PAGO UNION ALL
SELECT 'DEVOLUCION', COUNT(*) FROM DEVOLUCION UNION ALL
SELECT 'SERVICIO_AL_CLIENTE', COUNT(*) FROM SERVICIO_AL_CLIENTE;

-- 6.2 Catalogo con su categoria y su categoria principal
SELECT p.Id_producto, p.Nombre, p.Precio, p.Stock, c.Nombre AS Categoria, cp.Nombre AS Categoria_principal
FROM PRODUCTOS p
JOIN CATEGORIAS c ON c.Id_categoria = p.Id_categoria
LEFT JOIN CATEGORIAS cp ON cp.Id_categoria = c.Id_categoria_principal;

-- 6.3 Vista de ventas
SELECT * FROM vw_ventas_detalle ORDER BY Id_venta;

-- 6.4 Productos por debajo del stock minimo (alerta del panel Admin)
SELECT p.Nombre, p.Stock, i.Stock_minimo,
       CASE WHEN p.Stock <= i.Stock_minimo THEN 'REABASTECER' ELSE 'OK' END AS Alerta
FROM PRODUCTOS p JOIN INVENTARIO i ON i.Id_producto = p.Id_producto;

-- 6.5 Ventas por metodo de pago
SELECT Metodo_pago, COUNT(*) Num_pagos, SUM(Monto_pagado) Total_recaudado
FROM PAGO WHERE Estado_pago = 'Pagado' GROUP BY Metodo_pago;

-- 6.6 Procedimiento + disparador: comprar 2 Mouse (stock 25 -> 23)
SELECT Nombre, Stock AS Stock_antes FROM PRODUCTOS WHERE Id_producto = 3;
DECLARE @nuevo INT;
EXEC sp_registrar_pedido @Id_cliente = 1, @Id_ubicacion = 1, @Id_producto = 3, @Cantidad = 2, @Id_pedido = @nuevo OUTPUT;
SELECT @nuevo AS Pedido_creado;
SELECT Nombre, Stock AS Stock_despues FROM PRODUCTOS WHERE Id_producto = 3;
SELECT * FROM PEDIDOS WHERE Id_pedido = @nuevo;
SELECT * FROM DETALLE_DE_PEDIDO WHERE Id_pedido = @nuevo;

-- 6.7 Prueba de error controlado: pedir mas unidades que el stock
BEGIN TRY
    DECLARE @x INT;
    EXEC sp_registrar_pedido 1, 1, 3, 9999, @x OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;   -- 50002
END CATCH;

-- 6.8 Prueba de restriccion: precio negativo debe fallar (CK_PRODUCTOS_Precio)
BEGIN TRY
    INSERT INTO PRODUCTOS (Id_categoria, Nombre, Precio, Stock) VALUES (2,'Prueba',-1,1);
END TRY
BEGIN CATCH
    SELECT ERROR_MESSAGE() AS Restriccion_violada;
END CATCH;
GO

/* =============== CAMBIA LA CLAVE DEL ADMIN (el repositorio es publico) ===============
   Ejecuta esta linea con TU clave antes de publicar la pagina:
UPDATE USUARIO SET Contrasena_hash = CONVERT(VARCHAR(64),HASHBYTES('SHA2_256','TU_CLAVE_NUEVA'),2)
WHERE Correo = 'admin@techmarket.co';
*/
