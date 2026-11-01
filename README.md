# MW LinkAlign

Aplicación Flutter de herramientas colaborativas para técnicos de telecomunicaciones. Comienza con la alineación de enlaces microondas y la documentación de trabajos de campo; después podrá incorporar herramientas de fibra óptica y coordinación de cuadrillas.

## Objetivo

Ayudar a técnicos de campo a coordinarse entre extremos de un enlace, compartir mediciones y evidencias, y documentar el trabajo incluso cuando alguno pierda temporalmente la conexión a Internet.

La aplicación será gratuita. La monetización inicial prevista es publicidad, sujeta a validar adopción, experiencia de uso y viabilidad real.

## Plataformas y tecnología

- **Aplicación:** Flutter y Dart para compartir la mayor parte del código entre plataformas.
- **Primera distribución:** PWA en iPhone y Android.
- **Android posterior:** APK, evaluando el mecanismo de empaquetado cuando llegue esa fase.
- **Backend previsto:** Python con FastAPI, sesiones temporales y WebSockets para colaboración en tiempo real.
- **Datos:** SQLite inicialmente; evaluar PostgreSQL si el uso y crecimiento lo justifican.
- **Mapas:** MapLibre.
- **Servidor previsto:** VPS existente con Nginx. La aplicación tendrá un servicio separado del portal que usa Authelia.
- **Perfiles de enlace:** integración con la API Python existente de MW Profile.

Las decisiones de infraestructura se validarán antes de implementar cada integración. No se plantea migrar el backend a Go sin evidencia de un problema de rendimiento.

## Módulos y alcance

### Primera etapa: microondas y colaboración

| Módulo | Comportamiento previsto |
| --- | --- |
| **MW Alignment** | Un técnico crea una sesión de enlace y ocupa Site A; otro se une como Site B mediante un código temporal o enlace compartido, por ejemplo por WhatsApp. La vinculación inicial no requiere registro. |
| **GPS & Azimuth** | Cada técnico captura o confirma las coordenadas GPS de su extremo. La app muestra precisión y calcula azimut y distancia entre sitios. |
| **Tilt** | Calcula el ángulo vertical geométrico con coordenadas, elevaciones y alturas de antena confirmadas. |
| **Live Alignment** | Los dos extremos ven los datos confirmados y actualizaciones del compañero en tiempo real. La brújula y los sensores del teléfono son orientativos; el ajuste final se confirma con las mediciones del radio. |
| **GeoCamera** | Captura evidencia con coordenadas y precisión GPS, fecha y hora, estación o enlace, identificador del técnico, orientación del teléfono cuando esté disponible y descripción opcional. |
| **Live Photo Exchange** | Comparte fotografías entre técnicos autorizados en la sesión, sin videollamada. |
| **Field Map** | Muestra en un mapa las fotografías georreferenciadas de la sesión. |
| **KMZ Export** | Exporta la sesión y empaqueta las fotografías dentro del KMZ para consultarlas en Google Earth sin depender de enlaces externos. |
| **MW Profile** | Envía o entrega los datos necesarios a la API existente para generar perfiles topográficos y de zona de Fresnel. |

### Módulos de fibra óptica

Se reutilizarán la cámara, geolocalización, mapa, almacenamiento y exportación KMZ de la plataforma.

| Módulo | Comportamiento previsto |
| --- | --- |
| **FO Route Tracker** | Registra rutas de fibra mediante GPS y permite exportarlas a KMZ. |
| **Pole Inspector** | Captura fotos georreferenciadas de postes y registra inspecciones. |
| **Maintenance Board** | Tablero tipo Kanban para reportar necesidades de mantenimiento mediante tarjetas con fotos, ubicación, descripción, estado y seguimiento. Los estados y permisos se definirán antes de implementar el flujo. |
| **Splice Manager** | Registra fusiones, bandejas y colores de fibra. |
| **FO Fault Locator** | Relaciona distancias de OTDR con ubicaciones sobre una ruta de fibra. |
| **FO Loss Calculator** | Calcula presupuestos de pérdida óptica. |
| **Optical Power Test** | Registra mediciones de potencia y aceptación. |
| **Cable Inventory** | Documenta mufas, reservas, ODF y cables. |

