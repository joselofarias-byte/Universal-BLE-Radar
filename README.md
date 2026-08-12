# SignalRadar

**SignalRadar** es un proyecto Android/Flutter mantenido por **JoseloFarias** para detección, análisis y localización heurística de dispositivos Bluetooth Low Energy mediante intensidad de señal y sensores del teléfono.

El proyecto evolucionó a partir de `erogluyusuf/Universal-BLE-Radar`, pero su desarrollo actual tiene identidad, objetivos, arquitectura y evolución propias. Se conserva deliberadamente la genealogía Git para mantener trazabilidad técnica, autoría y atribución del proyecto de origen.

## Meta

Convertir el escaneo BLE en una herramienta práctica de localización: seleccionar un objetivo, estimar proximidad y orientar al usuario mediante RSSI, rumbo y fusión de sensores sin requerir hardware UWB.

## Objetivos técnicos

- Escaneo BLE continuo mediante una capa desacoplada.
- Clasificación de proximidad por RSSI.
- Suavizado EMA y análisis de tendencia para reducir ruido.
- Radar sectorial de 16 sectores de 22,5°.
- Ventana de muestras por sector y selección de señal dominante.
- Fusión de señal con magnetómetro y sensores de movimiento.
- Seguimiento de un dispositivo objetivo.
- Feedback visual y háptico durante la búsqueda.
- Privacidad local y ausencia de telemetría innecesaria.

## Estado

**Desarrollo activo.** SignalRadar ya incorpora lógica propia de radar sectorial, clasificación de proximidad y procesamiento de señal, y continúa avanzando en precisión, fusión de sensores, UX y validación sobre dispositivos reales.

La CI valida análisis estático, tests y generación de APK Android.

## Desarrollo

```bash
git clone https://github.com/joselofarias-byte/Universal-BLE-Radar.git
cd Universal-BLE-Radar
flutter pub get
flutter analyze
flutter test
flutter build apk
```

## Origen, genealogía y licencia

SignalRadar es un **proyecto derivado** de `erogluyusuf/Universal-BLE-Radar`.

Se mantiene la genealogía Git original de forma intencional para preservar:

- autoría e historial verificables;
- trazabilidad de los cambios;
- comparación con el proyecto de origen;
- cumplimiento de atribuciones y licencia aplicable.

Las partes provenientes del proyecto original conservan sus atribuciones y condiciones de licencia. Consulte `LICENSE` y el historial Git para el detalle correspondiente.

---
**Desarrollo y mantenimiento actual:** JoseloFarias
