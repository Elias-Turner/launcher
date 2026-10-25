# 🏛️ LANZADOR — SELECTOR DE VIDEOJUEGOS PARA TOTEMS (MODO KIOSCO)

Aplicación de escritorio y selector centralizado de videojuegos para **Windows 10 y Windows 11 (64-bit)**, desarrollado **100% en Godot Engine 4 y GDScript nativo**.

Diseñado para totems interactivos de museos y salas públicas, opera en **modo kiosco continuo** impidiendo que los usuarios salgan al escritorio de Windows y optimizando el consumo de hardware al ejecutar un solo juego a la vez.

---

## 🌟 CARACTERÍSTICAS PRINCIPALES

1. **Modo Kiosco Persistente para Totems**:
   - Inicia directamente en pantalla completa sin bordes.
   - Barra de tareas y botones de ventana de Windows totalmente invisibles.
   - La tecla **Escape** no cierra la aplicación para evitar que el público salga al escritorio.
   - El cierre ordenado está reservado para administradores mediante **Alt + F4**.

2. **Gestión Eficiente de Recursos (Un juego a la vez)**:
   - Solo se permite ejecutar un juego en simultáneo; los clics o comandos adicionales son bloqueados mientras un juego está activo.
   - Mientras un minijuego corre, el Lanzador entra en **modo de bajo consumo** (`Engine.max_fps = 5`, `OS.low_processor_usage_mode = true`), liberando CPU y GPU al 100% para el juego.
   - El Lanzador permanece en pantalla completa detrás del juego, evitando mostrar el escritorio de Windows en transiciones.
   - Al cerrar el juego, el Lanzador recupera automáticamente su rendimiento (60 FPS), regresa a primer plano y reenfoca la tarjeta jugada.

3. **Escalabilidad Sin Archivos de Configuración**:
   - Eliminación total de archivos de configuración (`launcher_config.json`).
   - El nombre del juego que aparece en las tarjetas viene dado directamente por el **nombre de la carpeta** (soporta tildes, espacios y caracteres en español). Para cambiar "Trivia" a "Trivia Malvinas", solo se renombra la carpeta.
   - Detección automática del primer ejecutable `.exe` válido dentro de cada carpeta, descartando desinstaladores o herramientas auxiliares.

4. **Convención Estandarizada de Carátulas**:
   - Formato recomendado: **`caratula.png`** (o `.jpg`, `.webp`) dentro de la carpeta del juego.
   - Al no depender del nombre del ejecutable ni de la carpeta, el administrador puede renombrar la carpeta en cualquier momento sin tener que renombrar la imagen.
   - Compatibilidad hacia atrás: soporta automáticamente la convención previa `<nombre_carpeta>_caratula.png`.

5. **Fondo Personalizable Dinámico**:
   - Se puede cambiar el fondo del Lanzador simplemente colocando una imagen (`fondo_lanzador.png` o `.jpg`) al lado del ejecutable `Lanzador.exe`.

---

## 📁 ESTRUCTURA DEL SISTEMA EN EL TOTEM

```
MuseoMinijuegos/
├── Lanzador/
│   ├── Lanzador.exe               # Ejecutable del selector
│   ├── Lanzador.pck               # Paquete de recursos
│   └── fondo_lanzador.png         # Fondo personalizado (opcional)
└── Juegos/
    ├── Trivia/
    │   ├── Trivia.exe             # Ejecutable del juego
    │   ├── Trivia.pck
    │   ├── caratula.png           # Imagen de portada de la tarjeta
    │   └── Personalizacion.trivia
    └── OtroMinijuego/
        ├── OtroMinijuego.exe
        ├── caratula.png
        └── configuracion.json
```

---

## 📂 ESTRUCTURA DEL PROYECTO GODOT

```
launcher/
├── project.godot               # Configuración global del proyecto Godot 4
├── export_presets.cfg          # Preset de exportación a Lanzador.exe
├── scenes/
│   ├── launcher.tscn           # Escena principal con cuadrícula y fondo
│   ├── game_card.tscn          # Tarjeta interactiva con carátula y título
│   └── estado_vacio.tscn       # Mensaje visual cuando no hay juegos
├── scripts/
│   ├── launcher.gd             # Controlador maestro de interfaz y modo Kiosco
│   ├── game_scanner.gd         # Detección y ordenamiento alfabético de juegos
│   ├── game_launcher.gd        # Ejecución en Windows y gestión de recursos
│   ├── game_card.gd            # Animaciones y foco de tarjetas
│   └── icon_manager.gd         # Gestor simplificado de carátulas e imágenes
├── assets/
│   ├── icons/                  # Icono temático de reserva
│   ├── img/                    # Fondo predeterminado
│   ├── styles/                 # Estilos de botones y paneles
│   └── themes/                 # Tema visual de la interfaz
└── tests/
    └── test_launcher_suite.gd  # Suite automatizada de pruebas
```

---

## 🎮 CONVENCIONES Y RECOMENDACIONES

### Carátulas de los Juegos
Colocar una imagen nombrada **`caratula.png`** (o `caratula.jpg`) dentro de cada carpeta en `Juegos/`.
El Lanzador busca en este orden:
1. `caratula.png` / `caratula.jpg` / `caratula.webp` (Recomendado).
2. `portada.png` / `portada.jpg`.
3. `<nombre_carpeta>_caratula.png` (Convención anterior).
4. `icon.png` / `icon.svg` / `logo.png`.
5. Icono predeterminado del sistema.
