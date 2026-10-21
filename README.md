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

1. Descarga la extensión desde la
   [última release](https://github.com/alfocal/aseprite-plugins/releases/latest):
   - [value-check.aseprite-extension](https://github.com/alfocal/aseprite-plugins/releases/latest/download/value-check.aseprite-extension)
   - [iso-guides.aseprite-extension](https://github.com/alfocal/aseprite-plugins/releases/latest/download/iso-guides.aseprite-extension)
   - [timelapse.aseprite-extension](https://github.com/alfocal/aseprite-plugins/releases/latest/download/timelapse.aseprite-extension)
2. Instálala en Aseprite haciendo doble clic en el archivo, o desde
   *Edit > Preferences > Extensions > Add Extension*.

Al instalar una versión nueva, sustituye a la anterior.

También puedes generar los paquetes tú mismo con `./build.sh`; se crean en
`dist/`, uno por extensión (`dist/<nombre>.aseprite-extension`).

Desarrollado con Aseprite v1.3.18.

## Desarrollo

```
build.sh          empaqueta cada extensión en dist/
.github/workflows/release.yml
                  publica una release en GitHub en cada push a main
<extensión>/      una carpeta por extensión
  package.json    manifiesto: nombre, versión y scripts que carga
  *.lua
dist/             paquetes generados (no se versiona)
```

Para añadir una extensión nueva, crea una carpeta con su `package.json`;
`build.sh` empaqueta automáticamente cualquier carpeta que tenga uno. Al
publicar cambios, sube el campo `version` del `package.json`.

Cada push a `main` lanza el workflow
[`release.yml`](.github/workflows/release.yml), que ejecuta `build.sh` y
publica una release (`vAAAA.MM.DD-N`) con todos los paquetes, sus versiones y
los commits desde la release anterior. Los cambios que solo tocan este README,
`LICENSE`, `.gitignore` o `.editorconfig` no generan release. También se puede
lanzar a mano desde la pestaña *Actions*.

## Licencia

[MIT](LICENSE)
