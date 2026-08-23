# Diseño: Notas `[^1]` e imágenes `[Imagen X]` en modo Markdown

**Fecha:** 2026-08-22
**Estado:** Aprobado por el usuario

## Objetivo

El modo Markdown actualmente no soporta notas al pie ni reconoce `[Imagen X]`
(mixto). Se añaden ambos reutilizando la lógica existente del motor:

1. **Imágenes**: `[Imagen X]` en cualquier combinación de mayúsculas/minúsculas,
   procesada por `motor/imagenes.py` igual que en modo Word.
2. **Notas**: sintaxis markdown estándar `[^N]` (llamada) + `[^N]: contenido`
   (definición al pie del archivo), procesada por `motor/notas.py`, con salida
   idéntica al modo Word: llamadas enlazadas en el capítulo y contenido en
   `notas_Finales.xhtml` con backlinks.

## Decisión clave

NO tocar el adaptador markdown para notas. Extender `extraer_notas()` en
`motor/notas.py` con dos regex nuevos (junto a los existentes de pandoc y
legacy `(NT##)`). Así los 3 modos comparten el mismo pipeline de notas
(limpieza, imágenes en notas, backlinks, render) sin duplicar código.

## Cambio 1 — Imágenes case-insensitive (`motor/imagenes.py`)

Añadir `re.IGNORECASE` a `RE_IMAGEN_TAG_P` y `RE_IMAGEN_TAG`. Con esto
`[Imagen 1]`, `[IMAGEN 1]`, `[imagen 1]` funcionan en todos los modos.

No hace falta tocar el adaptador: `_md_a_html` no altera `[Imagen N]`,
`_parrafos_a_html` lo envuelve en `<p>[Imagen N]</p>`, la limpieza no lo
molesta, y `procesar_imagenes()` (paso 4 del pipeline) ya lo captura.

## Cambio 2 — Notas markdown (`motor/notas.py`)

Nuevos regex:

```python
RE_NOTA_MD_DEF = re.compile(r'<p>\s*\[\^(\d+)\]:\s*(.*?)</p>', re.DOTALL)
RE_NOTA_MD_LLAMADA = re.compile(r'\[\^(\d+)\]')
```

En `extraer_notas()`, tras el bloque pandoc y antes del legacy:

1. Buscar definiciones `<p>[^N]: contenido</p>` → crear
   `Nota(num=N, texto=limpiar_texto_html(contenido))` y eliminar el párrafo.
2. Reemplazar llamadas `[^N]` → `formatear_llamada(N)`.

### Por qué funciona sin tocar el adaptador

Cuando `extraer_notas()` corre (primer paso de `_procesar_documento`,
ANTES de la limpieza — D6), las definiciones ya fueron envueltas en `<p>`
por `_parrafos_a_html`, que además une líneas internas con espacios
(definiciones multilínea quedan en un solo `<p>`). `[^N]` no contiene
`_`/`*`/`\`, así que `_md_a_html` y la máquina de comillas no lo alteran.

### Formato de entrada (lo que escribe la autora)

```markdown
# Capítulo 1

Era de noche[^1] cuando llegó.

[^1]: La luna salía sobre el puerto.
```

### Salida (idéntica al modo Word)

Capítulo (`C01.xhtml`):

```html
<p>Era de noche<a href="notas_Finales.xhtml#nt01" id="rf01"><sup>❮01❯</sup></a> cuando llegó.</p>
```

`notas_Finales.xhtml` (vía `formatear_nota`, backlink asignado por
`asignar_capitulos` tras el split):

```html
<div class="nota">
 <p id="nt01">
   <a href="C01.xhtml#rf01"><sup>❮01❯</sup> La luna salía sobre el puerto.</a>
 </p>
</div>
```

## Limitaciones aceptadas

- Llamada sin definición → llamada huérfana, sin aviso (posterior si hace falta).
- Imágenes dentro de definiciones markdown (`[^1]: !\Image1\ …`) no funcionan:
  los placeholders `\x00IMG_x\x00` se restauran después de extraer notas.
  Las notas de Word sí soportan imágenes.
- Numeración: se usa el número literal entre corchetes (igual que legacy `(NT##)`).

## Registro canónico

Este comportamiento debe registrarse en AGENTS.md §5.5 (soporte de notas
markdown `[^N]`) y §5.6 (`[IMAGEN N]` case-insensitive) ANTES de implementarse.

## Tests

- Caso golden: capítulo .md con 2 notas (una multilínea) → salida esperada.
- Caso golden: `[Imagen 2]` mixto en .md → figure con `../Images/02.jpg`.
- Caso límite: llamada sin definición; definición sin llamada (default C01).
- Verificar que los golden tests existentes de word/calibre no cambian.
