# ☀ LAUNCHER ARGENTINO — SELECTOR DE VIDEOJUEGOS PARA WINDOWS EN GODOT 4.7

Aplicación de escritorio y selector centralizado de videojuegos para **Windows 10 y Windows 11 (64-bit)**, desarrollado **100% en Godot Engine 4.7 y GDScript nativo**.

Diseñado bajo la estética soberana de la **Bandera Argentina** (celeste `#75AADB`, blanco `#FFFFFF`, Sol de Mayo dorado `#F6B40E` y azul profundo `#1C3B57`), opera como una interfaz estilo consola en **modo kiosco persistente**.

---

## 🌟 CARACTERÍSTICAS PRINCIPALES

1. **Desarrollo 100% Nativo en Godot 4.7 & GDScript**:
   - Sin Python, Tkinter, C#, Java, Electron, frameworks externos ni ejecutables auxiliares.
   - Utiliza exclusivamente nodos, shaders, CanvasItem, recursos y funciones nativas del motor.

2. **Modo Kiosco Persistente (No se puede salir accidentalmente)**:
   - Pantalla completa sin bordes directa al iniciar (`WINDOW_MODE_EXCLUSIVE_FULLSCREEN`).
   - Barra de título y botones de minimizar, maximizar o cerrar de Windows totalmente ocultos.
   - Sin botones de salir, minimizar o volver al escritorio en la interfaz.
   - Intercepción de `NOTIFICATION_WM_CLOSE_REQUEST` y `get_tree().set_auto_accept_quit(false)` para bloquear intentos de cierre como Alt+F4.
   - Tecla **Escape** interceptada y consumida; no cierra la aplicación.

3. **Ciclo de Ejecución y Regreso Automático**:
   - Al pulsar cualquier tarjeta (icono, nombre o fondo), el juego se ejecuta inmediatamente con `OS.create_process()`.
   - El launcher minimiza temporalmente su ventana para ceder el primer plano y los recursos al videojuego.
   - Monitoreo no bloqueante en segundo plano (`OS.is_process_running(pid)`).
   - Al cerrar el videojuego, el launcher se restaura automáticamente a pantalla completa, vuelve a primer plano y devuelve el foco a la tarjeta seleccionada.

4. **Detección Automática y Recursiva de Videojuegos**:
   - Localiza dinámicamente el directorio base (tanto en el editor como en la distribución exportada).
   - Examina subdirectorios hasta 3 niveles de profundidad (ejemplo: `Aventura/bin/Aventura.exe`).
   - El nombre visible de la tarjeta proviene del **nombre de la carpeta**, preservando espacios y tildes en español.
   - Filtrado determinista de ejecutables auxiliares: descarta desinstaladores (`unins*`), actualizadores, crash handlers y herramientas de configuración.
   - Prevención estricta de duplicados: exactamente una tarjeta por carpeta de juego.

5. **Identidad Visual Argentina**:
   - Composición de tres franjas: Celeste bandera, Blanco central y Celeste inferior con gradientes suaves.
   - Sol de Mayo procedural vectorial con **32 rayos** (16 rectos y 16 flamígeros ondulados alternados) y rostro tradicional sereno.
   - Encabezado soberano: **☀ SELECCIONÁ TU JUEGO ☀** con línea divisoria dorada.
   - Pie de pantalla con cantidad de juegos detectados, estado del sistema, instrucciones y versión.
   - Tarjetas interactivas con estados normal (borde celeste), hover (borde dorado y elevación suave con `Tween`) y seleccionado/foco.

6. **Jerarquía y Resolución de Iconos**:
   - Prioridad 1: Icono configurado en `launcher_config.json`.
   - Prioridad 2: Archivo de imagen convencional en la carpeta del juego (`launcher_icon.png`, `icon.png`, `icono.png`, `logo.png`, `cover.png`).
   - Prioridad 3: Imagen en subcarpetas de recursos (`recursos/icon.png`, `assets/icon.png`).
   - Prioridad 4: Icono temático oficial de reserva (vector SVG con joystick y Sol de Mayo argentino).
   - Caché en memoria para evitar relecturas constantes de disco.

---

## 📁 ESTRUCTURA DEL PROYECTO

```
launcher-argentino-godot/
├── project.godot               # Configuración global del proyecto Godot 4.7
├── export_presets.cfg          # Preset de exportación para Windows Desktop x86_64
├── launcher_config.json        # Archivo opcional de configuración de excepciones
├── scenes/
│   ├── launcher.tscn           # Escena principal (interfaz, kiosco, cabecera y pie)
│   ├── game_card.tscn          # Escena modular reutilizable de tarjeta de juego
│   └── sun_of_may.tscn         # Escena del Sol de Mayo procedural argentino
├── scripts/
│   ├── launcher.gd             # Controlador maestro de la interfaz y modo kiosco
│   ├── game_scanner.gd         # Escaneo recursivo y selección determinista de .exe
│   ├── game_launcher.gd        # Ejecución con OS.create_process y regreso automático
│   ├── game_card.gd            # Comportamiento visual, focus y animaciones Tween
│   ├── icon_manager.gd         # Resolución, carga dinámica y caché de iconos
│   └── sun_of_may.gd           # Dibujo procedural CanvasItem con 32 rayos
├── assets/
│   └── icons/
│       └── default_game_icon.svg # Icono vectorial temático oficial argentino
├── tests/
│   └── test_launcher_suite.gd  # Suite automatizada que valida las Pruebas A a L
└── README.md
```

