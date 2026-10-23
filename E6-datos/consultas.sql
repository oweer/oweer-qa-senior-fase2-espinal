-- E6 · Validación de datos en la base · HU-410
-- Base: copia de qa.db tomada al terminar la corrida completa + concurrencia (qa_completo_20261020_1925.db).
-- Origen de cada registro: los datos del sprint anterior los siembra el servicio al arrancar y usan IDs
-- con el patrón *_hNN (sgn_h01, kyc_h01, ...). Los generados por esta corrida usan IDs hexadecimales.
-- Todas las horas están en UTC (sufijo Z). Guatemala = UTC-6, sin horario de verano.

-- @Q01 Inventario por origen y formato de las horas
SELECT 'signups' AS tabla,
       CASE WHEN id GLOB '*_h[0-9][0-9]' THEN 'sprint_anterior' ELSE 'corrida_qa' END AS origen,
       COUNT(*) AS registros, MIN(created_at) AS desde, MAX(created_at) AS hasta,
       SUM(created_at NOT LIKE '%Z') AS horas_sin_utc
FROM signups GROUP BY origen
UNION ALL
SELECT 'kyc_checks',
       CASE WHEN id GLOB '*_h[0-9][0-9]' THEN 'sprint_anterior' ELSE 'corrida_qa' END,
       COUNT(*), MIN(created_at), MAX(created_at), SUM(created_at NOT LIKE '%Z')
FROM kyc_checks GROUP BY 2
UNION ALL
SELECT 'invitation_codes',
       CASE WHEN signup_id GLOB '*_h[0-9][0-9]' THEN 'sprint_anterior' ELSE 'corrida_qa' END,
       COUNT(*), MIN(created_at), MAX(created_at), SUM(created_at NOT LIKE '%Z')
FROM invitation_codes GROUP BY 2
ORDER BY tabla, origen;

-- @Q02 Altas duplicadas: mismo CUI en el mismo comercio (CA-07, CA-10)
SELECT CASE WHEN MIN(id) GLOB '*_h[0-9][0-9]' THEN 'sprint_anterior' ELSE 'corrida_qa' END AS origen,
       merchant_id, '*********' || substr(cui, -4) AS cui_enmascarado,
       COUNT(*) AS altas, GROUP_CONCAT(id, ', ') AS signups
FROM signups
GROUP BY merchant_id, cui
HAVING COUNT(*) > 1
ORDER BY origen DESC, altas DESC;

-- @Q03 Una verificación usada por más de un alta (CA-06, CA-10)
SELECT CASE WHEN kyc_check_id GLOB '*_h[0-9][0-9]' THEN 'sprint_anterior' ELSE 'corrida_qa' END AS origen,
       kyc_check_id, COUNT(*) AS altas, GROUP_CONCAT(id, ', ') AS signups
FROM signups
GROUP BY kyc_check_id
HAVING COUNT(*) > 1
ORDER BY origen DESC, altas DESC;

-- @Q04 Altas creadas desde una verificación que no estaba aprobada (gate del servidor, CA-06)
-- Una verificación válida para el alta tiene approved_at, puntajes del proveedor y termina en CONSUMED.
SELECT CASE WHEN s.id GLOB '*_h[0-9][0-9]' THEN 'sprint_anterior' ELSE 'corrida_qa' END AS origen,
       s.id AS signup, k.id AS verificacion, k.status, k.reject_reason,
       k.approved_at, k.face_match_score, k.liveness_score
FROM signups s JOIN kyc_checks k ON k.id = s.kyc_check_id
WHERE k.status <> 'CONSUMED' OR k.approved_at IS NULL OR k.reject_reason IS NOT NULL
   OR k.face_match_score IS NULL OR k.liveness_score IS NULL
ORDER BY origen DESC, s.created_at;

-- @Q05 Alta creada fuera de la ventana de 30 minutos de la aprobación (CA-06, A-04)
SELECT CASE WHEN s.id GLOB '*_h[0-9][0-9]' THEN 'sprint_anterior' ELSE 'corrida_qa' END AS origen,
       s.id AS signup, k.id AS verificacion, k.approved_at, k.expires_at, s.created_at AS alta_creada,
       ROUND((julianday(s.created_at) - julianday(k.approved_at)) * 1440, 2) AS minutos_desde_aprobacion
FROM signups s JOIN kyc_checks k ON k.id = s.kyc_check_id
WHERE k.approved_at IS NOT NULL
  AND (julianday(s.created_at) > julianday(k.expires_at) OR julianday(s.created_at) < julianday(k.approved_at))
ORDER BY origen DESC, s.created_at;

-- @Q06 La persona del alta no es la persona de la verificación (Regla 3, CA-04)
SELECT CASE WHEN s.id GLOB '*_h[0-9][0-9]' THEN 'sprint_anterior' ELSE 'corrida_qa' END AS origen,
       s.id AS signup, k.id AS verificacion,
       '*********' || substr(s.cui, -4) AS cui_alta, '*********' || substr(k.cui, -4) AS cui_verificacion,
       s.first_name || ' ' || s.last_name AS nombre_alta, k.first_name || ' ' || k.last_name AS nombre_verificacion
