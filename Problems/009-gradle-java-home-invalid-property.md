# 009: Invalid org.gradle.java.home in gradle.properties

---

- **Status**: ✅ Resolved
- **Date**: 2026-09-04
- **Severity**: Medium (Android Release Build Failure)
- **Component**: `android/gradle.properties`, Flutter Android SDK Config
- **Tags**: #android #gradle #jdk #java17 #build-failure

---

## 🔍 Symptom
Executing `flutter build apk --release` threw the following Gradle exception:

```
FAILURE: Build failed with an exception.

* What went wrong:
Value '/usr/lib/jvm/java-17-openjdk' given for org.gradle.java.home Gradle property is invalid (Java home supplied is invalid)
```

---

## 🔬 Root Cause Analysis
1. `org.gradle.java.home=/usr/lib/jvm/java-17-openjdk` had been hardcoded directly in `android/gradle.properties` to guard against an incompatible default JDK 26 in the VS Code Pleiades extension environment.
2. Hardcoding an absolute host filesystem path inside project-level `gradle.properties` is fragile across environments, different Linux distributions (e.g. Debian/Ubuntu uses `/usr/lib/jvm/java-17-openjdk-amd64`), containerized subshells, and varying terminal permissions where Gradle's `JavaProbe` can fail to evaluate the hardcoded path.
3. When Gradle fails its JVM probe for `org.gradle.java.home`, it halts immediately with `(Java home supplied is invalid)`.

---

## 🛠️ Solution & Verification
1. **Configured Flutter Global JDK Directory**:
   Configured Flutter's Android toolchain globally to use OpenJDK 17:
   ```bash
   flutter config --jdk-dir="/usr/lib/jvm/java-17-openjdk"
   ```
   `flutter doctor -v` confirms:
   ```
   • Java binary at: /usr/lib/jvm/java-17-openjdk/bin/java
     This JDK is specified in your Flutter configuration.
   • Java version OpenJDK Runtime Environment (build 17.0.20.1+1)
   ```
   Flutter now automatically injects the verified Java 17 path into all Gradle invocations without requiring a hardcoded path in Git.

2. **Removed Hardcoded Path from `android/gradle.properties`**:
   Commented out `org.gradle.java.home` in `android/gradle.properties`, relying on Flutter's managed `--jdk-dir` setting.

3. **Build Target Verification**:
   - `flutter build apk --release` compiled successfully:
     `✓ Built build/app/outputs/flutter-apk/app-release.apk (63.3MB)`.
   - `flutter build web --release` compiled successfully:
     `✓ Built build/web`.

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Progress/2026-09-session-log]]**
- **[[Reference/deployment-and-build-commands]]**
