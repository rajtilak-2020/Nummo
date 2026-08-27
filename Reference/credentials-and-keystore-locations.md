# Reference: Keystore & Configuration Locations 🔐

- **Policy**: No actual passwords, private keys, or API secrets are stored in this document.

---

## 📍 File Locations

### 1. Android Production Keystore
- **Location**: `android/app/nummo-release.jks`
- **Configuration**: `android/key.properties` (reads `storePassword`, `keyPassword`, `keyAlias`, `storeFile`)
- **Gradle Linkage**: `android/app/build.gradle.kts` references `key.properties` during `release` build type.

### 2. Google MCP & AI Configurations
- **MCP Config**: `.agents/mcp_config.json` and `.vscode/mcp.json`
- **Agent Guidelines**: `.agents/AGENTS.md` and `.agents/PRE_RELEASE_AUDIT.md`

### 3. Vercel Web Deployment
- **Config**: `vercel.json` (defines static build outputs from `build/web` and clean URL routing headers).

---

## 🔗 Related Notes
- **[[Home]]**
- **[[Structure]]**
- **[[Reference/deployment-and-build-commands]]**
