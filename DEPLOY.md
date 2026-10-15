# Publicar TechMarket Online en internet (Render + Azure SQL)

La página y el servidor van en **Render**; la base de datos va en **Azure SQL Database**.
El código sigue en GitHub y Render lo descarga de ahí.

## Parte 1: Base de datos en Azure
1. Entra a https://portal.azure.com y crea una cuenta (puede pedir tarjeta; con correo estudiantil revisa "Azure for Students").
2. **Crear un recurso → SQL Database**. En esa pantalla busca el banner **"Apply offer"** (oferta gratuita) y aplícalo.
3. **Server → Create new**: nombre único, región cercana, autenticación **SQL authentication**, usuario y contraseña fuerte (guárdalos).
4. Nombre de la base: `TechMarketOnline`.
5. En "Behavior when free limit reached" elige **Auto-pause** (se pausa en vez de cobrar).
6. **Networking**: Public endpoint = Selected networks. Marca "Add current client IP address" y "Allow Azure services".
   Luego agrega una regla de firewall `0.0.0.0` a `255.255.255.255` (Render cambia de IP; es aceptable solo porque son datos de prueba).
7. Crea la base y espera a que termine.

## Parte 2: Cargar las tablas
1. Abre **SSMS** → Server name: `TU-SERVIDOR.database.windows.net`, Authentication: SQL Server Authentication.
2. En *Options → Connection Properties → Connect to database* escribe `TechMarketOnline`.
3. Abre `backend/TechMarket_AzureSQL.sql` y ejecútalo completo (F5).
   Usa este archivo y NO el otro: el de Azure no trae CREATE DATABASE ni USE.
4. **Cambia la clave del admin**: ejecuta el UPDATE comentado al final del script con tu clave. El repositorio es público.

## Parte 3: Servidor en Render
1. Entra a https://render.com con tu cuenta de GitHub.
2. **New → Web Service** y elige tu repositorio.
3. Configura:
   - **Root Directory:** `backend`
   - **Build Command:** `npm install`
   - **Start Command:** `npm start`
   - **Instance Type:** Free
4. En **Environment Variables** agrega:
   | Variable | Valor |
   |---|---|
   | DB_SERVER | TU-SERVIDOR.database.windows.net |
   | DB_PORT | 1433 |
   | DB_NAME | TechMarketOnline |
   | DB_USER | el usuario de Azure |
   | DB_PASSWORD | la contraseña de Azure |
   | DB_ENCRYPT | true |
   | STAFF_VENTAS_ID | 2 |
5. **Create Web Service**. Cuando termine, abre la URL `https://....onrender.com`.
   En los *Logs* debe aparecer "Conectado a SQL Server".

## Antes de la sustentación
- Render gratis se duerme tras 15 min sin visitas y tarda cerca de 1 min en despertar.
- Azure SQL gratis también se duerme y la primera conexión puede tardar.
- Abre la página unos 5 minutos antes para que ambos estén despiertos.
- Revisa en cada servicio que el plan gratuito siga vigente (los planes cambian).
