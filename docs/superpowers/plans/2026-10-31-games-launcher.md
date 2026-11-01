# Games Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App nativa de macOS a pantalla completa que lee `games.json`, muestra los juegos estilo consola y los lanza con el DualSense.

**Architecture:** Paquete Swift con dos targets: `LauncherCore` (configuración, resolución de juegos, lanzamiento y modelo de selección, todo testeable sin UI) y el ejecutable `GamesLauncher` (SwiftUI y GameController). Un script arma el `.app` a partir del binario de SwiftPM, sin proyecto de Xcode.

**Tech Stack:** Swift 6, SwiftUI, AppKit (`NSWorkspace`), GameController, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-31-games-launcher-design.md`

## Global Constraints

- Sin dependencias externas ni acceso a internet.
- Plataforma mínima: macOS 14. Bundle id: `com.juansecalvinio.gameslauncher`.
- JSON en `~/Library/Application Support/GamesLauncher/games.json`.
- `name` y `path` obligatorios, `command` opcional; se expande `~` en los paths.
- Comando custom: `/bin/zsh -c <command>` con el directorio del juego como directorio de trabajo.
- El launcher no sigue, controla ni cierra juegos. Nunca usar `GCController.shouldMonitorBackgroundEvents`.
- Sin botón de opciones. La barra inferior muestra solo `✕ Jugar`. Se sale con `Cmd+Q`.
- Textos de la UI en español.

## Review Focus

1. Un `command` que ejecuta un binario directo y no termina: el launcher no se queda colgado (Task 3).
2. Nombres con apóstrofe y espacios, como `The Legend of Zelda - Link's Awakening.app`: se resuelven y se abren sin pasar por un shell (Tasks 2 y 3).
3. Doble ✕ rápido: se lanza una sola vez (Task 4).
4. JSON editado con menos juegos mientras la app sigue abierta: la selección queda dentro del rango (Task 4).
5. Carpetas reales con `.app.key`, `*_build`, `.xci`, `.nsp`: nada de eso se confunde con el `.app`, y una lista `games` vacía no rompe la pantalla (Tasks 2 y 5).

---

### Task 1: Paquete y lectura del JSON

**Files:**
- Create: `.gitignore` (`.build/`, `build/`, `.superpowers/`, `.DS_Store`)
- Create: `Package.swift`
- Create: `Sources/LauncherCore/GameConfig.swift`
- Create: `Sources/GamesLauncher/main.swift` (placeholder hasta la Task 5)
- Test: `Tests/LauncherCoreTests/GameConfigTests.swift`

**Interfaces:**
- Produces:
  - `public struct GameEntry: Decodable, Equatable { public let name: String; public let path: String; public let command: String? }`, con `init` público memberwise.
  - `public enum ConfigLoadResult: Equatable { case loaded([GameEntry]); case missing; case invalid(String) }`
  - `public enum ConfigStore { public static var defaultURL: URL; public static func load(from url: URL) -> ConfigLoadResult }`

- [ ] **Step 1: Inicializar repo y paquete**

`git init`, `.gitignore` y `Package.swift` con tools 6.0, plataforma `.macOS(.v14)`, library target `LauncherCore`, executable target `GamesLauncher` que depende de él y test target `LauncherCoreTests`.

- [ ] **Step 2: Escribir los tests que fallan**

Con un archivo temporal por test y Swift Testing:

```swift
@Test func loadsGamesInFileOrder()      // 2 juegos -> .loaded, el orden se conserva, command nil en el primero
@Test func missingFileIsMissing()       // URL inexistente -> .missing
@Test func malformedJsonIsInvalid()     // "{" -> .invalid con mensaje no vacío
@Test func entryWithoutPathIsInvalid()  // {"games":[{"name":"x"}]} -> .invalid
@Test func emptyGamesIsLoadedEmpty()    // {"games":[]} -> .loaded([])
@Test func unknownFieldsAreIgnored()    // campo extra -> .loaded
@Test func defaultURLPoints()           // termina en "GamesLauncher/games.json"
```

- [ ] **Step 3: Verificar que fallan**

Run: `swift test`
Expected: FAIL, `ConfigStore` no existe.

- [ ] **Step 4: Implementar `GameConfig.swift`**

