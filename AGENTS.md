# AGENTS.md — Especificación Técnica del Proyecto

Este archivo es la fuente de verdad para cualquier agente o desarrollador que trabaje en este
proyecto. Complementa a `Requisitos.md` (especificación funcional) con las decisiones técnicas,
reglas de comportamiento canónico, estilo de código y hoja de ruta resueltas al día de hoy.

---

## 1. Visión

Una **aplicación de escritorio Linux** escrita en Flutter/Dart que automatiza la limpieza tipográfica y
maquetación de manuscritos para ePubs. El proyecto fue originalmente escrito en Python (PySide6) y fue migrado a **Dart nativo** para aprovechar la compilación directa, rendimiento e interfaces modernas, dejando a Python únicamente como microservicio aislado para la lectura compleja de PDFs.

## 2. Stack

- **Lenguaje Core/GUI**: Dart / Flutter
- **Microservicio PDF**: Python 3.10+ (con `pdf2docx`)
- **Dependencia externa**: `pandoc` (DOCX y MD → HTML).
- **Distribución**: `flutter build linux` nativo.
- **Tests**: `flutter test` (suite de invariantes fuzzing trasladada íntegramente a Dart).

## 3. Arquitectura objetivo

```text
conversor-epub/
  app_flutter/                 # Proyecto Flutter (UI y Motor)
    lib/
      main.dart                # Punto de entrada de la app
      ui/
        home_screen.dart       # GUI, Drag&Drop, Diff Viewer, Tabla
      motor/                   # Núcleo puro portado a Dart
        modelo.dart            # Clases Chapter, Resultado, Nota
        limpieza.dart          # Máquina de estados canónica de comillas y regex
        notas.dart             # Extracción de marcadores
        imagenes.dart          # Procesado de figuras e imágenes
        division.dart          # Split por encabezados
        plantillas.dart        # Mapeo de capítulos especiales
        adaptadores.dart       # Wrappers de pandoc y microservicio PDF
        procesar.dart          # Orquestador central del pipeline (D6)
        render.dart            # Inyección en templates
    test/                      # Golden tests y unitarios (test_comillas.dart)
  convertidor_pdf.py           # Microservicio aislado de Python para pdf2docx
  assets/                      # Recursos estáticos
    Plantillas/                # prologo.xhtml, epilogo.xhtml, autor.xhtml
    Conv_Xhtml/                # template.xhtml
```

Reglas de arquitectura:

- **D6: El pipeline es**: adaptador → extracción de notas → limpieza → procesado de imágenes/separadores → split → render.
- Todos los modos convergen a `List<Chapter>`.
- El núcleo en Dart es puro y se ubica en `lib/motor/`. La UI maneja los efectos (guardado, diálogos).
- Las plantillas XHTML se empaquetan como assets nativos de Flutter (`rootBundle`) y el microservicio PDF de Python se encuentra embebido directamente en el binario de Dart, garantizando un bundle 100% autónomo y portable sin requerir archivos externos sueltos.

## 4. Comportamiento canónico (CRÍTICO — no cambiar sin validación)

### 4.1 Máquina de estados de comillas (D1, D2)

- Normalización previa: `“ ” « » ″` → `"`; `‘ ’ ′` → `'`.
- **D1**: TODOS los niveles de comillas dobles se escriben `«` (apertura) / `»` (cierre).
- **D2**: Las comillas simples explícitas `'` → `‘ ’`, independientes del contador de niveles.
- **Excepción a D2 (D9)**: comilla simple encadenada a doble del mismo signo o terna se vuelve anidada.
- Cortafuegos: `<p>`, `<br>`, `</div>`, etc., resetean el nivel a 0.
- Cierre automático al final del párrafo.
- Apertura tras `:`/`;`.

### 4.2 Resto del comportamiento

El comportamiento en torno a limpieza de HTML, extracción de notas al pie, resolución de plantillas, imágenes y markdown sigue idéntico a las reglas especificadas durante la era de Python. (El parser portado a Dart debe generar salida 100% equivalente byte a byte al código antiguo).

## 5. Estilo de código (Dart)

- Usar `camelCase` para variables/funciones y `PascalCase` para clases (estándar de Dart).
- Fuertemente tipado (evitar `dynamic`).
- `RegExp` definidos a nivel de archivo con prefijo `_re` (ej. `_reAtributosBasura`).
- Rutas resueltas con `package:path`.

## 6. Comandos

```bash
# Entrar al proyecto
cd app_flutter

# Modo desarrollo
flutter run -d linux

# Testing de invariantes (comillas)
flutter test

# Compilación final nativa
flutter build linux
```

## 7. Hoja de ruta (Migración a Dart)

1. **Fase 1**: Análisis y Setup. Crear rama `Dart_Migration` e inicializar Flutter app. (**Completada**)
2. **Fase 2**: Portar utilidades de archivo temporales (microservicio Python para PDFs). (**Completada**)
3. **Fase 3**: Traducción del Núcleo (Dart). Trasladar `modelo.dart`, `limpieza.dart` (máquina de estados), `notas.dart`, `adaptadores.dart` y `procesar.dart`. (**Completada**)
4. **Fase 4**: Pruebas doradas. Adaptar el fuzzing con 5000 documentos aleatorios en Dart para asegurar paridad 1:1. (**Completada**)
5. **Fase 5**: Interfaz Gráfica (Flutter). Zona Drag&Drop, badges, visor Diff y guardado con `file_picker`. (**Completada**)
6. **Fase 6**: Limpieza de Legacy. Borrar los scripts Python del núcleo y app antigua, dejando sólo el código moderno. (**Completada**)