# Plataforma de herramientas de campo para telecomunicaciones

## Visión del producto

Aplicación multiplataforma hecha completamente con Flutter y Dart para facilitar el trabajo colaborativo de técnicos de telecomunicaciones. El primer producto será **MW LinkAlign**, un módulo de alineación de enlaces microondas. La plataforma tendrá un nombre general que también abarque módulos futuros de fibra óptica; el nombre de la plataforma queda pendiente de definir.

La aplicación debe ser útil a técnicos de campo de distintas empresas. El objetivo es que reduzca coordinación manual, ayude a documentar intervenciones y haga accesibles herramientas prácticas desde el teléfono. La prioridad del producto es la utilidad en campo y la recomendación entre técnicos.

## Usuarios y escenarios

- Dos técnicos trabajan en extremos Site A y Site B de un enlace microondas.
- Un técnico de fibra documenta postes, rutas, fusiones, mediciones y fallas.
- Una cuadrilla crea reportes de mantenimiento con fotos y ubicación para que el equipo los clasifique y atienda.
- Un supervisor autorizado coordina una intervención y, si el técnico lo activa, recibe su ubicación durante el trabajo.

## Plataforma y arquitectura prevista

### Aplicación cliente

- Flutter y Dart para toda la aplicación y para compartir código de negocio y presentación.
- Primera distribución: PWA instalable desde Safari en iPhone y como PWA en Android.
- Más adelante: empaquetado de Android como APK. Se evaluará Capacitor, Bubblewrap u otra opción compatible con la arquitectura elegida. No se planifica distribución nativa iOS inicial.
- La app deberá considerar permisos de GPS, cámara, orientación y almacenamiento de forma explícita. La disponibilidad de sensores y ejecución en segundo plano varía por navegador y plataforma y se comprobará en dispositivos reales.

### Servicios

| Área | Diseño previsto |
| --- | --- |
| API | Python y FastAPI, desplegados en un servicio independiente de la aplicación web. |
| Colaboración | Sesiones temporales con código o enlace de invitación y WebSockets para actualizaciones en vivo. |
| Persistencia | SQLite para el comienzo; evaluar PostgreSQL cuando crecimiento, concurrencia u operación lo justifiquen. |
| Mapas | MapLibre para representación de sitios, trazas y fotografías georreferenciadas. |
| Perfiles de radioenlace | Integrar la API Python existente de MW Profile para perfil topográfico y zona de Fresnel. |
| Fotos | Compresión en el dispositivo, almacenamiento temporal, metadatos, cola de pendientes y sincronización cuando regrese la conectividad. |
| Hosting | VPS existente con Nginx; servicio y dominio separados del portal protegido mediante Authelia. |

No se migrará Python a Go salvo que mediciones de rendimiento demuestren una necesidad. Los detalles de autenticación, expiración, respaldo, retención y protección de datos se concretarán antes de publicar servicios con datos de usuarios.

## Módulo inicial: MW LinkAlign

### Beta funcional en curso

La siguiente beta incorpora una pantalla de arranque roja con el monograma K/A de KenLab y luego abre el menú de herramientas. La primera cámara y pantalla de alineación son flujos locales de prueba:

- **Cámara de campo:** vista en vivo de la cámara trasera, lectura de GPS, altitud y precisión, fecha/hora y descripción opcional. Al capturar, incrusta esos datos en la parte inferior de la imagen y permite descargarla como JPG. Si el GPS no está permitido, la foto puede capturarse, pero se identifica que no tiene ubicación.
- **Alineación beta:** abre la cámara y consulta la ubicación de Site A. El técnico introduce latitud/longitud de Site B; la app calcula azimut y distancia, dibuja una guía direccional con el rumbo magnético del teléfono cuando está disponible, e incluye inclinómetro del dispositivo y tilt geométrico.
- Para calcular el tilt de enlace se usa la altitud capturada para A y se permite introducir la elevación del terreno y la altura de antena en ambos extremos. Esos datos del teléfono son aproximados y deben confirmarse.
- El control **Conectar técnico** muestra el punto de entrada al flujo colaborativo, pero no conecta todavía dos dispositivos: requiere implementar y desplegar la API de sesiones y WebSockets descrita en la arquitectura.
- Esta beta no sincroniza ni conserva una biblioteca de fotos dentro de la app. Los JPG se descargan al dispositivo. El mapa, KMZ, perfil topográfico y el tablero de mantenimiento siguen pendientes.

En PWA, cámara, geolocalización y sensores dependen del navegador, hardware y permisos. El sitio debe abrirse con HTTPS; el magnetómetro no está disponible o calibrado en todos los teléfonos. Cerca de torres y estructuras metálicas puede marcar rumbos incorrectos. La guía del teléfono nunca sustituye la medición final del radio.

### Flujo de MW Alignment planeado

### Sesión y colaboración Site A / Site B

