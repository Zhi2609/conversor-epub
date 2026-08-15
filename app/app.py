"""Aplicación de escritorio (PySide6): selector universal, dashboard, tabla
de títulos con validación de conteo y visor Diff antes/después."""

import sys
from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QApplication,
    QComboBox,
    QFileDialog,
    QFrame,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QSplitter,
    QTableWidget,
    QTableWidgetItem,
    QTextBrowser,
    QVBoxLayout,
    QWidget,
)

from motor import detectar_modo, procesar, ruta_plantillas_empaquetado, ruta_template_empaquetado
from motor.plantillas import numero_de_archivo
from motor.render import (
    limpiar_carpeta,
    render_capitulo,
    render_capitulo_especial,
    render_notas,
)

RUTA_RAIZ = Path(__file__).resolve().parent.parent
RUTA_TEMPLATE_DEFECTO = ruta_template_empaquetado()
RUTA_SALIDA_DEFECTO = RUTA_RAIZ / 'Capitulos'
RUTA_PLANTILLAS_DEFECTO = ruta_plantillas_empaquetado()

ETIQUETA_MODOS = {'word': 'Modo Word', 'calibre': 'Modo Calibre', 'markdown': 'Modo Markdown'}


class ZonaEntrada(QFrame):
    """Área de Drag & Drop para el archivo .docx o la carpeta de trabajo."""

    def __init__(self, al_aceptar):
        super().__init__()
        self.al_aceptar = al_aceptar
        self.setAcceptDrops(True)
        self.setFrameShape(QFrame.StyledPanel)
        self.setMinimumHeight(90)
        texto = QLabel('Arrastra aquí tu .docx o tu carpeta (.md / .xhtml / .html)\no pulsa el botón de exploración')
        boton = QPushButton('Explorar...')
        boton.clicked.connect(self._explorar)
        layout = QVBoxLayout(self)
        layout.addWidget(texto, alignment=Qt.AlignCenter)
        layout.addWidget(boton, alignment=Qt.AlignCenter)

    def dragEnterEvent(self, evento):
        if evento.mimeData().hasUrls():
            evento.acceptProposedAction()

    def dropEvent(self, evento):
        if evento.mimeData().hasUrls():
            ruta = Path(evento.mimeData().urls()[0].toLocalFile())
            self.al_aceptar(ruta)

    def _explorar(self):
        ruta, _ = QFileDialog.getOpenFileName(
            self, 'Selecciona un .docx', str(Path.home()), 'Word (*.docx)',
            options=QFileDialog.Option.DontUseNativeDialog,
        )
        if ruta:
            self.al_aceptar(Path(ruta))