FROM signups s JOIN kyc_checks k ON k.id = s.kyc_check_id
WHERE s.cui <> k.cui OR s.first_name <> k.first_name OR s.last_name <> k.last_name
ORDER BY origen DESC, s.created_at;

-- @Q07 Comercio o canal del alta distinto al de la verificación o al configurado en el comercio (Regla 3)
SELECT CASE WHEN s.id GLOB '*_h[0-9][0-9]' THEN 'sprint_anterior' ELSE 'corrida_qa' END AS origen,
       s.id AS signup, s.merchant_id, s.channel AS canal_alta, m.channel AS canal_comercio,
       k.merchant_id AS comercio_verificacion
FROM signups s
JOIN merchants m ON m.id = s.merchant_id
JOIN kyc_checks k ON k.id = s.kyc_check_id
WHERE s.channel <> m.channel OR s.merchant_id <> k.merchant_id
ORDER BY origen DESC, s.created_at;

-- @Q08 Verificaciones aprobadas o consumidas bajo el umbral facial del comercio (CA-03)
SELECT CASE WHEN k.id GLOB '*_h[0-9][0-9]' THEN 'sprint_anterior' ELSE 'corrida_qa' END AS origen,
       k.id AS verificacion, k.merchant_id, k.status, k.face_match_score, m.face_match_threshold AS umbral,
       k.consumed_by_signup_id AS signup
FROM kyc_checks k JOIN merchants m ON m.id = k.merchant_id
WHERE k.status IN ('APPROVED', 'CONSUMED', 'EXPIRED') AND m.face_match_required = 1
  AND (k.face_match_score IS NULL OR k.face_match_score < m.face_match_threshold)
ORDER BY origen DESC, k.created_at;

-- @Q09 Verificaciones aprobadas o consumidas con el DPI vencido al momento de aprobar (CA-02)
SELECT CASE WHEN k.id GLOB '*_h[0-9][0-9]' THEN 'sprint_anterior' ELSE 'corrida_qa' END AS origen,
       k.id AS verificacion, k.merchant_id, k.status, k.document_expiry,
       COALESCE(k.approved_at, k.updated_at) AS aprobada, k.consumed_by_signup_id AS signup
FROM kyc_checks k
WHERE k.status IN ('APPROVED', 'CONSUMED', 'EXPIRED')
  AND k.document_expiry < date(COALESCE(k.approved_at, k.updated_at), '-6 hours')
ORDER BY origen DESC, k.created_at;

-- @Q10 Verificaciones aprobadas o consumidas sin alguno de los 7 datos del DPI (CA-02, A-17)
SELECT CASE WHEN id GLOB '*_h[0-9][0-9]' THEN 'sprint_anterior' ELSE 'corrida_qa' END AS origen,
       id AS verificacion, status,
       TRIM((CASE WHEN cui IS NULL THEN 'cui ' ELSE '' END) ||
            (CASE WHEN first_name IS NULL THEN 'first_name ' ELSE '' END) ||
            (CASE WHEN last_name IS NULL THEN 'last_name ' ELSE '' END) ||
            (CASE WHEN birth_date IS NULL THEN 'birth_date ' ELSE '' END) ||
            (CASE WHEN document_expiry IS NULL THEN 'document_expiry ' ELSE '' END) ||
            (CASE WHEN gender IS NULL THEN 'gender ' ELSE '' END) ||
            (CASE WHEN nationality IS NULL THEN 'nationality' ELSE '' END)) AS faltan
FROM kyc_checks
WHERE status IN ('APPROVED', 'CONSUMED', 'EXPIRED')
  AND (cui IS NULL OR first_name IS NULL OR last_name IS NULL OR birth_date IS NULL
       OR document_expiry IS NULL OR gender IS NULL OR nationality IS NULL)
ORDER BY origen DESC, created_at;

-- @Q11 Coherencia de estados y vencimiento (tabla de estados, A-04)
-- a) expires_at debe ser approved_at + 30 min; b) un rechazo no debe tener approved_at ni alta;
-- c) CONSUMED debe apuntar a un alta que exista (en una reutilización, CA-07, es el alta existente del mismo CUI).
SELECT CASE WHEN k.id GLOB '*_h[0-9][0-9]' THEN 'sprint_anterior' ELSE 'corrida_qa' END AS origen,
       k.id AS verificacion, k.status, k.approved_at, k.expires_at, k.consumed_by_signup_id,
       CASE
         WHEN k.status = 'REJECTED' AND (k.approved_at IS NOT NULL OR k.consumed_by_signup_id IS NOT NULL)
           THEN 'rechazada con aprobación o alta'
         WHEN k.approved_at IS NOT NULL
              AND ROUND((julianday(k.expires_at) - julianday(k.approved_at)) * 1440) <> 30
           THEN 'expires_at distinto de aprobación + 30 min'
         WHEN k.status = 'CONSUMED' AND s.id IS NULL
           THEN 'CONSUMED sin alta existente'
       END AS problema
