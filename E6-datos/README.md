# E6 · Validación de datos en la base – HU-410

**Autor:** Belly Espinal · **Fecha:** 2026-10-22 · **Versión:** 1

## Qué se validó y cómo

- **Base:** copia de `qa.db` tomada al terminar la corrida completa y la de concurrencia del 20-oct-2026 (`qa_completo_20261020_1925.db`). La base no se sube al repositorio (reglas del caso); se guarda en `ambiente/`.
- **Consultas:** [`consultas.sql`](consultas.sql), 16 consultas de solo lectura (SQLite).
- **Ejecución:** `python3 E6-datos/ejecutar_consultas.py ambiente/qa_completo_20261020_1925.db` abre la base en modo solo lectura, corre cada consulta y guarda la salida en [`resultados/resultados-corrida-completa.txt`](resultados/resultados-corrida-completa.txt).
- **Cómo distingo el origen:** el servicio siembra los datos del sprint anterior cada vez que arranca, con IDs del tipo `*_hNN` (`sgn_h01`, `kyc_h01`…). Lo confirmé levantando el servicio con una base nueva (`DB_PATH` temporal): trae exactamente 9 altas, 12 verificaciones, 9 códigos, 1 webhook y 2 logs, todos con ese patrón y fechas del 14 al 16 de octubre. Los registros de mi corrida tienen IDs hexadecimales y fechas desde el 21-oct UTC (el reloj del servicio se adelantó 24 h en TC-12). Cada consulta muestra la columna `origen`: `sprint_anterior` o `corrida_qa`.
- **Horas:** todas se guardan en UTC (`Z`). Guatemala es UTC-6 sin horario de verano.
- **Privacidad:** las consultas enmascaran el CUI (solo los últimos 4 dígitos), para no repetir en la evidencia el defecto D-13.

**Inventario (Q01):** 48 altas (9 del sprint anterior y 39 mías), 77 verificaciones (12 y 65) y 48 códigos (9 y 39). Ninguna hora sin UTC.

## Resultados

| # | Qué valida | Sprint anterior | Corrida QA | Interpretación |
|---|---|---|---|---|
| Q02 | Mismo CUI con más de un alta en el mismo comercio (CA-07, CA-10) | **1 duplicado:** `sgn_h03` y `sgn_h04` en M-ESTE, creadas con 1 s de diferencia | 3 grupos: 10, 10 y 2 altas del mismo CUI | El duplicado del sprint anterior tiene la forma de un doble toque o reintento. Es el mismo defecto de concurrencia que reproduje en TC-10 (**D-04**). |
| Q03 | Una verificación usada por más de un alta (CA-06, CA-10) | `kyc_h03` → 2 altas | 2 verificaciones → 10 altas cada una | Confirma D-04: la verificación no se bloquea al consumirse. |
| Q04 | Altas desde verificaciones que no estaban aprobadas (CA-06) | **2:** `sgn_h02` usa una verificación **REJECTED** (`LIVENESS_FAILED`, la selfie era una foto de pantalla) y `sgn_h07` una sin aprobación, sin selfie ni puntajes | 2: `sgn_a92752e64e33` (DOCUMENT_OK, **D-07**) y `sgn_bf9bea755ee7` | El gate del servidor no se aplicaba ya en el sprint anterior. El caso de `sgn_bf9bea755ee7` es **D-03**: un webhook devolvió a APPROVED la verificación que ya estaba consumida. |
| Q05 | Alta creada fuera de los 30 minutos desde la aprobación (CA-06, A-04) | 0 | 3: a los 31,02 min (**D-07**), a los 30,02 min y una con hora negativa | La de 31 min es el defecto ya reportado. La de 30,02 min es el caso límite de TC-07: el reloj se adelantó 30:00 y la petición tardó 1 s; el servidor no valida el vencimiento, así que queda dentro de D-07. La hora negativa es `sgn_bf9bea755ee7`: D-03 reescribió `approved_at` después del alta. |
| Q06 | La persona del alta no es la de la verificación (Regla 3, CA-04) | **1:** `sgn_h05` está a nombre de *Byron Alvarado* con una verificación de *Julio César Morales* | 2: `sgn_1191b8bbb26d` (**D-02**, persona del body) y `sgn_bf9bea755ee7` (D-03 sobrescribió la persona) | En el sprint anterior ya hay un alta a nombre de alguien que nadie verificó: es suplantación, el mismo patrón de **D-02**. Hay que escalarlo. |
| Q07 | Canal o comercio del alta distinto al configurado (Regla 3) | **1:** `sgn_h06` en M-ESTE con canal `omega` (el comercio es `alfa`) | 1: `sgn_9d6c413912bb` con canal `beta` (**D-10**) | El canal sale del body, no de la configuración. `omega` ni siquiera existe como canal en el ambiente. |
| Q08 | Aprobadas o consumidas bajo el umbral facial de 0.80 (CA-03) | **2:** `kyc_h07` con 0.74 (alta `sgn_h08`) y `kyc_h06` sin puntaje (alta `sgn_h07`) | 3: 0.72 y 0.79 (**D-06**) y una sin puntaje (D-07) | El umbral del comercio no se aplicaba y ya se dieron altas con él. |
| Q09 | Aprobadas o consumidas con el DPI vencido (CA-02) | **1:** `kyc_h05` (vencía el 2025-06-15) → alta `sgn_h06` en M-ESTE | 2 (vencimiento 2024-01-31, **D-09**) | La misma persona tiene después 4 rechazos por `DOCUMENT_EXPIRED` en M-NORTE (`kyc_h08` a `kyc_h11`), pero su alta en M-ESTE quedó creada. |
| Q10 | Aprobadas sin alguno de los 7 datos del DPI (CA-02, A-17) | 0 | 0 | Sin hallazgos. El caso sin datos (TC-04.17) terminó en error 500 (**D-16**) y no dejó registro. |
| Q11 | Coherencia de estados: rechazo con aprobación o alta, `expires_at` = aprobación + 30 min, CONSUMED con alta existente | **1:** `kyc_h02` está REJECTED pero tiene `approved_at` y un alta | 0 | Estado incoherente: la verificación se rechazó y aun así se usó (ver Q04). El resto cumple. |
| Q12 | Un código por alta, del mismo comercio, formato `INV-XXXXXX` y CONSUMED (CA-05) | **1:** `sgn_h07` tiene su código en `GENERATED`, sin consumir | 0 | El alta de `sgn_h07` no se completó: tiene un código sin consumir, que un tercero podría usar en el flujo con código (Regla 1). |
| Q13 | Más de 3 intentos por dispositivo y comercio en 24 h (CA-08) | **1:** `dev-h08` tiene 4 intentos en 6 minutos en M-NORTE | 3 dispositivos con 4 intentos | Es **D-14** (permite 4 en lugar de 3), también en el sprint anterior. |
| Q14 | CUI completo en `api_logs` (Regla 8) e imágenes con URL pública (Regla 4) | 1 de 2 logs; 12 de 12 verificaciones | 76 de 257 logs; 40 de 65 verificaciones | En total 77 de 259 logs guardan un CUI completo (**D-13**). Todas las verificaciones con imagen usan `/public/` (**D-12**). |

