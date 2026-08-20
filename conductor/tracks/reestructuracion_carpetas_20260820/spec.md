# Specification: Reestructuración de Carpetas (Chore)

## Overview
El proyecto contiene carpetas en la raíz que ya no son necesarias o que ensucian el directorio principal (`Old/`, `Plantillas/`, `Conv_Xhtml/`). Este track tiene como objetivo eliminar el código heredado validado, consolidar los recursos estáticos en un directorio `assets/`, y sincronizar la documentación oficial para reflejar la eliminación definitiva de los scripts de la arquitectura antigua.

## Functional Requirements
1. **Eliminación de Código Legacy:**
   - Eliminar la carpeta `Old/` permanentemente.
2. **Consolidación de Recursos (Assets):**
   - Crear el directorio `assets/` en la raíz.
   - Mover las carpetas `Plantillas/` y `Conv_Xhtml/` hacia el interior de `assets/`.
3. **Actualización de Rutas del Motor:**
   - Corregir cualquier constante de ruta (ej. en `motor/plantillas.py` o dependencias) para apuntar a `assets/Plantillas/`.
   - Asegurar que PyInstaller (`empaquetar.sh`) copie `assets/` vía `--add-data`.
4. **Sincronización de Documentación:**
   - Actualizar `AGENTS.md` (eliminar referencias a la existencia de los scripts legacy en `Old/`).
   - Actualizar `README.md` (reflejar la nueva arquitectura de carpetas).
   - Registrar la reorganización estructural en `CHANGELOG.md`.

## Acceptance Criteria
- [ ] La carpeta `Old/` fue eliminada.
- [ ] La estructura de directorios en `README.md` y `AGENTS.md` ya no menciona a `Old/` e incluye la nueva carpeta `assets/`.
- [ ] Los tests (`pytest`) pasan con un 100% de éxito y el empaquetado (build) no arroja errores de rutas no encontradas.
- [ ] `CHANGELOG.md` contiene una entrada detallada sobre esta limpieza estructural.

## Out of Scope
- Refactorización de la lógica del motor de limpieza tipográfica.