`JSONDecoder` sobre un `struct` interno `{ games: [GameEntry] }`. `.missing` solo si el archivo no existe. Usar `FileManager.urls(for: .applicationSupportDirectory, ...)` para `defaultURL`.

- [ ] **Step 5: Verificar que pasan**

Run: `swift test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add .gitignore Package.swift Sources Tests docs
git commit -m "feat: add package and games.json loading"
```

### Task 2: Resolución de cada juego

**Files:**
- Create: `Sources/LauncherCore/Game.swift`
- Test: `Tests/LauncherCoreTests/GameResolverTests.swift`

**Interfaces:**
- Consumes: `GameEntry`.
- Produces:
  - `public struct Game: Equatable { public let name: String; public let directory: URL; public let appURL: URL?; public let command: String?; public let unavailableReason: String?; public var isLaunchable: Bool { unavailableReason == nil } }`, con `init` público memberwise.
  - `public enum GameResolver { public static func resolve(_ entry: GameEntry, fileManager: FileManager = .default) -> Game }`

- [ ] **Step 1: Escribir los tests que fallan**

Crear estructuras reales en un directorio temporal:

```swift
@Test func findsAppInDirectory()         // appURL termina en "Juego.app"
@Test func pathCanPointDirectlyToApp()   // path ".../Juego.app" -> appURL ese mismo, directory su padre
@Test func expandsTilde()                // "~/x" -> directory bajo NSHomeDirectory()
@Test func trailingSlashWorks()          // ".../Juego/" resuelve igual
@Test func ignoresKeyAndBuildSiblings()  // X.app.key, 0100_build/, X.xci + X.app -> solo X.app
@Test func apostropheAndSpacesInName()   // "The Legend of Zelda - Link's Awakening.app" -> resuelto
@Test func onlyDirectChildrenAreSearched() // sub/Juego.app -> appURL nil
@Test func multipleAppsPicksFirstAlphabetically() // B.app, A.app -> A.app
@Test func keyFileAloneIsNotAnApp()      // solo X.app.key -> no disponible
@Test func noAppNoCommandIsUnavailable() // reason == "No se encontró ningún .app en: <path>"
@Test func missingDirectoryIsUnavailable() // reason == "No se encontró la carpeta: <path>"
@Test func commandWithoutAppIsLaunchable() // appURL nil, isLaunchable true
@Test func missingDirectoryWithCommandIsUnavailable() // no hay directorio de trabajo posible
```

- [ ] **Step 2: Verificar que fallan**

Run: `swift test --filter GameResolverTests`
Expected: FAIL, `GameResolver` no existe.

- [ ] **Step 3: Implementar `GameResolver.resolve` en `Game.swift`**

`NSString.expandingTildeInPath`. Un `.app` es un directorio con `pathExtension == "app"`, buscado con `contentsOfDirectory` sin recursión y ordenado por nombre.

- [ ] **Step 4: Verificar que pasan**

Run: `swift test --filter GameResolverTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "feat: resolve game entries to launchable apps"
```

### Task 3: Lanzamiento

**Files:**
- Create: `Sources/LauncherCore/GameLauncher.swift`
- Test: `Tests/LauncherCoreTests/GameLauncherTests.swift`

**Interfaces:**
- Consumes: `Game`.
- Produces:
  - `public protocol GameLaunching: Sendable { func launch(_ game: Game) async throws }`
  - `public struct SystemGameLauncher: GameLaunching { public init(failureWindow: Duration = .seconds(2)) }`
  - `public enum LaunchError: LocalizedError, Equatable { case commandFailed(code: Int32, output: String); case nothingToLaunch }`

- [ ] **Step 1: Escribir los tests que fallan**

Con un `Game` de directorio temporal:

```swift
@Test func commandRunsInGameDirectory()   // "pwd > out.txt" -> out.txt en el directorio, con ese path
@Test func commandKeepsShellQuoting()     // comando con comillas dobles y espacios se ejecuta bien
@Test func failingCommandThrows()         // "echo no >&2; exit 3" -> .commandFailed(code: 3, output: "no")
@Test func longRunningCommandReturns()    // failureWindow 0.2s, "sleep 30" -> vuelve en menos de 2s, sin error
@Test func noAppNoCommandThrows()         // -> .nothingToLaunch
```

La rama de `NSWorkspace` no se cubre con tests automáticos, porque abriría apps reales. Se verifica en la Task 6.

