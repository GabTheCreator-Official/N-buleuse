# Nébuleuse (iOS, SwiftUI + HealthKit)

App iPhone gratuite qui lit le sommeil enregistré par votre Apple Watch dans Apple Santé :
- durée et phases (profond / léger / paradoxal / éveil) ;
- objectif de sommeil réglable, avec anneau de progression ;
- score de régularité (0–100) et heure de coucher moyenne sur 7 nuits ;
- widget (petit format) : dernière nuit et objectif.

Aucune app Watch à développer : la montre écrit déjà le sommeil dans Santé, l'iPhone le lit.

## Compatibilité Apple Watch

- Séries 3 à 12 : la durée de sommeil fonctionne dès que le suivi du sommeil est activé sur la montre.
- Phases de sommeil : watchOS 9 ou plus, donc Series 4 et suivantes. La Series 3 reste limitée
  à watchOS 8 : l'app affiche alors la durée seule.

## Option A : avec un Mac (le plus simple)

1. Installez XcodeGen : `brew install xcodegen`.
2. Dans ce dossier : `xcodegen generate`, puis ouvrez `SommeilTracker.xcodeproj`.
3. Réglez votre Team (Apple ID gratuit) dans Signing & Capabilities pour les deux cibles,
   et changez `com.example` par un identifiant à vous (aussi dans `project.yml`, App Group compris).
4. Branchez l'iPhone, Run.

## Option B : sans Mac (PC Windows)

Principe : un Mac loué par GitHub compile l'app gratuitement, puis Sideloadly (sur votre PC)
la signe avec votre Apple ID et l'installe sur l'iPhone.

1. Créez un compte gratuit sur github.com, puis un dépôt **public** (les minutes de build macOS
   sont gratuites pour les dépôts publics) et envoyez-y tout ce dossier (bouton « Add file › Upload files »,
   y compris le dossier `.github`).
2. Onglet **Actions** › « Build IPA » › **Run workflow**. Attendez environ 5 à 10 minutes.
3. Ouvrez l'exécution terminée, téléchargez l'artefact **SommeilTracker-ipa** (un zip contenant le `.ipa`).
4. Sur le PC : installez iTunes et iCloud depuis apple.com (pas depuis le Microsoft Store),
   puis Sideloadly (sideloadly.io).
5. Branchez l'iPhone, activez Réglages › Confidentialité et sécurité › **Mode développeur**.
6. Dans Sideloadly : glissez le `.ipa`, entrez votre Apple ID, cliquez Start.
7. Sur l'iPhone : Réglages › Général › VPN et gestion de l'appareil › faites confiance à votre profil.

À savoir :
- Avec un Apple ID gratuit, l'app expire après 7 jours : refaites l'étape 6 chaque semaine.
- HealthKit et les App Groups (nécessaires à Santé et au widget) peuvent être refusés ou retirés
  par un compte gratuit selon l'outil de signature. Je n'ai pas pu tester sur un vrai iPhone.
  Si l'app s'ouvre mais ne lit rien, ou si le widget reste vide, c'est la cause la plus probable ;
  la solution fiable est alors l'Apple Developer Program (99 $/an).
- Alternative payante au besoin : louer un Mac à distance (MacinCloud, etc.) et suivre l'option A.

## Publication

App Store ou TestFlight : Apple Developer Program, 99 $/an. Pas de contournement gratuit.
