# Value Check

Vista previa en escala de grises, en vivo, del sprite activo para comprobar los
valores mientras pintas. No modifica el sprite: no añade capas ni pasos de
deshacer.

- **Abrir/cerrar:** se abre sola al arrancar Aseprite. También puedes
  abrirla o cerrarla en *View > Value Check*; para asignarle un atajo, ve a
  *Edit > Keyboard Shortcuts* y busca "Value Check".
- **Ventana:** se puede redimensionar y recuerda su tamaño y posición.
- **Color:** muestra los colores originales en lugar de los valores.
- **Flip H:** espeja la vista horizontalmente (el sprite no cambia).
- **Mode**
  - *Perceptual (L\*)*: luminosidad percibida (CIE L\*). Es la mejor opción
    para juzgar valores.
  - *Luma (Rec. 601)*: lo mismo que hace un "desaturar" típico.
- **Posterize:** agrupa los valores en 2–8 bandas (con 2 obtienes un notan en
  blanco y negro), para ver si las masas de valor se leen bien.
- **Info:** muestra el rango de valores de la imagen (0–100). Al pasar el ratón
  por la vista, muestra el valor del píxel bajo el cursor y su banda.

Se actualiza al pintar, al deshacer, al cambiar de frame o de sprite y al
cambiar la visibilidad, opacidad o modo de fusión de una capa.

Para empaquetar: `./build.sh` genera `dist/value-check.aseprite-extension`.
