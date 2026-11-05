# ✂️ Draw & Cut - Android Game

A fast-paced, neon-cyberpunk arcade cutting puzzle game for Android built with high-performance HTML5 Canvas & Web Audio wrapped in an optimized native Android WebView.

---

## 🚀 Automated Build & Release (CI/CD Pipeline)

This project features a fully automated production build, code-signing, versioning, and publishing pipeline both **locally** and in the **cloud** via **GitHub Actions**.

---

### 🌐 Method 1: Cloud Automation via GitHub Actions (Zero Local Setup)

Whenever you are ready to publish a new release:

#### Option A: Automatic via Git Tag (Recommended)
Simply tag your release and push:
```bash
git tag v1.2
git push origin v1.2
```
GitHub Actions will automatically:
1. Compile signed production APK and Google Play Store App Bundle (`.aab`).
2. Generate SHA-256 integrity checksums.
3. Create an official GitHub Release with downloadable assets attached.
4. (Optional) Upload the bundle directly to Google Play Console if the service account secret is present.

#### Option B: 1-Click Manual Trigger via GitHub UI
1. Go to your repository on GitHub: [`https://github.com/ssilu07/Draw-and-Cut`](https://github.com/ssilu07/Draw-and-Cut)
2. Open the **Actions** tab.
3. Select **Build & Release Android App** from the left sidebar.
4. Click **Run workflow** -> Select target track (`internal`, `alpha`, `beta`, `production`) -> Click **Run workflow**.

---

### 🔑 Setting Up Production Signing Secrets (1-Minute Setup)

To allow GitHub Actions to sign your releases with your official production key:

1. **Run the helper script on your PC:**
   ```powershell
   .\scripts\export-keystore-secret.ps1
   ```
   *(This automatically reads your production keystore and copies the Base64 string directly to your clipboard!)*

2. **Add secrets in GitHub:**
   - Go to [GitHub Secrets Settings](https://github.com/ssilu07/Draw-and-Cut/settings/secrets/actions)
   - Click **New repository secret** and add:
     - `KEYSTORE_BASE64` ➜ Paste your clipboard (`Ctrl + V`)
     - `KEYSTORE_PASSWORD` ➜ `8750257510`
     - `KEY_ALIAS` ➜ `key0`
     - `KEY_PASSWORD` ➜ `8750257510`
     - *(Optional)* `PLAY_STORE_JSON_KEY` ➜ Google Play Service Account JSON for automatic Play Store release.

> **Note:** If `KEYSTORE_BASE64` is not configured, GitHub Actions automatically generates a temporary fallback signing key so CI builds will never fail!

---

### 💻 Method 2: Local 1-Click Release Script

You can also build, package, increment version, and push directly from your computer:

#### Windows Double-Click:
- Double-click [`release.bat`](file:///d:/htmlgames/DrawAndCut/release.bat).

#### PowerShell:
```powershell
# Interactive mode (prompts for version bump):
.\scripts\release.ps1

# Or specify bump type directly:
.\scripts\release.ps1 -Bump minor    # 1.1 -> 1.2
.\scripts\release.ps1 -Bump patch    # 1.1 -> 1.1.1
.\scripts\release.ps1 -NewVersion "2.0"

# Local build only without committing or pushing:
.\scripts\release.ps1 -Bump none -SkipPush
```

**What the local release script does automatically:**
1. Auto-increments `versionCode` and `versionName` in `app/build.gradle`.
2. Builds optimized, minified, and signed `assembleProdRelease` (.apk) and `bundleProdRelease` (.aab).
3. Packages outputs into `release-outputs/v<version>/` with version stamps.
4. Computes SHA-256 checksums in `checksums.txt`.
5. Commits `app/build.gradle`, tags `v<version>`, and pushes to GitHub (triggering the online GitHub Release).

---

### 🧪 Fast Local Verification Script

To quickly test compilation and build health without making a release:
```powershell
# Test production release variants
.\scripts\test-build.ps1 -Target prodRelease

# Test dev debug build
.\scripts\test-build.ps1 -Target devDebug

# Test all variants
.\scripts\test-build.ps1 -Target all
```

---

## 📁 Project Architecture

```
DrawAndCut/
├── .github/
│   └── workflows/
│       └── release.yml          # GitHub Actions CI/CD pipeline
├── app/
│   ├── build.gradle             # Android build & dynamic signing configuration
│   ├── proguard-rules.pro       # R8 & ProGuard code shrinking rules
│   ├── keystore/                # Local release keystore (git-ignored)
│   └── src/main/
│       ├── AndroidManifest.xml  # Permissions (Internet, Vibrate, etc.)
│       ├── java/com/royals/drawandcut/
│       │   └── MainActivity.java# Native wrapper, AdMob & JS Interface
│       └── assets/
│           └── game.html        # High-performance HTML5 Canvas arcade game
├── gradle/wrapper/              # Gradle 8.5 wrapper binaries & properties
├── scripts/
│   ├── export-keystore-secret.ps1 # Keystore to Base64 export helper
│   ├── release.ps1              # Local build, package, and git release script
│   └── test-build.ps1           # Quick build sanity checker
├── build.gradle                 # Project-level Gradle config
├── gradle.properties            # JVM tuning and compileSdk suppression
├── release.bat                  # 1-Click Windows release launcher
└── README.md                    # Documentation
```

---

## 🎮 Game Highlights & Features

- **Core Gameplay**: Classic Qix/Volfied cutting mechanics with neon cyberpunk visuals.
- **Boss Fights**: Incoming Titan Bosses with unique attack patterns and weak points.
- **Haptic Feedback**: Native vibration integrated seamlessly via `@JavascriptInterface`.
- **Sound Engine**: Procedural Web Audio FX for cuts, hits, combos, and victory.
- **Micro-Interactions**: Particle bursts, frozen screen vignette, frenzy speedlines, confetti celebrations.
- **Monetization**: Google AdMob integration with Banner, Interstitial, and Rewarded Ads.
- **Offline First**: All assets, scripts, and audio synthesizers bundled inside `app/src/main/assets/game.html`.
