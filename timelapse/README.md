# Timelapse

Graba cómo se hace un dibujo: después de cada cambio guarda una instantánea
del lienzo y, al terminar, la exporta como animación (GIF, WebP, secuencia de
PNG...).

La grabación se guarda en un archivo `<nombre>.timelapse` junto al dibujo
(`gato.aseprite` → `gato.timelapse`), así que sobrevive entre sesiones. Solo
guarda la zona que cambia en cada paso, por lo que ocupa poco.

Todo está en *File > Timelapse*. Para asignar atajos, ve a
*Edit > Keyboard Shortcuts* y busca "Timelapse".

- **Record Timelapse:** empieza a grabar el sprite activo, o la pausa. Mientras
  graba aparece marcado en el menú.
  - El sprite tiene que estar guardado; si no lo está, te ofrece guardarlo.
  - La grabación sigue sola cada vez que abres el dibujo. Si la pausas, sigue
    en pausa hasta que vuelvas a pulsar *Record Timelapse*.
  - Graba el frame que estás editando, con las capas visibles (las de
    referencia no salen).
  - Los cambios muy seguidos (menos de 0,25 s) cuentan como una sola
    instantánea. Deshacer también se graba.
- **Export Timelapse...**
  - *Length:* duración máxima. Si hay más instantáneas de las que caben, se
    toman repartidas por igual (siempre la primera y la última). *All* las usa
    todas.
  - *Speed:* frames por segundo.
  - *Hold end:* segundos que se queda el dibujo terminado al final.
  - *Background:* rellena el fondo con un color en lugar de dejarlo
    transparente.
  - *Export...* abre el diálogo de exportar de Aseprite, donde eliges formato,
    archivo y escala (propone una para que el lado mayor mida al menos
    512 px).
  - *Open as Sprite* abre el timelapse como un sprite nuevo, para verlo o
    retocarlo antes de exportarlo.
- **Delete Timelapse...:** borra el archivo `.timelapse` del sprite activo.

Si guardas el dibujo con otro nombre (*Save As*), el archivo nuevo se lleva
una copia del timelapse y la grabación sigue en esa copia; el original
conserva la suya.

## Permisos

Aseprite pide permiso cuando un script lee o escribe archivos. La primera vez
que grabes te preguntará por el script `snapshots.lua` (el único que toca
archivos): pulsa *Allow* y marca *Don't show this specific alert again for
this script*. Si no lo marcas, volverá a preguntar en cada instantánea.

Para empaquetar: `./build.sh` genera `dist/timelapse.aseprite-extension`.
