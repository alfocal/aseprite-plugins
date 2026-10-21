# aseprite-plugins

Extensiones para [Aseprite](https://www.aseprite.org/) escritas con su
[API de Lua](https://www.aseprite.org/api/).

## Extensiones

| Extensión | Descripción |
| --- | --- |
| [Value Check](value-check/) | Vista previa en vivo y en escala de grises para comprobar los valores mientras pintas. Incluye posterizado, vista con los colores originales y espejo horizontal. |
| [Iso Guides](iso-guides/) | Rejilla isométrica 2:1 para dibujar pixel art, en una capa de referencia bloqueada que no se exporta. |
| [Timelapse](timelapse/) | Graba una instantánea del dibujo tras cada cambio y exporta la grabación como animación (GIF, WebP, PNG...). |

## Instalación

1. Genera los paquetes con `./build.sh`. Se crean en `dist/`, uno por extensión
   (`dist/<nombre>.aseprite-extension`).
2. Instálalo en Aseprite haciendo doble clic en el archivo, o desde
   *Edit > Preferences > Extensions > Add Extension*.

Al instalar una versión nueva, sustituye a la anterior.

Desarrollado con Aseprite v1.3.18.

## Desarrollo

```
build.sh          empaqueta cada extensión en dist/
<extensión>/      una carpeta por extensión
  package.json    manifiesto: nombre, versión y scripts que carga
  *.lua
dist/             paquetes generados (no se versiona)
```

Para añadir una extensión nueva, crea una carpeta con su `package.json`;
`build.sh` empaqueta automáticamente cualquier carpeta que tenga uno. Al
publicar cambios, sube el campo `version` del `package.json`.

## Licencia

[MIT](LICENSE)