---

## ⚙️ DETALLES TÉCNICOS FUNDAMENTALES

### 1. ¿Cómo maneja Godot 4 los iconos incrustados dentro de los archivos `.exe`?
En Windows, los iconos incrustados en los ejecutables forman parte de la cabecera PE (*Portable Executable*) en la sección de recursos binarios (`.rsrc`). Godot Engine 4 en GDScript puro no incluye un deserializador de recursos PE de Windows.
Para mantener el **requisito estricto de desarrollo exclusivo en Godot sin scripts en Python ni bibliotecas nativas externas**, el launcher implementa la convención estándar de la industria:
- Si colocás `launcher_icon.png`, `icon.png` o `icono.png` en la carpeta del juego, el launcher lo detecta y lo carga dinámicamente en tiempo de ejecución con `Image.load_from_file()` y `ImageTexture.create_from_image()`.
- Si no existe un archivo de icono, el launcher utiliza su icono temático argentino de alta definición sin interrumpir el funcionamiento de la tarjeta.

### 2. Directorio de trabajo al ejecutar videojuegos
Al iniciar un juego externo mediante `OS.create_process(executable_path, PackedStringArray([]), false)`:
- Se envía la ruta canónica absoluta del ejecutable.
- En juegos exportados de Godot, el motor busca automáticamente su archivo `.pck` en el mismo directorio donde reside el `.exe`.
- Para juegos cuyos recursos dependen de la carpeta del ejecutable, la ruta absoluta del binario garantiza que Windows ubique los recursos vecinos.

### 3. Restricciones del Sistema Operativo vs Godot
El launcher implementa todas las protecciones compatibles con Godot:
- Ventana sin bordes a pantalla completa (`WINDOW_MODE_EXCLUSIVE_FULLSCREEN`).
- `get_tree().set_auto_accept_quit(false)` e intercepción de `NOTIFICATION_WM_CLOSE_REQUEST` (anula Alt+F4 y eventos estándar de cierre).
- Consumo de la tecla `Escape` en `_unhandled_input()`.
- Sin controles de salida en pantalla.

> **Nota sobre seguridad y modo Kiosco real en Windows:**
> Las combinaciones de teclado a nivel del kernel de Windows como `Ctrl + Alt + Supr`, `Win + L` o el acceso al Administrador de Tareas no pueden ni deben ser interceptadas mediante código GDScript ficticio ni modificaciones destructivas del registro. En un entorno arcade o cabina comercial dedicada, se recomienda activar el **Modo Kiosco de Windows (Acceso Asignado / Shell Launcher)** configurando `LauncherArgentino.exe` como el Shell de la cuenta de usuario.

---

## 🚀 INSTRUCCIONES DE USO

### Ejecución desde el editor de Godot
1. Abrí **Godot Engine 4.7**.
2. Hacé clic en **Importar** y seleccioná la carpeta `launcher-argentino-godot`.
3. Presioná **F5** (o el botón *Reproducir Proyecto* en la esquina superior derecha).
4. El launcher se iniciará en pantalla completa con la estética de la Bandera Argentina.

### Ejecución de la Suite de Pruebas Automatizadas
Para verificar todos los escenarios del sistema de forma automática:
```powershell
& "ruta/a/godot.exe" --headless --path "ruta/al/proyecto" -s "res://tests/test_launcher_suite.gd"
```

---

## 📦 EXPORTACIÓN Y DISTRIBUCIÓN PARA WINDOWS 64-BIT

1. En el editor de Godot, ingresá a **Proyecto > Exportar...**.
2. Seleccioná el preset preconfigurado **Windows Desktop**.
3. Hacé clic en **Exportar Proyecto**.
4. Seleccioná la carpeta de destino y el nombre del archivo (por ejemplo, `LauncherArgentino.exe`).
5. La estructura final de distribución para el usuario final quedará de la siguiente forma:

```
Biblioteca/
├── LauncherArgentino.exe
├── LauncherArgentino.pck (o integrado según opción de exportación)
├── Juego de Memoria/
│   ├── JuegoDeMemoria.exe
│   ├── launcher_icon.png
│   └── recursos/
├── Vuelo de Reconocimiento/
│   ├── Vuelo.exe
│   └── icon.png
├── Aventura Fantástica/
│   └── bin/
│       └── Aventura.exe
└── Plataforma 2D/
    └── Plataforma.exe
```

Cualquier nueva carpeta con un archivo `.exe` que se coloque al lado de `LauncherArgentino.exe` será detectada automáticamente al iniciar el launcher o al presionar **F5**.

---

## 🎮 CONTROLES

| Entrada | Acción |
| :--- | :--- |
| **Clic izquierdo del ratón** | Iniciar juego inmediatamente |
| **Flechas (Arriba / Abajo / Izquierda / Derecha)** | Navegar entre tarjetas de juegos |
| **Enter / Espacio** | Iniciar el juego enfocado |
| **F5** | Actualizar biblioteca (rescanear carpetas) |
| **Escape** | Bloqueado (no permite salir) |
| **Alt + F4** | Bloqueado mediante Modo Kiosco |
