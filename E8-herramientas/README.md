# E8 · Bitácora de herramientas – HU-410

**Autor:** Belly Espinal · **Fecha:** 2026-10-22 · **Versión:** 2

## 1. Herramientas y para qué las usé

| Herramienta | Para qué | Entregables |
|---|---|---|
| **Visual Studio Code** | Leer el contrato `openapi.yaml` y el `README.md` del ambiente (el código del servicio quedó fuera de alcance: se probó como caja negra); editar la colección, el script de concurrencia y los README. | E1, E5 |
| **Node.js 22** | Levantar el servicio de QA (`node server.mjs`, puerto 4010) y correr el script de concurrencia con `fetch` y `node:crypto`, sin dependencias. | E4, E5 |
| **Postman** | Diseñar y depurar los casos de API: environment con `baseUrl`, tokens de los 4 comercios y de operaciones; encadenamiento de IDs entre llamadas; firma HMAC-SHA256 de los webhooks en el *pre-request* (CryptoJS); validación de esquemas contra el contrato (`pm.response.to.have.jsonSchema`); y el Runner para las carpetas Smoke y Regresión. | E3, E4, E5 |
| **Newman** | Correr la colección desde la terminal, con el smoke por separado de la corrida completa, sobre un ambiente recién reiniciado. Es la forma reproducible de la suite. | E4, E5 |
| **newman-reporter-htmlextra** | Generar `newman-smoke.html` y `newman-completo.html` con cada petición, su respuesta y sus validaciones. Son la evidencia del E4. | E4 |
| **Script de extracción** | Extraer las 196 peticiones del reporte HTML a `ejecucion-completa.json`, para citar cada defecto con su petición y respuesta. | E4 |
| **SQLite + Python (`sqlite3`)** | Guardar una copia de la base después de cada corrida (`qa_smoke_*.db`, `qa_completo_*.db`) y correr las 16 consultas del E6 en modo solo lectura con `E6-datos/ejecutar_consultas.py`. También levanté el servicio con una base nueva (`DB_PATH` temporal) para identificar los datos sembrados del sprint anterior. | E4, E6 |
| **Microsoft Word y Excel** | Redactar el análisis, la estrategia y el reporte de defectos (Word), y la matriz de casos trazable (Excel). | E1, E2, E3, E4 |
| **Claude (IA, Anthropic)** | Asistente en las partes que se detallan en la sección 2. | E1, E2, E3, E5, E7 |

¿Por qué Postman + Newman? El caso permite cualquier herramienta. Elegí Postman porque deja ver cada petición mientras se diseña el caso, y Newman porque corre la misma colección desde la terminal, sin cambios, para el smoke de liberación. Newman ejecuta en secuencia, así que la concurrencia (TC-10) va en un script de Node aparte, que dispara las solicitudes en paralelo con `Promise.all`.

## 2. Uso de IA

Usé Claude como asistente. Las decisiones de QA son mías: qué probar, cuál es el resultado esperado, la severidad de cada defecto y la recomendación. Revisé todo lo que propuso la IA contra el contrato y contra la ejecución real antes de incluirlo.

| Entregable | Qué hizo la IA | Qué hice yo |
|---|---|---|
| **E1 · Análisis** | Cruzar la HU, las reglas y la tabla de estados con `openapi.yaml` para encontrar contradicciones y vacíos; proponer la redacción de las preguntas al PO. | Decidir el riesgo y el supuesto de cada punto; actualizar el análisis a la versión 2 cuando el contrato resolvió parte de las dudas, y agregar A-16 y A-17. |
| **E2 · Estrategia** | Proponer la estructura y condensarla en una página. | Definir el orden de los riesgos, el alcance y los criterios Go / Go condicionado / No-Go. |
| **E3 · Casos** | Sugerir técnicas de diseño y valores límite (0.79 / 0.80 / 0.81; 29, 30 y 31 minutos). | Elegir los casos, su prioridad y cuáles forman el smoke, y trazarlos a los CA y las reglas. |
| **E5 · Automatización** | Escribir borradores de los scripts de prueba de Postman, la firma HMAC del webhook, los esquemas del contrato y el script de concurrencia. | Correr todo contra el ambiente, depurar y confirmar que las pruebas fallan solo por defectos reales del servicio. |
| **E7 · Informe** | Armar el Word de una página a partir de los resultados del E4 y redactar el resumen en inglés. | Revisar las cifras y la recomendación, y corregir el orden del informe (ver el ejemplo). |

**Regla que apliqué con la IA:** una prueba que falla por un defecto del servicio no se ajusta para que pase. Si la IA proponía cambiar una validación, primero comprobaba qué dice el contrato.

## 3. Ejemplo de algo que la IA propuso y corregí

- **Qué propuso:** en el informe del E7, la IA puso el resumen de cinco líneas en inglés para el CTO en medio del documento (después de los riesgos y antes de las aprobaciones y la recomendación).
- **Por qué no era correcto:** al revisarlo decidí que el informe debía cerrar con el resumen en inglés para el CTO. En la posición que propuso la IA, el resumen quedaba entre secciones en español y no era lo último que leía el CTO.
- **Cómo lo corregí:** pedí que el resumen en inglés fuera la última sección, después de la recomendación, sin pasar de una página. Revisé la versión final para confirmar el orden y que siguiera ocupando una página.
- **Lo que aprendí:** la IA cumple los requisitos que se le dan, pero no siempre el orden o la audiencia que pide el caso. El cierre de un informe para la gerencia lo reviso yo contra el enunciado.