FROM kyc_checks k
LEFT JOIN signups s ON s.id = k.consumed_by_signup_id
WHERE (k.status = 'REJECTED' AND (k.approved_at IS NOT NULL OR k.consumed_by_signup_id IS NOT NULL))
   OR (k.approved_at IS NOT NULL AND ROUND((julianday(k.expires_at) - julianday(k.approved_at)) * 1440) <> 30)
   OR (k.status = 'CONSUMED' AND s.id IS NULL)
ORDER BY origen DESC, k.created_at;

-- @Q12 Códigos de invitación: uno por alta, del mismo comercio, con formato INV-XXXXXX y CONSUMED (CA-05)
SELECT CASE WHEN s.id GLOB '*_h[0-9][0-9]' THEN 'sprint_anterior' ELSE 'corrida_qa' END AS origen,
       s.id AS signup, COUNT(c.code) AS codigos, GROUP_CONCAT(c.code) AS code,
       GROUP_CONCAT(c.status) AS estado, GROUP_CONCAT(c.merchant_id) AS comercio_codigo, s.merchant_id
FROM signups s LEFT JOIN invitation_codes c ON c.signup_id = s.id
GROUP BY s.id
HAVING COUNT(c.code) <> 1
    OR SUM(c.status <> 'CONSUMED' OR c.consumed_at IS NULL) > 0
    OR SUM(c.merchant_id <> s.merchant_id) > 0
    OR SUM(c.code NOT GLOB 'INV-[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]') > 0
ORDER BY origen DESC, s.created_at;

-- @Q13 Más de 3 intentos por dispositivo y comercio en 24 horas (CA-08; las canceladas no cuentan, A-16)
SELECT CASE WHEN a.id GLOB '*_h[0-9][0-9]' THEN 'sprint_anterior' ELSE 'corrida_qa' END AS origen,
       a.merchant_id, a.device_id, a.id AS sesion, a.created_at,
       COUNT(b.id) AS intentos_en_24h_hasta_esta, m.max_attempts
FROM kyc_checks a
JOIN kyc_checks b ON b.merchant_id = a.merchant_id AND b.device_id = a.device_id
                 AND b.status <> 'CANCELLED'
                 AND julianday(b.created_at) BETWEEN julianday(a.created_at) - 1 AND julianday(a.created_at)
JOIN merchants m ON m.id = a.merchant_id
WHERE a.status <> 'CANCELLED'
GROUP BY a.id
HAVING COUNT(b.id) > m.max_attempts
ORDER BY origen DESC, a.created_at;

-- @Q14 Datos personales expuestos: CUI completo en api_logs (Regla 8) e imágenes con URL pública (Regla 4)
SELECT 'api_logs con CUI de 13 dígitos' AS hallazgo,
       CASE WHEN ts < '2026-10-20' THEN 'sprint_anterior' ELSE 'corrida_qa' END AS origen,
       COUNT(*) AS registros
FROM api_logs
WHERE body GLOB '*[^0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][^0-9]*'
GROUP BY origen
UNION ALL
SELECT 'api_logs total', CASE WHEN ts < '2026-10-20' THEN 'sprint_anterior' ELSE 'corrida_qa' END, COUNT(*)
FROM api_logs GROUP BY 2
UNION ALL
SELECT 'verificaciones con imagen en /public/',
       CASE WHEN id GLOB '*_h[0-9][0-9]' THEN 'sprint_anterior' ELSE 'corrida_qa' END, COUNT(*)
FROM kyc_checks
WHERE document_front_url LIKE '%/public/%' OR document_back_url LIKE '%/public/%' OR selfie_url LIKE '%/public/%'
GROUP BY 2
ORDER BY hallazgo, origen DESC;

-- @Q15 ¿Cuántas altas se crearon el 15 de octubre de 2026, hora de Guatemala (UTC-6)?
-- created_at está en UTC. El 15-oct en Guatemala va de 2026-10-15T06:00:00Z a 2026-10-16T05:59:59Z.
-- Se compara el rango en UTC (ISO 8601 se ordena bien como texto) y se muestra la hora local para comprobar.
SELECT CASE WHEN id GLOB '*_h[0-9][0-9]' THEN 'sprint_anterior' ELSE 'corrida_qa' END AS origen,
       id AS signup, merchant_id, created_at AS creada_utc,
       datetime(created_at, '-6 hours') AS creada_guatemala
FROM signups
WHERE created_at >= '2026-10-15T06:00:00Z' AND created_at < '2026-10-16T06:00:00Z'
ORDER BY created_at;

-- @Q16 Contraste: el mismo conteo con la fecha en UTC (el error típico)
SELECT 'fecha UTC = 2026-10-15' AS criterio, COUNT(*) AS altas, GROUP_CONCAT(id, ', ') AS signups
FROM signups WHERE substr(created_at, 1, 10) = '2026-10-15'
UNION ALL
SELECT 'fecha Guatemala = 2026-10-15', COUNT(*), GROUP_CONCAT(id, ', ')
FROM signups WHERE date(created_at, '-6 hours') = '2026-10-15';
