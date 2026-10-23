# Colección Postman · HU-410

| Archivo | Qué es |
|---|---|
| `HU-410.postman_collection.json` | Casos de API trazados al E3: carpetas **00 · Preparación**, **Smoke** (6 casos) y **Regresión** (11 casos) |
| `HU-410-QA-local.postman_environment.json` | Variables del ambiente: `baseUrl`, tokens de los 4 comercios y de operaciones, secreto del webhook |

## 1. Levantar el ambiente

```bash
cd ambiente
node server.mjs          # http://localhost:4010
```

## 2. Importar en Postman

1. **Import** → arrastra los dos archivos `.json`.
2. Arriba a la derecha, selecciona el environment **HU-410 · QA local**.
3. Corre la carpeta **00 · Preparación** (reinicia la base y el reloj).
4. Corre la carpeta **Smoke** con el **Runner** (clic derecho → *Run folder*).
5. Para la corrida completa, corre la colección entera (Preparación → Smoke → Regresión).

## 3. Correr desde la terminal (Newman)

```bash
npm install -g newman newman-reporter-htmlextra   # una sola vez

newman run E5-automatizacion/postman/HU-410.postman_collection.json \
  -e E5-automatizacion/postman/HU-410-QA-local.postman_environment.json \
  --folder "00 · Preparación" --folder "Smoke" \
  -r cli,htmlextra --reporter-htmlextra-export E4-defectos/resultados/newman-smoke.html
```

Corrida completa (smoke + regresión) y concurrencia:

```bash
newman run E5-automatizacion/postman/HU-410.postman_collection.json \
  -e E5-automatizacion/postman/HU-410-QA-local.postman_environment.json \
  -r cli,htmlextra --reporter-htmlextra-export E4-defectos/resultados/newman-completo.html

node E5-automatizacion/concurrencia/concurrencia.mjs | tee E4-defectos/resultados/concurrencia.txt
```

Dentro de **Regresión**, TC-07 y TC-12 van al final porque adelantan el reloj del servicio (31 minutos y 24 horas). Para repetir la corrida, empieza siempre por **00 · Preparación**.

## Qué valida cada petición

- **Código HTTP** esperado según el contrato.
- **Esquema de la respuesta** contra `openapi.yaml` v1.1.0. Los esquemas están como variables de la colección (`schema_Verification`, `schema_Signup`, etc.).
- **Reglas del caso** (estado, `error.code`, datos del OCR, canal, código consumido, etc.).
- **En toda respuesta de error** (script a nivel de colección): forma `{error:{code,message}}` y que no aparezca un CUI (Regla 8).

## Notas

- Cada sesión usa un `X-Device-Id` nuevo, para que el límite de intentos no mezcle casos.
- Los webhooks propios (TC-15) se firman en el *pre-request* con HMAC-SHA256 del cuerpo crudo.
- Las pruebas que fallan por un defecto real **deben fallar**: no se ajustan para que pasen.
- La concurrencia (TC-10 y parte de TC-12) no se puede probar con Newman, que ejecuta en secuencia. Va en `E5-automatizacion/concurrencia/concurrencia.mjs` (Node 22, sin dependencias).