1. El técnico A abre la aplicación y crea una sesión de alineación.
2. La sesión asigna a A el extremo Site A y genera un código temporal o enlace para compartir, por ejemplo mediante WhatsApp.
3. El técnico B abre el enlace o ingresa el código y se une como Site B. En la primera etapa, la participación no exige registro.
4. La app muestra el estado de conexión de ambos participantes y sincroniza las medidas y fotos autorizadas para esa sesión.
5. Al finalizar, los técnicos conservan o exportan la documentación de su trabajo según las reglas de retención que se definan.

El código debe limitar el acceso a la sesión y tener una política de expiración. El mecanismo concreto y la opción de recuperación de sesión quedan por diseñar.

### GPS, distancia, azimut y tilt

Cada técnico obtiene la ubicación del teléfono en su extremo y debe poder revisar y confirmar la coordenada antes de compartirla. La lectura incluye precisión horizontal y hora de captura. El producto debe distinguir una ubicación capturada de una ubicación confirmada.

Con las coordenadas de ambos extremos se calcula la distancia y el azimut inicial desde A hacia B. También se muestra el azimut inverso para el extremo opuesto. Como referencia ilustrativa, si A apunta a 125.4°, el rumbo inverso de B es aproximadamente 305.4°; los datos reales siempre se calculan a partir de las ubicaciones.

El tilt geométrico usa las elevaciones de terreno y las alturas de las antenas en ambos extremos. La app debe solicitar o recibir esas alturas y mostrar qué datos se usaron. Las coordenadas GPS del teléfono por sí solas no garantizan elevación precisa; se debe permitir revisar la elevación y documentar su fuente. Las correcciones por curvatura terrestre, refracción u otros parámetros de ingeniería se definirán con el flujo de MW Profile y validación técnica.

La orientación del teléfono y la brújula se presentan como guía aproximada. El metal de torres y estructuras puede perturbar sensores magnéticos. El ajuste final se valida con los niveles y mediciones del radio, no con el sensor del teléfono.

### Live Alignment

Ambos técnicos ven la información de los dos extremos y sus cambios recientes en una sesión compartida. La pantalla de cada sitio debe priorizar el azimut objetivo, el sentido del enlace, la calidad/precisión de la ubicación, el tilt objetivo y el estado de conexión. Los valores de demostración nunca se presentan como mediciones reales.

### GeoCamera y fotos en vivo

La cámara de campo registra evidencia de instalación, mantenimiento y fibra. Cada foto puede incluir:

- coordenadas GPS y precisión horizontal;
- fecha y hora de captura;
- nombre de estación, enlace o activo relacionado;
- identificador visible del técnico;
- azimut e inclinación del teléfono si los sensores están disponibles;
- descripción opcional.

El usuario revisa los metadatos antes de guardar. Las imágenes se comprimen para reducir consumo de datos y almacenamiento. Las fotos autorizadas llegan a los participantes de la sesión en tiempo real, sin videollamada, y se asocian con su ubicación para mostrarse en Field Map.

Sin Internet, la aplicación conserva fotos y cambios pendientes localmente y los sincroniza al volver la conexión, teniendo en cuenta el espacio libre y los permisos del dispositivo. Deben mostrarse claramente estados como pendiente, sincronizando, enviado y error para evitar creer que una evidencia ya fue recibida cuando no lo fue.

### Field Map y KMZ

Field Map representa la sesión, los extremos y las fotos georreferenciadas. Al seleccionar una foto se consulta su imagen y metadatos. KMZ Export empaqueta las imágenes dentro del archivo junto con sus marcadores y datos para abrirlo en Google Earth sin depender de enlaces externos. La exportación debe identificar coordenadas inválidas o fotos sin ubicación y permitir al usuario decidir cómo manejarlas.

### MW Profile

El módulo integrará la API existente de MW Profile para generar perfil topográfico y zona de Fresnel. El contrato API, los parámetros, tratamiento de errores, unidades y representación de resultados se revisarán antes de implementar el cliente. La app vinculará el perfil a la sesión de enlace.

## Módulos de fibra óptica

Estos módulos son una expansión de la plataforma. Reutilizarán GPS, GeoCamera, mapas, almacenamiento, sincronización y KMZ donde tenga sentido.

| Herramienta | Alcance previsto |
| --- | --- |
| **FO Route Tracker** | Capturar una ruta de fibra con GPS y exportar el recorrido a KMZ. |
| **Pole Inspector** | Registrar postes con ubicación, fotografías y datos de inspección. |
| **Maintenance Board** | Crear reportes de mantenimiento con fotos georreferenciadas, poste/activo relacionado, descripción, prioridad, autor, fechas y estado. Presentarlos como tablero Kanban para que el equipo vea pendientes, trabajos en curso y resueltos. Columnas, permisos, asignación, comentarios e historial quedan por definir antes de su implementación. |
| **Splice Manager** | Documentar fusiones, bandejas y colores de fibras. |
| **FO Fault Locator** | Relacionar una distancia de falla medida por OTDR con una ubicación sobre la ruta registrada. |
| **FO Loss Calculator** | Calcular el presupuesto de pérdidas ópticas del enlace a partir de los componentes y valores de entrada acordados. |
| **Optical Power Test** | Registrar pruebas de potencia óptica y aceptación. |
| **Cable Inventory** | Documentar cables, mufas, reservas y ODF. |