- [ ] **Step 2: Verificar que fallan**

Run: `swift test --filter GameLauncherTests`
Expected: FAIL, `SystemGameLauncher` no existe.

- [ ] **Step 3: Implementar `SystemGameLauncher`**

Con `command`: `Process` con `/bin/zsh`, `["-c", command]`, `currentDirectoryURL = game.directory` y stderr a un `Pipe`. Esperar la primera de dos cosas: que termine o que pase `failureWindow`. Exit 0 o sigue corriendo: éxito, y el proceso queda vivo por su cuenta. Exit distinto de 0: `.commandFailed`. Sin `command`: `NSWorkspace.shared.openApplication(at:configuration:)` sobre `appURL`, sin shell. `errorDescription` en español.

- [ ] **Step 4: Verificar que pasan**

Run: `swift test --filter GameLauncherTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "feat: launch games by app or custom command"
```

### Task 4: Modelo de selección

**Files:**
- Create: `Sources/LauncherCore/LauncherModel.swift`
- Test: `Tests/LauncherCoreTests/LauncherModelTests.swift`

**Interfaces:**
- Consumes: `ConfigStore`, `GameResolver`, `Game`, `GameLaunching`.
- Produces:

```swift
public enum LauncherState: Equatable { case ready; case configMissing(URL); case configInvalid(URL, String) }

@MainActor @Observable public final class LauncherModel {
    public private(set) var state: LauncherState
    public private(set) var games: [Game]
    public private(set) var selectedIndex: Int
    public var message: String?
    public var selectedGame: Game? { get }
    public init(configURL: URL, launcher: any GameLaunching)
    public func reload()
    public func moveLeft()
    public func moveRight()
    public func confirm() async
}
```

- [ ] **Step 1: Escribir los tests que fallan**

Con un `GameLaunching` falso que cuenta llamadas y puede fallar o demorarse:

```swift
@Test func moveStopsAtEdges()             // no da la vuelta, igual que Switch
@Test func moveWithNoGamesDoesNotCrash()  // selectedGame nil
@Test func confirmLaunchesSelected()      // el falso recibe ese juego
@Test func confirmOnUnavailableShowsReason() // message == reason, 0 llamadas
@Test func launchFailureShowsMessage()    // message != nil, sigue .ready
@Test func doubleConfirmLaunchesOnce()    // 2 confirm concurrentes con falso demorado -> 1 llamada
@Test func confirmWhileMessageDismisses() // con message visible, confirm lo limpia y no lanza
@Test func reloadClampsSelection()        // índice 2, JSON pasa a 1 juego -> selectedIndex 0
@Test func reloadKeepsSelectionInRange()  // índice 1, reload igual -> sigue 1
@Test func missingConfigState()           // -> .configMissing(url)
@Test func invalidConfigState()           // -> .configInvalid con mensaje
```

- [ ] **Step 2: Verificar que fallan**

Run: `swift test --filter LauncherModelTests`
Expected: FAIL, `LauncherModel` no existe.

- [ ] **Step 3: Implementar `LauncherModel`**

Un flag `isLaunching` evita lanzamientos dobles. `init` llama a `reload()`.

- [ ] **Step 4: Verificar que pasan**

Run: `swift test --filter LauncherModelTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "feat: add launcher selection model"
```

### Task 5: Pantalla principal y empaquetado

**Files:**
- Delete: `Sources/GamesLauncher/main.swift`
- Create: `Sources/GamesLauncher/GamesLauncherApp.swift` (`@main`, una ventana)
- Create: `Sources/GamesLauncher/HomeView.swift` (barras, nombre y fila)
- Create: `Sources/GamesLauncher/GameArtwork.swift` (ícono y fondo)
- Create: `Sources/GamesLauncher/NoticeViews.swift` (configuración faltante o inválida, sin juegos, mensaje)
- Create: `scripts/bundle.sh`
- Create: `Resources/Info.plist`

**Interfaces:**
- Consumes: `LauncherModel`, `LauncherState`, `Game`, `ConfigStore.defaultURL`, `SystemGameLauncher`.
- Produces: `build/GamesLauncher.app`, y `HomeView(model: LauncherModel)` para la Task 6.

- [ ] **Step 1: Implementar la pantalla, siguiendo la opción B del mockup**

