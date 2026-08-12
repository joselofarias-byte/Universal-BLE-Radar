# SignalRadar / Universal BLE Radar — JoseloFarias fork

Proyecto Android/Flutter mantenido por **JoseloFarias** para detección, análisis y localización heurística de dispositivos Bluetooth Low Energy mediante intensidad de señal y sensores del teléfono.

## Meta

Convertir el escaneo BLE en una herramienta práctica de localización: seleccionar un objetivo, estimar proximidad y orientar al usuario mediante RSSI, rumbo y fusión de sensores sin requerir hardware UWB.

## Objetivos técnicos

- Escaneo BLE continuo mediante una capa desacoplada.
- Clasificación de proximidad por RSSI.
- Suavizado y análisis de tendencia para reducir ruido.
- Fusión de señal con magnetómetro/sensores de movimiento.
- Radar sectorial y seguimiento de un dispositivo objetivo.
- Feedback visual y háptico durante la búsqueda.
- Privacidad local y ausencia de telemetría innecesaria.

## Estado

**Desarrollo activo.** El objetivo es avanzar el algoritmo, la precisión y la UX de búsqueda en cada ciclo, además de mantener compatibilidad y builds.

## Desarrollo

```bash
git clone https://github.com/joselofarias-byte/Universal-BLE-Radar.git
cd Universal-BLE-Radar
flutter pub get
flutter analyze
flutter test
flutter build apk
```

## Origen y licencia

Fork basado en `erogluyusuf/Universal-BLE-Radar`. Se conservan las atribuciones y licencia del proyecto original; consulte `LICENSE` y el historial Git.

---
**Mantenimiento del fork:** JoseloFarias