### Resumen del sprint anterior

De las **9 altas del sprint anterior, solo 2 están sanas** (`sgn_h01` y `sgn_h09`; que compartan el CUI en dos comercios distintos es correcto según CA-07). Las otras 7 tienen al menos un problema:

| Alta | Comercio | Problema | Defecto equivalente |
|---|---|---|---|
| `sgn_h02` | M-NORTE | Verificación rechazada por prueba de vida | D-07 |
| `sgn_h03` | M-ESTE | Su verificación se usó para otra alta | D-04 |
| `sgn_h04` | M-ESTE | Duplicado de `sgn_h03` (misma verificación, 1 s después) | D-04 |
| `sgn_h05` | M-NORTE | A nombre de otra persona | D-02 |
| `sgn_h06` | M-ESTE | DPI vencido y canal `omega` | D-09, D-10 |
| `sgn_h07` | M-NORTE | Verificación sin aprobar, sin selfie ni puntaje; código sin consumir | D-07 |
| `sgn_h08` | M-NORTE | Coincidencia facial de 0.74 | D-06 |

**Interpretación:** los defectos que encontré en la API no son teóricos: ya dejaron datos incorrectos en el sprint anterior, que nadie había validado. Antes de liberar hay que corregir o dar de baja estas altas, invalidar el código `INV-5T6Y7G` y depurar los CUI de `api_logs`.

## ¿Cuántas altas se crearon el 15 de octubre de 2026, hora de Guatemala?

**Respuesta: 2 altas**, las dos del sprint anterior.

| Alta | Comercio | Hora UTC (guardada) | Hora de Guatemala |
|---|---|---|---|
| `sgn_h08` | M-NORTE | 2026-10-15 14:05:00 | 2026-10-15 08:05:00 |
| `sgn_h09` | M-ESTE | 2026-10-16 00:02:00 | 2026-10-15 18:02:00 |

**La consulta (Q15):**

```sql
SELECT id, merchant_id, created_at AS creada_utc, datetime(created_at, '-6 hours') AS creada_guatemala
FROM signups
WHERE created_at >= '2026-10-15T06:00:00Z' AND created_at < '2026-10-16T06:00:00Z'
ORDER BY created_at;
```

**Por qué así:** `created_at` está en UTC. El 15 de octubre en Guatemala (UTC-6, sin horario de verano) va de las 06:00 del 15 a las 05:59:59 del 16 en UTC. Filtro por ese rango en UTC: el formato ISO 8601 se compara bien como texto y no hay que convertir cada fila. La columna en hora local sirve para comprobar el resultado.

**El error típico (Q16):** si se cuenta por la fecha UTC (`substr(created_at, 1, 10) = '2026-10-15'`), el resultado es **4** (`sgn_h05`, `sgn_h06`, `sgn_h07` y `sgn_h08`). Es incorrecto: las tres primeras se crearon la noche del **14** en Guatemala (19:20, 21:25 y 23:40), y se pierde `sgn_h09`, creada a las 18:02 del 15.

**Nota de calidad:** de esas 2 altas, `sgn_h08` no debió crearse (coincidencia facial de 0.74, Q08). Altas válidas ese día: 1.