- Fondo: ícono del juego elegido ampliado a pantalla completa, con `.blur`, y degradado oscuro desde abajo.
- Barra superior: círculo de avatar genérico a la izquierda, hora actual a la derecha.
- Abajo: nombre grande del juego elegido y la fila de íconos nítidos, con borde celeste y separación en el elegido. Los no disponibles van atenuados.
- Barra inferior: solo `✕ Jugar`.
- Ícono: `NSWorkspace.shared.icon(forFile:)` fijando `image.size` en 1024×1024 para que no use la representación de 32 pt. Sin `appURL`: fondo gris y símbolo `gamecontroller.fill`.
- `NoticeViews`: `.configMissing` muestra la ruta y un ejemplo del formato. `.configInvalid` muestra la ruta y el problema. Lista vacía: "No hay juegos en games.json". `message`: panel centrado.

- [ ] **Step 2: Crear `Resources/Info.plist` y `scripts/bundle.sh`**

El script corre `swift build -c release`, copia el binario a `build/GamesLauncher.app/Contents/MacOS/`, copia el plist y firma con `codesign --force --sign -`. El plist lleva el bundle id, `LSMinimumSystemVersion` 14.0 y `NSPrincipalClass` `NSApplication`.

- [ ] **Step 3: Compilar y verificar**

Run: `swift test && bash scripts/bundle.sh && open build/GamesLauncher.app`
Expected: tests PASS. Sin `games.json` se ve la pantalla con la ruta. Con un JSON de prueba de 0 juegos se ve el aviso de lista vacía, y con 3 se ve la fila.

- [ ] **Step 4: Commit**

```bash
git add Sources Resources scripts
git commit -m "feat: add home screen and app bundling"
```

### Task 6: DualSense, pantalla completa y configuración real

**Files:**
- Create: `Sources/GamesLauncher/ControllerInput.swift`
- Modify: `Sources/GamesLauncher/GamesLauncherApp.swift`
- Modify: `Sources/GamesLauncher/HomeView.swift`
- Create (fuera del repo): `~/Library/Application Support/GamesLauncher/games.json`

**Interfaces:**
- Consumes: `LauncherModel.moveLeft()`, `moveRight()`, `confirm()`, `reload()`.
- Produces: `@MainActor final class ControllerInput { init(model: LauncherModel); func start() }`

- [ ] **Step 1: Implementar `ControllerInput`**

Observar `GCControllerDidConnect` y usar `controller.extendedGamepad`: dpad y stick izquierdo para moverse, `buttonA` (✕ en DualSense) para confirmar. El stick actúa una vez por inclinación, con umbral 0.5, para no saltar varios juegos. También flechas y Return en `HomeView` con `.onKeyPress`, por si el control no está conectado.

- [ ] **Step 2: Pantalla completa y recarga**

Entrar en pantalla completa nativa al abrir, con `NSWindow.toggleFullScreen`, para que `Cmd+Tab` siga funcionando. Llamar a `model.reload()` en `NSApplication.didBecomeActiveNotification`, así los cambios en el JSON se ven al volver a la app.

- [ ] **Step 3: Crear `games.json` con los juegos reales**

Breath of the Wild con `open --env DM_LANG=es-419 "The Legend of Zelda - Breath of the Wild.app"`, Dragon Quest VII y Link's Awakening, con los paths de `~/Documents/gaming/roms/switch/`. Si `DK_RETURNS_HD` ya tiene `.app`, agregarlo.

- [ ] **Step 4: Verificación manual con Juan**

Run: `swift test && bash scripts/bundle.sh && open build/GamesLauncher.app`

Aceptar el permiso de acceso a Documentos si aparece (con firma ad-hoc puede repetirse tras recompilar). Comprobar:

- El DualSense mueve la selección y el stick no salta juegos.
- ✕ abre Dragon Quest VII y Link's Awakening como apps independientes.
- Breath of the Wild arranca en español.
- Cerrar un juego desde su ventana deja el launcher disponible.
- Mientras se juega, el control no mueve la selección del launcher ni lanza nada.
- `Cmd+Tab` y `Cmd+Q` funcionan.

Expected: todo lo anterior se cumple.

- [ ] **Step 5: Commit**

```bash
git add Sources
git commit -m "feat: add DualSense input and fullscreen"
```
