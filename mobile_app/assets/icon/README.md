# App Icon

Place the launcher icon here as **`app_icon.png`** (1024×1024 recommended,
square PNG — the glowing violet lotus).

Then regenerate the Android launcher icons:

```bash
cd mobile_app
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
```

This overwrites the `mipmap-*` icons and the adaptive-icon XML using
`assets/icon/app_icon.png`, with a dark-violet (#12082E) adaptive background.