## Crew Assist y seguridad del técnico

Crew Assist es obligatorio antes de lanzar públicamente la aplicación, aunque no pertenece a la primera etapa de MW LinkAlign. Un técnico podrá iniciar el envío de ubicación y ruta a compañeros o supervisores autorizados durante una intervención y detenerlo cuando termine. La app mantendrá un indicador visible mientras comparta ubicación y pedirá permisos apropiados.

El propósito es seguridad y coordinación, no vigilancia permanente. No debe existir seguimiento oculto ni continuo sin una acción explícita. Se definirán los roles autorizados, la duración, la retención y el acceso a ubicaciones antes de publicar esta función.

## Navegación conceptual

La pantalla inicial agrupará herramientas de campo. En la primera versión priorizará “Alineación microondas” y el acceso a las sesiones recientes. Las secciones futuras podrán incluir “Fibra óptica”, “Mantenimiento” y “Crew Assist”. Los nombres finales, navegación y diseño visual se definirán antes de implementar interfaces completas.

## Modelo de negocio

La aplicación será gratuita y el modelo inicial prevé publicidad de Google como única fuente de monetización. Cálculo de referencia, no garantía de ingresos:

| Supuesto | Valor |
| --- | ---: |
| Intervenciones por año | 5,000 |
| Técnicos por intervención | 2 |
| Participaciones de técnicos por año | 10,000 |
| Impresiones por participación (supuesto) | 5 |
| Impresiones anuales estimadas | 50,000 |
| RPM usado como referencia | US$1.50 |
| Ingreso anual ilustrativo | US$75 |

El ingreso real depende de adopción, impresiones efectivamente monetizadas, región, formatos y políticas de la red publicitaria. Las herramientas de fibra buscan aumentar la frecuencia de uso, sin desplazar el objetivo principal de utilidad para técnicos.

## Funciones expresamente fuera del alcance inicial

- Link Difficulty o estimación de dificultad de alineamiento.
- Antenna Loss o cálculo de pérdida de antena.
- Comunidad de usuarios.
- Bolsa de empleos.

## Plan de desarrollo

| Etapa | Alcance |
| --- | --- |
| 1 | PWA Flutter, permisos y capacidades base de cámara, GPS y sensores. |
| 2 | Sesiones Site A/Site B, vinculación y cálculos colaborativos de alineamiento. |
| 3 | GeoCamera, intercambio de fotografías, almacenamiento local y sincronización. |
| 4 | Field Map y exportación KMZ con fotos incrustadas. |
| 5 | Integración con MW Profile y pruebas de campo. |
| 6 | Crew Assist, consentimiento y controles visibles antes de lanzamiento público. |
| 7 | APK Android, publicación y evaluación de publicidad. |
| 8 | Expansión de herramientas de fibra, postes y tablero Kanban de mantenimiento. |

La estimación inicial de unas dos semanas de desarrollo dedicado se refiere a una PWA colaborativa básica y es orientativa. Fotos, operación sin conexión, exportación, controles de seguridad, integración API y validación en campo requieren planificación y pruebas adicionales.

## Estructura inicial del código

```text
lib/
  app/                         composición de la app y navegación
  core/                        configuración y servicios comunes
    export/                    exportación KMZ
    location/                  ubicación GPS
    maps/                      servicios de mapas
    network/                   conectividad
    sensors/                   orientación y sensores
    storage/                   almacenamiento local
    sync/                      cola de sincronización
  shared/                      modelos y componentes comunes
  features/
    mw_alignment/              sesión, mediciones, cálculos y colaboración
    geo_camera/                 cámara y metadatos fotográficos
    field_map/                  mapa de evidencias
    mw_profile/                 integración con MW Profile
    fiber_tools/                herramientas de fibra agrupadas por actividad
    maintenance/                reportes y tablero Kanban
    crew_assist/                ubicación compartida durante una intervención
test/
  features/                     pruebas agrupadas por módulo
```

Los archivos de módulo se crean como puntos de partida vacíos. No contienen todavía reglas de negocio, interfaces funcionales ni integraciones. Se implementarán incrementalmente siguiendo este documento y se ajustará la estructura si las decisiones técnicas lo requieren.

## Desarrollo y CI

Se necesita Flutter estable; Dart viene incluido en el SDK.

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

GitHub Actions instala Flutter temporalmente en sus runners, descarga las dependencias, ejecuta análisis y pruebas y compila la PWA. El artefacto web se genera en `build/web`. Compilar no publica la aplicación; la publicación requerirá configurar hosting y permisos correspondientes.
