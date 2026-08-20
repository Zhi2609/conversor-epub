# Plan: Reestructuración de Carpetas (Chore)

## Phase 1: Reubicación de Archivos y Limpieza
- [x] Task: Eliminar carpeta `Old/`.
  - [x] Borrar el directorio `Old/` usando comandos de sistema operativo/git.
- [x] Task: Crear carpeta de recursos consolidados.
  - [x] Crear el directorio raíz `assets/`.
- [x] Task: Mover las carpetas estáticas.
  - [x] Mover `Plantillas/` dentro de `assets/`.
  - [x] Mover `Conv_Xhtml/` dentro de `assets/`.
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 2: Refactorización de Rutas en Código
- [ ] Task: Actualizar rutas relativas en el núcleo (`motor/`).
  - [ ] Buscar referencias a `"Plantillas/"` o `"Conv_Xhtml/"` en el código fuente (ej. `motor/plantillas.py`).
  - [ ] Reemplazar las cadenas por `"assets/Plantillas/"` y `"assets/Conv_Xhtml/"`.
- [ ] Task: Actualizar scripts de empaquetado.
  - [ ] Revisar `empaquetar.sh` o el script de PyInstaller.
  - [ ] Modificar el flag `--add-data` para que apunte a las nuevas rutas dentro de `assets/`.
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 3: Validación y Pruebas
- [ ] Task: Ejecutar la suite de pruebas unitarias.
  - [ ] Correr `pytest` para verificar que el auto-splitter y la carga de plantillas sigan funcionando (los golden tests deben pasar).
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 4: Sincronización de Documentación
- [ ] Task: Actualizar `AGENTS.md`.
  - [ ] Eliminar referencias a los scripts de `Old/`.
  - [ ] Actualizar el diagrama de arquitectura objetivo para mostrar `assets/`.
- [ ] Task: Actualizar `README.md`.
  - [ ] Actualizar el árbol de directorios para mostrar la nueva estructura.
- [ ] Task: Actualizar `CHANGELOG.md`.
  - [ ] Registrar la eliminación de `Old/` y el movimiento a `assets/`.
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)
