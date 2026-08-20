# ConversorEpub

## Vision
Una aplicación de escritorio nativa para Linux construida con Python y PySide6. Actúa como un motor centralizado que automatiza la limpieza tipográfica (máquina de estados para comillas, limpieza de basura HTML) y la maquetación de manuscritos provenientes de formatos DOCX, Markdown y XHTML de Calibre. Su objetivo es generar capítulos perfectamente estructurados y listos para ser ensamblados en un ePub.

## Core Features
*   **Adaptadores de Entrada Universales:** Soporte automático para Word (.docx vía pandoc), Calibre (XHTML) y Markdown (.md).
*   **Motor de Limpieza Tipográfica Canónica:** Máquina de estados para control de niveles de comillas (D1, D2), alineación de etiquetas y limpieza exhaustiva de basura HTML heredada.
*   **Procesamiento Avanzado:** Extracción, formateo y enlazado bidireccional de notas al pie, y soporte nativo para placeholders de imágenes y separadores de escenas.
*   **Auto-Splitter:** División automática de capítulos por encabezados (`<h1>`, `<h2>`, `<h3>`), incluyendo un sistema de plantillas independiente para capítulos especiales sin numeración (Prólogo, Epílogo, Palabras del autor).
*   **Interfaz Gráfica de Usuario (GUI):** Ventana con zona de arrastrar y soltar (Drag & Drop), dashboard de métricas en tiempo real, tabla validada de capítulos y un visor de diferencias (Diff) del código, todo bajo un tema oscuro moderno inspirado en Catppuccin.

## Target Audience
Escritores, editores y maquetadores de libros digitales que buscan estandarizar y limpiar manuscritos rápidamente en entornos Linux antes de ensamblarlos en editores como Sigil, asegurando una pureza de código absoluto.
