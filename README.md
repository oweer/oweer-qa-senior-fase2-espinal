# QA Senior · Fase 2 · HU-410 — Belly Espinal

Caso práctico de QA Senior: **alta de comercios sin código de invitación, con verificación de identidad** (HU-410). El servicio se probó como caja negra, por su API y su base de datos, contra el contrato `openapi.yaml` v1.1.0.

| | |
|---|---|
| **Autor** | Belly Espinal · QA Senior |
| **Contacto** | belly.espinal17@gmail.com |
| **Ejecución** | 20 de octubre de 2026 (hora de Guatemala), ambiente de QA local |
| **Recomendación** | **NO-GO** (ver [E7](E7-informe/E7-Informe-HU-410.docx)) |
| **Video** | https://we.tl/t-vYuouaV8Qm63Wj2U |

## Resultado en una línea

De 18 casos de API ejecutados pasan 3, y del smoke de liberación pasa 1 de 6. Hay **19 defectos abiertos (5 críticos, 8 altos, 4 medios, 2 bajos)**, y la base muestra que 7 de las 9 altas del sprint anterior ya tienen datos incorrectos por esos mismos defectos.

| Métrica | Resultado |
|---|---|
| Casos diseñados (E3) | 25: 19 de API y 6 de app móvil |
| Casos de API ejecutados | 18 de 19 (TC-19 no es ejecutable: el contrato no expone el flujo con código) |
| Casos de API que pasan | 3 de 18 (TC-08, TC-09, TC-13) |
| Smoke de liberación | 1 de 6 casos pasa · 44 peticiones · 15 de 108 validaciones fallan |
| Corrida completa (Newman) | 196 peticiones · 432 validaciones · 45 fallan, todas por el servicio |
| Concurrencia (TC-10) | 6 de 7 validaciones fallan |
| Validación en la base (E6) | 16 consultas; 7 de 9 altas del sprint anterior con problemas |
| Altas del 15-oct-2026, hora de Guatemala | **2** (`sgn_h08` y `sgn_h09`) |

## Entregables

| # | Entregable | Archivo |
|---|---|---|
| E1 | Análisis del requerimiento: 17 ambigüedades, contradicciones y vacíos, ordenados por riesgo, con preguntas al PO | [E1-Analisis-HU-410.docx](E1-analisis/E1-Analisis-HU-410.docx) |
| E2 | Estrategia de pruebas basada en riesgo (1 página) | [E2-Estrategia-HU-410.docx](E2-estrategia/E2-Estrategia-HU-410.docx) |
| E3 | Matriz de casos trazable a CA y reglas, con técnica, prioridad y smoke marcado | [E3-Casos-HU-410.xlsx](E3-casos/E3-Casos-HU-410.xlsx) |
| E4 | Ejecución y reporte de defectos (8 completos + tabla) y evidencia | [E4-Defectos-HU-410.docx](E4-defectos/E4-Defectos-HU-410.docx) · [resultados/](E4-defectos/resultados/) · [evidencias/](E4-defectos/evidencias/) |
| E5 | Automatización: colección Postman/Newman y script de concurrencia en Node | [E5-automatizacion/](E5-automatizacion/) · [README](E5-automatizacion/postman/README.md) |
| E6 | Validación de datos en la base: consultas SQL, resultados e interpretación | [E6-datos/README.md](E6-datos/README.md) · [consultas.sql](E6-datos/consultas.sql) |
| E7 | Informe de calidad y recomendación para PO/CTO (1 página, resumen en inglés) | [E7-Informe-HU-410.docx](E7-informe/E7-Informe-HU-410.docx) |
| E8 | Bitácora de herramientas y uso de IA | [E8-herramientas/README.md](E8-herramientas/README.md) |
| E9 | Video del QA | [E9-video.md](E9-video.md) |

## Cómo correr la prueba desde cero

### Requisitos

- **Node.js 22.13 o superior** (el servicio y el script de concurrencia no tienen dependencias).
- **Newman** y el reporte HTML, una sola vez:
  ```bash
  npm install -g newman newman-reporter-htmlextra
  ```
- **Python 3** (solo para el E6).
- El paquete del ambiente del caso copiado en `ambiente/` (`server.mjs`, `openapi.yaml`). No está en el repositorio por las reglas del caso.

### 1. Levantar el servicio con la base recién reiniciada

```bash
cd ambiente
node server.mjs          # http://localhost:4010
```

Al arrancar, el servicio borra y recrea la base con los datos del sprint anterior. La colección también reinicia la base y el reloj en su primera carpeta (`00 · Preparación`, que llama a `POST /v1/_sandbox/reset`), así que cada corrida empieza limpia. Deja el servicio corriendo y abre otra terminal en la raíz del repositorio.

### 2. Smoke de liberación (por separado)

```bash
newman run E5-automatizacion/postman/HU-410.postman_collection.json \
  -e E5-automatizacion/postman/HU-410-QA-local.postman_environment.json \
  --folder "00 · Preparación" --folder "Smoke" \
  -r cli,htmlextra --reporter-htmlextra-export E4-defectos/resultados/newman-smoke.html
```

Corre 6 casos: TC-01, TC-02, TC-03, TC-06, TC-09 y TC-15.

### 3. Corrida completa (smoke + regresión)

```bash
newman run E5-automatizacion/postman/HU-410.postman_collection.json \
  -e E5-automatizacion/postman/HU-410-QA-local.postman_environment.json \
  -r cli,htmlextra --reporter-htmlextra-export E4-defectos/resultados/newman-completo.html
```

TC-07 y TC-12 van al final porque adelantan el reloj del servicio (31 minutos y 24 horas).

### 4. Concurrencia (TC-10)

Newman ejecuta en secuencia, así que la concurrencia va en un script que dispara las solicitudes en paralelo:

```bash
node E5-automatizacion/concurrencia/concurrencia.mjs | tee E4-defectos/resultados/concurrencia.txt
```

Variables opcionales: `BASE_URL` (por defecto `http://localhost:4010`) y `N` (solicitudes simultáneas, por defecto 10).

### 5. Validación de la base (E6)

Antes de reiniciar el servicio, copia la base, porque al arrancar se borra:

```bash
cp ambiente/qa.db ambiente/qa_completo_$(date +%Y%m%d_%H%M).db
python3 E6-datos/ejecutar_consultas.py ambiente/qa_completo_<fecha>.db
```

El script abre la base en modo solo lectura, corre las 16 consultas de `E6-datos/consultas.sql` y guarda la salida en `E6-datos/resultados/`.

### Qué esperar

**Las pruebas fallan, y es lo esperado.** Cada falla corresponde a un defecto real del servicio, documentado en el E4. Las validaciones no se ajustaron para que pasen. Si el servicio se corrige, la misma suite sirve como regresión: el criterio para liberar es smoke 6/6, concurrencia 7/7 y ningún defecto crítico ni alto abierto.

## Decisión

**NO-GO.** Hay defectos críticos en las cuatro áreas que la estrategia define como bloqueantes:

- **Aprobación de identidad:** webhooks sin firma aprueban verificaciones (D-01).
- **Gate del alta:** se crean altas con datos de otra persona (D-02) y duplicadas en paralelo (D-04).
- **Aislamiento entre comercios:** un comercio lee datos personales de otro (D-05).
- **Privacidad:** el CUI completo aparece en mensajes y en logs (D-08, D-13).

Las condiciones para volver a evaluar están en el [E7](E7-informe/E7-Informe-HU-410.docx).