### Crew Assist

Antes del lanzamiento público se requiere una función de seguridad para compartir ubicación, ruta y actividad con compañeros o supervisores autorizados durante una intervención. El técnico debe iniciar y detener explícitamente el seguimiento y ver claramente cuándo está activo. No se contempla seguimiento permanente.

### Fuera del alcance inicial

- Evaluación de dificultad del enlace o de alineamiento.
- Cálculo de pérdidas de antena.
- Comunidad y bolsa de empleos.

## Flujo previsto de una sesión de microondas

1. Site A crea una sesión.
2. La aplicación genera un código o enlace temporal para invitar a Site B.
3. Site B se vincula a la sesión sin crear una cuenta en la primera etapa.
4. Cada técnico captura las coordenadas GPS y revisa su precisión; las elevaciones y alturas necesarias para el tilt se confirman.
5. La aplicación calcula y comparte azimut, distancia y tilt geométrico entre los sitios.
6. Cada técnico usa los valores como referencia mientras alinea la antena y confirma el resultado con las mediciones reales del radio.
7. El equipo intercambia fotos, notas y evidencias; estas aparecen asociadas a la sesión y en el mapa.
8. La sesión puede exportarse con sus fotografías en un KMZ.

## Datos, sincronización y permisos

- Las actualizaciones de sesión se sincronizan en tiempo real mientras haya conexión.
- Si se pierde Internet, la app conserva localmente las fotografías y cambios pendientes para sincronizarlos al recuperar conexión, sujeto al espacio disponible y a los permisos del dispositivo.
- Las sesiones de enlace se protegen mediante códigos temporales y acceso autorizado a sus participantes.
- La ubicación de Crew Assist solo se comparte tras una acción explícita del técnico y mientras el seguimiento esté activo.
- Se definirán retención, eliminación, autenticación de supervisores y protección de datos antes de abrir el servicio al público.

## Estructura prevista del código

```text
lib/
  app/                 configuración y composición de la aplicación
  core/                utilidades y servicios comunes
  shared/              componentes reutilizables
  features/
    mw_alignment/      sesiones, GPS, cálculos y estado en vivo
    geo_camera/        captura y metadatos de fotos
    field_map/         mapa de sitios y evidencias
    mw_profile/        integración con perfiles de enlace
    fiber_tools/       herramientas de fibra óptica
    maintenance/       reportes y tablero Kanban
    crew_assist/       ubicación compartida durante intervenciones
test/
  features/            pruebas agrupadas por módulo
```

La estructura es una guía inicial. Las carpetas no implican que todos los módulos estén implementados. La lógica se añadirá por etapas y se documentará junto con sus decisiones de diseño.

## Plan de desarrollo

1. Preparar la PWA y las capacidades base de cámara, ubicación y sensores.
2. Crear sesiones Site A/Site B y cálculo colaborativo de alineamiento.
3. Añadir GeoCamera, intercambio de fotos y sincronización pendiente.
4. Añadir mapa de evidencias y exportación KMZ autocontenida.
5. Integrar MW Profile y validar el flujo en campo.
6. Implementar Crew Assist con controles de consentimiento antes del lanzamiento público.
7. Empaquetar APK Android, publicar y evaluar monetización.
8. Incorporar herramientas de fibra óptica, incluyendo registro de postes y tablero de mantenimiento.

## Desarrollo y comprobaciones

Requiere Flutter estable y Dart (incluido en Flutter).

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

GitHub Actions instala Flutter en sus runners para analizar, probar y compilar la PWA. La compilación web se genera en `build/web`. La publicación en una URL requiere configurar un destino de hosting; compilar por sí solo no publica la aplicación.
