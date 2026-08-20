# Technology Stack

## Primary Language
* **Python 3.10+**: Lenguaje base para toda la lógica de backend (motor) y frontend (GUI).

## Frontend / GUI
* **PySide6**: Framework principal elegido para construir la interfaz gráfica de usuario multiplataforma y renderizar el código HTML en el visor Diff.

## Testing & Quality Assurance
* **pytest** / **unittest**: Frameworks empleados para ejecutar los *Golden Tests* y pruebas unitarias que congelan la regresión de las reglas tipográficas.

## Core Dependencies & External Tools
* **Pandoc**: Dependencia del sistema necesaria para la lectura e ingesta inicial de manuscritos `.docx`.
* **PyInstaller**: Utilizado para empaquetar la aplicación y sus dependencias en un ejecutable *onefile*.
* **linuxdeploy**: Utilizado para la distribución final del software como una AppImage nativa para Linux.
