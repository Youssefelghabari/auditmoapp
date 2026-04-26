# 📋 Audit Commercial — Application Flutter

Application Android/iOS d'inspection et de conformité commerciale avec :
- 📸 Photo du commerce + GPS
- 📸 Photo optionnelle par point d'audit  
- 💾 Persistance SQLite complète
- 📄 Export PDF du rapport
- 🗂 Import/export de modèles d'audit (JSON ou CSV)
- ✏️ Éditeur de modèles intégré

---

## 🚀 Installation

### 1. Prérequis
- Flutter SDK ≥ 3.10 (https://flutter.dev/docs/get-started/install)
- Android Studio + SDK Android API 21+
- Xcode (pour iOS uniquement)

### 2. Cloner et installer les dépendances
```bash
cd audit_app
flutter pub get
```

### 3. Lancer l'application
```bash
# Android (émulateur ou appareil connecté)
flutter run

# iOS
flutter run -d ios
```

### 4. Build APK de production
```bash
flutter build apk --release
# L'APK se trouve dans build/app/outputs/flutter-apk/app-release.apk
```

---

## 📁 Structure du projet

```
lib/
├── main.dart                      # Point d'entrée
├── models/
│   ├── models.dart                # Commerce, AuditSession, AuditResponse, AuditCategory
│   └── audit_template.dart        # AuditTemplate, TemplateCategory, TemplatePoint
├── services/
│   ├── database_service.dart      # SQLite : commerces, sessions, réponses
│   ├── template_service.dart      # Gestion des modèles + import/export
│   ├── location_service.dart      # GPS + géocodage inverse
│   └── pdf_service.dart           # Génération du rapport PDF
└── screens/
    ├── home_screen.dart            # Liste des commerces
    ├── commerce_form_screen.dart   # Création/édition d'un commerce (photo + GPS)
    ├── audit_screen.dart           # Écran d'audit (OUI/NON/N/A + photo + note)
    ├── report_screen.dart          # Rapport de conformité
    ├── template_list_screen.dart   # Liste des modèles d'audit
    ├── template_import_screen.dart # Import + prévisualisation + aide formats
    └── template_editor_screen.dart # Éditeur de modèle (catégories + points)
```

---

## 🗂 Formats d'import supportés

### JSON — Format natif (recommandé)
```json
{
  "name": "Mon modèle d'audit",
  "description": "Description optionnelle",
  "version": "1.0",
  "categories": [
    {
      "id": "cat1",
      "label": "Sécurité",
      "icon": "🔒",
      "points": [
        {
          "id": "p1",
          "label": "Extincteurs vérifiés",
          "description": "Date de vérification < 1 an",
          "legal_ref": "Art. R4227-28"
        },
        { "id": "p2", "label": "Issues de secours dégagées" }
      ]
    }
  ]
}
```

### JSON — Format sections (simplifié)
```json
{
  "name": "Mon audit",
  "sections": [
    {
      "title": "Sécurité",
      "items": ["Extincteurs vérifiés", "Issues dégagées"]
    }
  ]
}
```

### JSON — Format items plat
```json
{
  "name": "Mon audit",
  "items": [
    { "category": "Sécurité", "label": "Extincteurs vérifiés", "description": "..." },
    { "category": "Affichage", "label": "Prix affichés" }
  ]
}
```

### CSV (séparateur `,` ou `;`)
```csv
Catégorie,Point,Description,Référence légale
Sécurité,Extincteurs vérifiés,Date < 1 an,Art. R4227-28
Sécurité,Issues dégagées,,
Affichage,Prix affichés,,
Affichage,Horaires visibles,,
```
- La **première ligne** peut être un en-tête (détection automatique)
- Les colonnes **Description** et **Référence légale** sont optionnelles
- Si une seule colonne : tous les points dans une catégorie unique

### TXT — Liste simple
```
Extincteurs vérifiés
Issues de secours dégagées
Prix affichés
Horaires d'ouverture visibles
```

---

## 🔧 Dépendances principales

| Package | Usage |
|---|---|
| `sqflite` | Base de données SQLite locale |
| `image_picker` | Caméra et galerie photo |
| `geolocator` | Position GPS |
| `geocoding` | Adresse depuis coordonnées |
| `file_picker` | Import de fichiers JSON/CSV |
| `pdf` + `printing` | Génération et partage PDF |
| `share_plus` | Partage de fichiers |
| `flutter_map` | Carte interactive |
| `uuid` | Génération d'identifiants |
| `intl` | Formatage de dates en français |

---

## 📱 Permissions Android requises

Déclarées dans `android/app/src/main/AndroidManifest.xml` :
- `CAMERA` — prise de photos
- `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` — GPS
- `READ_EXTERNAL_STORAGE` / `READ_MEDIA_IMAGES` — galerie photos
- `INTERNET` — tuiles de carte

---

## 📦 Données stockées

Toutes les données sont stockées **localement** dans SQLite (`audit_commercial.db`) :

| Table | Contenu |
|---|---|
| `commerces` | Nom, adresse, catégorie, GPS, photo, dates |
| `audit_sessions` | Lien commerce, auditeur, date, statut |
| `audit_responses` | Réponse OUI/NON/NA, note, photo, par point |
| `audit_templates` | Modèles d'audit personnalisés (JSON) |
| `commerce_templates` | Modèle actif par commerce |
