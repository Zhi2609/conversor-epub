import sys
from pdf2docx import Converter

def convertir(ruta_pdf: str, ruta_salida_docx: str):
    cv = Converter(ruta_pdf)
    cv.convert(ruta_salida_docx)
    cv.close()

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Uso: python3 convertidor_pdf.py <entrada.pdf> <salida.docx>")
        sys.exit(1)
    
    try:
        convertir(sys.argv[1], sys.argv[2])
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
