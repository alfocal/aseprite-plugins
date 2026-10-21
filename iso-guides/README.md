# Iso Guides

Rejilla isométrica para dibujar pixel art encima. Usa la línea 2:1 típica del
pixel art (2 píxeles en horizontal por cada 1 en vertical), así que las
baldosas miden W × W/2 y sus esquinas son tramos planos de 2 píxeles.

La rejilla vive en una **capa de referencia** bloqueada llamada "Iso Guide",
encima del resto de capas. Aseprite la muestra en el editor, pero no la incluye
al exportar ni en las previsualizaciones, así que nunca acaba en tu dibujo. Se
guarda con el `.aseprite`.

- **Abrir/cerrar:** *View > Iso Guides*.
- **Tile:** tamaño de la baldosa, de 8x4 a 128x64.
- **Color / Opacity:** color de las líneas y opacidad de la capa.
- **Vertical lines:** líneas verticales punteadas por cada esquina, para
  levantar paredes y alturas.
- **Origin**
  - *Pick...*: haz clic en el lienzo donde quieras una esquina de baldosa
    (Esc para cancelar).
  - *Center*: pone una esquina en el centro del lienzo (es la posición por
    defecto).
- **Add guide / Redraw:** crea la guía en el sprite activo. Si ya existe, la
  vuelve a dibujar; úsalo después de cambiar el tamaño del lienzo o de añadir
  frames vacíos.
- **Show/Hide:** muestra u oculta la guía sin añadir pasos de deshacer.
  También está en *View > Show/Hide Iso Guide*; para asignarle un atajo, ve a
  *Edit > Keyboard Shortcuts* y busca "Iso Guide".
- **Remove:** borra la capa de la guía.

Cada sprite tiene su propia guía y el diálogo muestra la del sprite activo.
Los cambios se aplican al momento y cada uno se puede deshacer.

## Trucos

- Con la herramienta **Line**, mantén **Shift** para que la línea se ajuste a
  los ángulos 2:1 (y también a 0°, 45° y 90°).
- Activa *Pixel-perfect* en el lápiz para que los trazos a mano alzada no
  dejen esquinas dobles.

Para empaquetar: `./build.sh` genera `dist/iso-guides.aseprite-extension`.
