# Aurora para iPhone

Control remoto de **Aurora RGB** (el programa de iluminación del PC) desde el iPhone, por la WiFi de casa.
Color, efecto, brillo, velocidad, escenas, dispositivos y temperatura de la GPU, con una vista previa
animada que se mueve igual que los ventiladores.

## Cómo funciona

- Aurora (en el PC) abre un servidor en la red local, puerto **6750**:
  `GET /api/state`, `POST /api/state`, `POST /api/scene`, `POST /api/device`.
  Todo lo que llega se valida en el PC.
- La app consulta el estado cada 1,5 s mientras está en pantalla y agrupa los cambios al arrastrar.
- **Buscar mi PC** prueba el puerto 6750 en toda la subred del iPhone; también se puede escribir la IP
  (aparece arriba a la derecha en la ventana de Aurora).
- Sin PIN: cualquiera en tu WiFi podría cambiar las luces.

## Compilar (sin Mac)

Cada `git push` a `main` compila en GitHub Actions (`xcode-27`) con XcodeGen y publica `Aurora.ipa`
en **Releases** (IPA sin firmar).

## Instalar en el iPhone (Windows)

1. iPhone: **Ajustes → Privacidad y seguridad → Modo de desarrollador → Activar**.
2. PC: app **Dispositivos Apple** (o iTunes) y **[Sideloadly](https://sideloadly.io)**.
3. Descarga `Aurora.ipa` de Releases, arrástrala a Sideloadly, pon tu Apple ID e instala por cable.
4. Primera vez: **Ajustes → General → VPN y gestión de dispositivos** → confía en tu Apple ID.
5. Al abrir, acepta el permiso de **red local**.

Con Apple ID gratuito la app caduca a los 7 días (Sideloadly puede refrescarla).
