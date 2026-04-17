# HrContratPro Mobile

Application mobile Flutter — version mobile complète de HrContratPro.

## Architecture

```
lib/
├── main.dart                    # Point d'entrée + Router GoRouter
├── theme/
│   └── app_theme.dart           # Couleurs, ThemeData, StatusConfig
├── services/
│   ├── api_service.dart         # Tous les appels API Laravel
│   └── auth_service.dart        # Gestion session/rôle
├── widgets/
│   └── common_widgets.dart      # StatCard, EmployeeCard, LoadingWidget…
└── screens/
    ├── auth/
    │   ├── login_screen.dart    # Connexion
    │   └── config_screen.dart  # Configuration URL API
    ├── dashboard/
    │   └── dashboard_screen.dart # Tableau de bord (tous rôles)
    ├── employees/
    │   └── employees_screen.dart # Liste + détail employé
    ├── attendance/
    │   └── qr_scan_screen.dart  # Scanner QR + mode matricule
    ├── notifications/
    │   └── notifications_screen.dart
    └── profile/
        └── profile_screen.dart
```

## Installation

### Prérequis
- Flutter SDK 3.x
- Android Studio ou VS Code
- Appareil Android ou iOS (ou émulateur)

### Démarrer

```bash
flutter pub get
flutter run
```

### Build Android APK

```bash
flutter build apk --release --target-platform android-arm64
# → build/app/outputs/flutter-apk/app-release.apk
```

### Build iOS

```bash
flutter build ios --release
# Nécessite macOS + Xcode
```

## Modules implémentés

| Module | DG | RH | Employé |
|---|---|---|---|
| Authentification | ✅ | ✅ | ✅ |
| Config URL API | ✅ | ✅ | ✅ |
| Tableau de bord | ✅ | ✅ | ✅ |
| Liste employés | ✅ | ✅ | — |
| Détail employé | ✅ | ✅ | — |
| Scanner QR | ✅ | ✅ | ✅ |
| Pointage matricule | ✅ | ✅ | ✅ |
| Notifications | ✅ | ✅ | ✅ |
| Profil | ✅ | ✅ | ✅ |

## Navigation

- **DG** : Tableau → Employés → Pointage → Demandes → Notifications
- **RH** : Tableau → Employés → Pointage → Contrats → Notifications  
- **Employé** : Accueil → Scanner QR → Pointage → Contrats → Notifications

## Rôles

- `dg` → accès complet
- `rh` → gestion employés, contrats, pointage
- `employee` → self-service (ses contrats, ses congés, scanner QR)
