# Plan: Reestructuración de Carpetas (Chore)

## Phase 1: Reubicación de Archivos y Limpieza
- [x] Task: Eliminar carpeta `Old/`.
  - [x] Borrar el directorio `Old/` usando comandos de sistema operativo/git.
- [x] Task: Crear carpeta de recursos consolidados.
  - [x] Crear el directorio raíz `assets/`.
- [x] Task: Mover las carpetas estáticas.
  - [x] Mover `Plantillas/` dentro de `assets/`.
  - [x] Mover `Conv_Xhtml/` dentro de `assets/`.
- [x] Task: Phase Verification - [x] Task: Phase Verification & Checkpoint [checkpoint: 1cc0e53] Checkpoint [checkpoint: 8ef63d4]

## Phase 2: Refactorización de Rutas en Código
- [x] Task: Actualizar rutas relativas en el núcleo (`motor/`).
  - [x] Buscar referencias a `"Plantillas/"` o `"Conv_Xhtml/"` en el código fuente (ej. `motor/plantillas.py`).
  - [x] Reemplazar las cadenas por `"assets/Plantillas/"` y `"assets/Conv_Xhtml/"`.
- [x] Task: Actualizar scripts de empaquetado.
  - [x] Revisar `empaquetar.sh` o el script de PyInstaller.
  - [x] Modificar el flag `--add-data` para que apunte a las nuevas rutas dentro de `assets/`.
- [x] Task: Phase Verification - [x] Task: Phase Verification & Checkpoint [checkpoint: 86497cc] Checkpoint [checkpoint: 8ef63d4]

## Phase 3: Validación y Pruebas
- [x] Task: Ejecutar la suite de pruebas unitarias.
  - [x] Correr `pytest` para verificar que el auto-splitter y la carga de plantillas sigan funcionando (los golden tests deben pasar).
- [x] Task: Phase Verification - [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md) Checkpoint [checkpoint: 8ef63d4]

## Phase 4: Sincronización de Documentación
- [ ] Task: Actualizar `AGENTS.md`.
  - [ ] Eliminar referencias a los scripts de `Old/`.
  - [ ] Actualizar el diagrama de arquitectura objetivo para mostrar `assets/`.
- [ ] Task: Actualizar `README.md`.
  - [ ] Actualizar el árbol de directorios para mostrar la nueva estructura.
- [ ] Task: Actualizar `CHANGELOG.md`.
  - [ ] Registrar la eliminación de `Old/` y el movimiento a `assets/`.
- [x] Task: Phase Verification - [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md) Checkpoint [checkpoint: 8ef63d4]
