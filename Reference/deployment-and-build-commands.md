# Reference: Build, Test & Deployment Commands 🚀

---

## 🧪 Testing & Static Analysis

```bash
# Run all unit and widget tests
flutter test

# Run Dart linter checks
flutter analyze
```

---

## 🌐 Web Release (Vercel)

```bash
# Compile optimized static Web release
flutter build web --release

# Output path: build/web/
```

---

## 📱 Android Release APK

```bash
# Build signed Android Release APK
flutter build apk --release

# Output path: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🎨 App Icon Generation

```bash
# Regenerate launcher icons for Android & Web from logo/nummo.png
dart run flutter_launcher_icons
```

---

## 🧭 Obsidian Knowledge Vault & Graph View

```bash
# Launch interactive Obsidian Graph View directly
obsidian-graph

# Launch standard Obsidian app with Nummo vault
obsidian
```

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Reference/tech-stack-and-versions]]**
