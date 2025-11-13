# 🎹 Piano Sensorial - Flutter

Una aplicación interactiva de piano desarrollada en **Flutter**, que permite tocar melodías, seguir canciones y reproducir notas con audio de alta calidad.

---

## ✨ Características

* Teclado de piano completo con octavas de 3 a 5.
* **Modo libre**: toca cualquier nota a tu gusto.
* **Modo seguir canción**: reproduce canciones en formato JSON y guía al usuario con iluminación de notas.
* **Autoplay**: reproduce automáticamente la canción en el modo seguimiento.
* **Loop**: repite canciones infinitamente.
* Control de BPM y sincronización precisa con compensación de latencia.
* Interfaz responsiva con header y controles adaptativos.
* **AudioPool** robusto para reproducción simultánea de varias notas sin retrasos.
* Compatible con formatos de audio: MP3, WAV, OGG.
* Sistema de **throttle de notas** para evitar solapamientos y sobrecarga de audio.
* Animaciones suaves al presionar teclas blancas y negras.

---

## 📁 Estructura de archivos

```
lib/
 └── main.dart          # Código principal de la app
assets/
 └── piano/             # Archivos de notas individuales (.mp3, .wav, .ogg)
 └── canciones/         # Archivos JSON de canciones
```

---

## 📝 Formato de canción JSON

Cada canción debe tener la siguiente estructura:

```json
{
  "title": "Nombre de la canción",
  "bpm": 96,
  "notes": [
    {"name": "C", "octave": 4, "beats": 1},
    {"name": "D", "octave": 4, "beats": 0.5},
    {"name": "E", "octave": 4, "beats": 1}
  ]
}
```

* `name`: Nota musical (C, Db, D, Eb, E, F, Gb, G, Ab, A, Bb, B) o `R` para silencio.
* `octave`: Octava de la nota (3–5), 0 si es un silencio.
* `beats`: Duración de la nota (1 = negra, 2 = blanca, 0.5 = corchea, etc.).

---

## 📦 Dependencias

* **Flutter**
* **audioplayers**

Agrega en tu `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  audioplayers: ^2.0.0
```

---

## 🚀 Uso

1. Clona el repositorio:

```bash
git clone https://github.com/usuario/piano-sensorial.git
cd piano-sensorial
```

2. Instala las dependencias:

```bash
flutter pub get
```

3. Ejecuta la app:

```bash
flutter run
```

---

## 🎮 Controles

* **Modo libre**: toca cualquier tecla del piano.
* **Seguir canción**: la nota actual se ilumina para guiarte.
* **Autoplay**: la canción se reproduce automáticamente.
* **Loop**: activa/desactiva repetición continua de la canción.
* **BPM**: indicador de velocidad de la canción.

---

## ⚠️ Notas

* Coloca los archivos de notas (C4.mp3, D#4.wav, etc.) en `assets/piano/`.
* Las canciones deben estar en `assets/canciones/` en formato JSON.
* La aplicación maneja automáticamente compensación de latencia y optimización de audio.

---

## 🤝 Contribuciones

¡Bienvenidas! Puedes contribuir agregando nuevas canciones, optimizando el rendimiento o mejorando la UI.

---

## 📝 Licencia

Este proyecto está bajo la **licencia MIT**.
