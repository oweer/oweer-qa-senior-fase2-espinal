#!/usr/bin/env python3
"""Ejecuta consultas.sql contra una copia de qa.db en modo solo lectura y guarda los resultados.
Uso: python3 E6-datos/ejecutar_consultas.py <ruta a la copia de qa.db> [archivo de salida]"""
import re, sqlite3, sys
from pathlib import Path

db = sys.argv[1]
out = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).with_name('resultados') / 'resultados.txt'
sql = Path(__file__).with_name('consultas.sql').read_text(encoding='utf-8')
con = sqlite3.connect(f'file:{db}?mode=ro', uri=True)
lines = [f'Base: {Path(db).name}', '']
for block in re.split(r'^-- @', sql, flags=re.M)[1:]:
    title = block.splitlines()[0]
    cur = con.execute(block.split('\n', 1)[1])
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    lines += [f'== {title}', ' | '.join(cols)]
    lines += [' | '.join('' if v is None else str(v) for v in r) for r in rows] or ['(sin filas)']
    lines += [f'-- {len(rows)} fila(s)', '']
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text('\n'.join(lines), encoding='utf-8')
print('\n'.join(lines))
