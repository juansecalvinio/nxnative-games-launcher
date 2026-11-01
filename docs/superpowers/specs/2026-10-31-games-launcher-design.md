# Games Launcher para macOS: diseño

## Intención

Juan tiene juegos de Nintendo Switch recompilados para macOS con el proyecto nxnative. Hoy abre cada uno yendo a su carpeta y haciendo doble click en el `.app`, y uno de ellos necesita un comando con un flag para arrancar en español.

Quiere un launcher nativo y simple que junte sus juegos en un solo lugar, se maneje con el DualSense desde el sillón o escritorio y se sienta como una consola, tomando la Home de Nintendo Switch como referencia.

## Objetivos

- Ver todos los juegos en una pantalla y lanzar cualquiera con el DualSense.
- Definir los juegos en un archivo JSON editado a mano.
- Lanzar cada juego como el doble click por defecto, o con un comando custom si está definido.
- Mostrar la carátula sin configuración, usando el ícono del `.app`.

## No objetivos

- Tienda, cuentas o estadísticas de juego.
- Pantalla de configuración dentro de la app para agregar o editar juegos.
- Imagen de carátula propia por juego en el JSON (descartado por ahora).
- Descarga automática de carátulas por ID oficial (descartado por ahora; si se hace, sería una herramienta aparte para que el launcher nunca dependa de internet).
- Distribución pública, firma o notarización: es para uso personal en su Mac.

## Anti-objetivos

- Que haya que usar teclado o mouse para navegar el launcher y lanzar un juego. Cerrar el juego sí se hace desde el sistema operativo.
- Que el launcher necesite internet.
- Que un juego mal configurado impida usar los demás.
- Que se vea como una app de escritorio común en vez de una consola.

## Decisiones de Juan

- App nativa de macOS.
- Configuración por JSON con el path del directorio donde está el juego.
- Comando de ejecución custom opcional por juego; sin él, se ejecuta como por defecto en el sistema (equivalente al doble click en el `.app`).
- Control principal: DualSense por Bluetooth.
- Pantalla principal, opción B de los mockups: fila horizontal de carátulas abajo, nombre grande del juego elegido sobre la fila, barra superior con avatar y hora, barra inferior con ayuda de botones (`✕ Jugar`) y el juego elegido llenando el fondo. No hay botón de opciones: Juan lo descartó.
- Carátula: el ícono del `.app`, ampliado y desenfocado de fondo, con el ícono nítido encima. Los dos `.app` existentes traen `AppIcon.icns` de 1024×1024 (verificado), pero es cuadrado y la pantalla no, por eso se mantiene el fondo desenfocado.
- La Mac es de uso general: Juan abre el launcher a mano cuando quiere jugar, sin arranque automático al iniciar sesión.
- Validó estas suposiciones: navegación completa con DualSense (izquierda/derecha para moverse, ✕ para jugar), pantalla completa, JSON editado a mano, nombre del juego en el JSON.
- El launcher solo lanza el juego. El juego se abre como una app independiente y se cierra con su ventana del sistema operativo, no desde el launcher. El launcher no sigue, controla ni cierra los juegos: no detecta cuándo terminan ni escucha el control mientras se juega.

## Decisiones técnicas de Claude

- Swift y SwiftUI, target macOS. El soporte de mandos con el framework GameController de Apple, que reconoce el DualSense.
- Ícono obtenido con `NSWorkspace.shared.icon(forFile:)`.
- Lanzamiento por defecto con `NSWorkspace` abriendo el `.app`.
- Comando custom ejecutado a través de `/bin/zsh -c`, con el directorio del juego como directorio de trabajo, para que el usuario escriba el mismo comando que usa en la terminal.
- Proyecto compilable desde la línea de comandos, sin depender de la interfaz de Xcode más de lo necesario.

## Formato del JSON

```json
{
  "games": [
    {
      "name": "Dragon Quest VII Reimagined",
      "path": "~/Documents/gaming/roms/switch/DQ_REIMAGINED"
    },
    {
      "name": "The Legend of Zelda: Breath of the Wild",
      "path": "~/Documents/gaming/roms/switch/ZELDA_BOTW",
      "command": "open --env DM_LANG=es-419 \"The Legend of Zelda - Breath of the Wild.app\""
    }
  ]
}
```

- `name` y `path` son obligatorios; `command` es opcional. El comando corre con `path` como directorio de trabajo, por eso el `.app` va sin ruta.
- `path` es el directorio que contiene el `.app`. También se acepta que apunte directamente al `.app`. El launcher busca el `.app` como hijo directo del directorio. En las carpetas reales conviven con él archivos `.app.key`, `.xci`, `.nsp`, `.7z` y una carpeta `*_build`, que se ignoran. Si hubiera más de un `.app`, se usa el primero en orden alfabético.
- Estado real al 2026-10-31: en `~/Documents/gaming/roms/switch/` hay 4 carpetas y 3 tienen `.app` (`ZELDA_BOTW`, `DQ_REIMAGINED`, `ZELDA_LINKS_AWAKENING`). `DK_RETURNS_HD` todavía tiene una descarga en curso.
- El launcher no escanea esta carpeta: solo muestra lo que está en el JSON.
- El orden en la fila es el orden del JSON.
- Se expande `~` en los paths.

## Ubicación del JSON

Decisión de Claude: `~/Library/Application Support/GamesLauncher/games.json`. Si no existe, el launcher muestra una pantalla que indica la ruta y un ejemplo del formato.

## Casos de error

Decisión de Claude:

- JSON inválido: pantalla de error con la ruta y el problema; la app no se cierra.
- Juego sin `.app` encontrado o path inexistente, y sin `command`: aparece en la fila marcado como no disponible, y al elegirlo muestra el motivo.
- Juego con `command` pero sin `.app`: se puede lanzar, y usa una carátula genérica.
- Falla al lanzar: mensaje en pantalla y se sigue en el launcher. Con `open` el comando termina enseguida, así que solo se detectan fallas de arranque, no lo que pase después con el juego.

## Salir del launcher

Decisión de Claude: como la Mac es de uso general y no hay botón de opciones, se sale con `Cmd+Q`, igual que cualquier app. Con `Cmd+Tab` se puede pasar a otra app sin cerrarlo. El control no tiene acción de salir, para evitar cierres accidentales. Esto no contradice el anti-objetivo: es salir, no navegar ni lanzar.

Tras lanzar un juego el launcher queda abierto detrás, sin hacer nada más.

## Queda a criterio de quien construya

- Animaciones, sonidos y detalles visuales finos, siempre cerca de la referencia de Switch.
- Cómo se ve y cómo se organiza internamente el código.