class VentanaPrincipal(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle('Conversor ePub — Limpieza y Maquetación')
        self.resize(1100, 720)
        self._resultado = None
        self._documentos_raw: list[str] = []
        self._ruta_entrada: Path | None = None
        self._construir_ui()

    def _construir_ui(self):
        central = QWidget()
        layout = QVBoxLayout(central)

        self.zona_entrada = ZonaEntrada(self._aceptar_entrada)
        self.etiqueta_modo = QLabel('Sin archivo cargado')
        self.etiqueta_modo.setStyleSheet('font-weight: bold; color: #555;')
        layout.addWidget(self.zona_entrada)
        layout.addWidget(self.etiqueta_modo)

        self.etiqueta_conteos = QLabel('📄 Capítulos: —   📝 Notas: —   🖼️ Imágenes: —   ✂️ Separadores: —')
        layout.addWidget(self.etiqueta_conteos)

        self.etiqueta_avisos = QLabel('')
        self.etiqueta_avisos.setStyleSheet('color: #b9770e;')
        self.etiqueta_avisos.setWordWrap(True)
        self.etiqueta_avisos.hide()
        layout.addWidget(self.etiqueta_avisos)

        self.tabla = QTableWidget(0, 2)
        self.tabla.setHorizontalHeaderLabels(['Nº', 'Título del capítulo'])
        self.tabla.horizontalHeader().setStretchLastSection(True)
        self.tabla.cellChanged.connect(self._validar_conteo)
        filas = QHBoxLayout()
        boton_anadir = QPushButton('＋ Añadir fila')
        boton_quitar = QPushButton('－ Eliminar fila')
        boton_anadir.clicked.connect(self._anadir_fila)
        boton_quitar.clicked.connect(self._quitar_fila)
        filas.addWidget(boton_anadir)
        filas.addWidget(boton_quitar)
        filas.addStretch()
        layout.addWidget(self.tabla)
        layout.addLayout(filas)

        self.etiqueta_validacion = QLabel('')
        self.etiqueta_validacion.setStyleSheet('color: #c0392b; font-weight: bold;')
        layout.addWidget(self.etiqueta_validacion)

        diff = QSplitter(Qt.Horizontal)
        self.selector_capitulo = QComboBox()
        self.original = QTextBrowser()
        self.limpio = QTextBrowser()
        self.original.setHtml('<i>— HTML original —</i>')
        self.limpio.setHtml('<i>— HTML limpio —</i>')
        panel_original = QWidget()
        l1 = QVBoxLayout(panel_original)
        l1.addWidget(QLabel('📄 Original'))
        l1.addWidget(self.original)
        panel_limpio = QWidget()
        l2 = QVBoxLayout(panel_limpio)
        l2.addWidget(QLabel('✨ Limpio'))
        l2.addWidget(self.limpio)
        diff.addWidget(panel_original)
        diff.addWidget(panel_limpio)
        layout.addWidget(self.selector_capitulo)
        layout.addWidget(diff, stretch=1)

        generacion = QHBoxLayout()
        generacion.addWidget(QLabel('Template:'))
        self.campo_template = QLineEdit(str(RUTA_TEMPLATE_DEFECTO))
        generacion.addWidget(self.campo_template, stretch=1)
        boton_generar = QPushButton('Generar Archivos')
        boton_generar.clicked.connect(self._generar)
        self.boton_generar = boton_generar
        generacion.addWidget(boton_generar)
        layout.addLayout(generacion)

        self.setCentralWidget(central)
        self._validar_conteo()

    def _aceptar_entrada(self, ruta: Path):
        if not ruta.exists():
            self._mostrar_error('No se encuentra la entrada.')
            return
        try:
            modo = detectar_modo(ruta)
        except ValueError as error:
            self._mostrar_error(str(error))
            return

        self._ruta_entrada = ruta
        self.etiqueta_modo.setText(f'🔄 Procesando… ({ETIQUETA_MODOS[modo]})')
        QApplication.processEvents()
        try:
            self._resultado = procesar(
                modo,
                ruta,
                Path(self.campo_template.text()),
                ruta_plantillas=(
                    RUTA_PLANTILLAS_DEFECTO
                    if RUTA_PLANTILLAS_DEFECTO.is_dir()
                    else None
                ),
            )
            self._documentos_raw = []
            if modo == 'word':
                from motor.adaptadores.docx import convertir_docx
                self._documentos_raw = [convertir_docx(ruta)] * len(self._resultado.capitulos)
            elif modo == 'calibre':
                from motor.adaptadores.calibre import extraer_cuerpo
                self._documentos_raw = [
                    extraer_cuerpo(archivo.read_text(encoding='utf-8'))[0]
                    for archivo in sorted(ruta.glob('*.xhtml')) + sorted(ruta.glob('*.html'))
                ]
            else:
                from motor.adaptadores.markdown import _limpiar_invisibles, _md_a_html
                for archivo in sorted(ruta.glob('*.md')):
                    texto = archivo.read_text(encoding='utf-8')
                    self._documentos_raw.append(_md_a_html(_limpiar_invisibles(texto)))
            self._documentos_raw += [self._documentos_raw[-1]] * (len(self._resultado.capitulos) - len(self._documentos_raw))
        except (ValueError, RuntimeError) as error:
            self._mostrar_error(str(error))
            QMessageBox.warning(self, 'Error al procesar', str(error))
            return

        self.etiqueta_modo.setText(f'✅ {ETIQUETA_MODOS[modo]} — {ruta.name}')
        contadores = self._resultado.contadores
        self.etiqueta_conteos.setText(
            f'📄 Capítulos: {contadores.capitulos}   '
            f'📝 Notas: {contadores.notas}   '
            f'🖼️ Imágenes: {contadores.imagenes}   '
            f'✂️ Separadores: {contadores.separadores}'
        )
        if self._resultado.avisos:
            self.etiqueta_avisos.setText('⚠️ ' + '; '.join(self._resultado.avisos))
            self.etiqueta_avisos.show()
        else:
            self.etiqueta_avisos.hide()
        self._poblar_tabla()
        self.selector_capitulo.clear()
        for num, capitulo in enumerate(self._resultado.capitulos, start=1):
            self.selector_capitulo.addItem(f'Capítulo {num:02d} — {capitulo.titulo}')
        self.selector_capitulo.currentIndexChanged.connect(self._mostrar_diff)
        self._mostrar_diff()
        self._validar_conteo()

    def _poblar_tabla(self):
        self.tabla.cellChanged.disconnect()
        self.tabla.setRowCount(len(self._resultado.capitulos))
        for fila, capitulo in enumerate(self._resultado.capitulos):
            self.tabla.setItem(fila, 0, QTableWidgetItem(f'{fila + 1}'))
            self.tabla.setItem(fila, 1, QTableWidgetItem(capitulo.titulo))
        self.tabla.cellChanged.connect(self._validar_conteo)

    def _titulos_de_tabla(self) -> list[str]:
        return [
            (self.tabla.item(fila, 1).text() if self.tabla.item(fila, 1) else '')
            for fila in range(self.tabla.rowCount())
        ]

    def _anadir_fila(self):
        self.tabla.cellChanged.disconnect()
        self.tabla.insertRow(self.tabla.rowCount())
        self.tabla.setItem(self.tabla.rowCount() - 1, 0, QTableWidgetItem(f'{self.tabla.rowCount()}'))
        self.tabla.setItem(self.tabla.rowCount() - 1, 1, QTableWidgetItem(''))
        self.tabla.cellChanged.connect(self._validar_conteo)
        self._validar_conteo()

    def _quitar_fila(self):
        fila = self.tabla.currentRow()
        if fila < 0:
            return
        self.tabla.cellChanged.disconnect()
        self.tabla.removeRow(fila)
        self.tabla.cellChanged.connect(self._validar_conteo)
        self._validar_conteo()

    def _validar_conteo(self):
        if self._resultado is None:
            self.etiqueta_validacion.setText('')
            self.boton_generar.setEnabled(False)
            return
        esperados = len(self._resultado.capitulos)
        actuales = self.tabla.rowCount()
        if esperados == actuales:
            vacios = sum(1 for titulo in self._titulos_de_tabla() if not titulo.strip())
            if vacios:
                self._mostrar_error(f'Títulos: {actuales - vacios}/{esperados} — hay {vacios} título(s) vacío(s)')
                self.boton_generar.setEnabled(False)
            else:
                self._mostrar_error('')
                self.boton_generar.setEnabled(True)
        else:
            falta = esperados - actuales
            texto = f'falta {abs(falta)}' if falta > 0 else f'sobra {abs(falta)}'
            self._mostrar_error(f'Títulos: {actuales}/{esperados} — {texto}')
            self.boton_generar.setEnabled(False)

    def _mostrar_error(self, mensaje: str):
        self.etiqueta_validacion.setText(mensaje)
        self.etiqueta_validacion.setVisible(bool(mensaje))

    def _mostrar_diff(self):
        if not self._resultado:
            return
        indice = self.selector_capitulo.currentIndex()
        if indice < 0:
            return
        capitulo = self._resultado.capitulos[indice]
        original = self._documentos_raw[indice] if indice < len(self._documentos_raw) else ''
        self.original.setPlainText(original)
        self.limpio.setHtml(capitulo.html_cuerpo)

    def _generar(self):
        template = Path(self.campo_template.text())
        if not template.exists():
            self._mostrar_error(f'No se encuentra el template: {template}')
            return
        if '{{CONTENIDO}}' not in template.read_text(encoding='utf-8'):
            self._mostrar_error('El template no contiene el placeholder {{CONTENIDO}}')
            return
        salida = QFileDialog.getExistingDirectory(
            self, 'Elige la carpeta de salida', str(RUTA_SALIDA_DEFECTO),
            options=QFileDialog.Option.DontUseNativeDialog,
        )
        if not salida:
            return
        salida = Path(salida)
        try:
            limpiar_carpeta(salida)
            plantilla = template.read_text(encoding='utf-8')
            titulos = self._titulos_de_tabla()
            for indice, capitulo in enumerate(self._resultado.capitulos):
                num = indice + 1
                archivo = capitulo.archivo or f'C{num:02d}.xhtml'
                numero = numero_de_archivo(archivo, num)
                if capitulo.plantilla_ruta is not None:
                    plantilla_especial = capitulo.plantilla_ruta.read_text(encoding='utf-8')
                    html_final = render_capitulo_especial(
                        plantilla_especial, titulos[indice], numero, capitulo.html_cuerpo
                    )
                else:
                    html_final = render_capitulo(
                        plantilla, titulos[indice], numero, capitulo.html_cuerpo
                    )
                ruta = salida / archivo
                ruta.write_text(html_final, encoding='utf-8')
            if self._resultado.notas:
                (salida / 'notas_Finales.xhtml').write_text(
                    render_notas(self._resultado.notas), encoding='utf-8'
                )
        except Exception as error:
            self._mostrar_error(f'Error al generar: {error}')
            return
        QMessageBox.information(self, 'Listo', f'Archivos generados en {salida}')


def main():
    app = QApplication(sys.argv)
    ventana = VentanaPrincipal()
    ventana.show()
    sys.exit(app.exec())


if __name__ == '__main__':
    main()