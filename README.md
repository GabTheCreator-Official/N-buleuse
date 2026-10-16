# Nébuleuse (iOS, SwiftUI)

App iPhone gratuite qui affiche votre sommeil, lu dans Apple Santé :
- durée et phases (profond / léger / paradoxal / éveil), si Santé les contient ;
- objectif de sommeil réglable, avec anneau de progression ;
- score de régularité (0–100) et heure de coucher moyenne sur 7 nuits ;
- widget (petit format) : dernière nuit et objectif.

## Comment les données arrivent

Un Apple ID gratuit n'autorise pas l'accès direct à Santé (HealthKit). L'app reçoit donc le sommeil
par l'app **Raccourcis** d'Apple, qui, elle, peut lire Santé. Il faut créer le raccourci une fois.

### Créer le raccourci « Sommeil → Nébuleuse » (environ 5 min)

Dans l'app Raccourcis, nouveau raccourci, puis ajoutez ces actions dans l'ordre :

1. **Rechercher des échantillons Santé** : filtre « Type » = analyse du sommeil, filtre « Date de début »
   dans les 14 derniers jours, tri par date de début (plus ancien d'abord), « Limite » désactivée.
2. **Répéter avec chaque élément** (sur ces échantillons).
3. Dans la boucle, une action **Texte** contenant, séparés par des points-virgules :
   `Date de début ; Date de fin ; Valeur`
   Insérez la variable « Élément de répétition », touchez-la et choisissez la propriété voulue
   (Date de début, Date de fin, Valeur). Pour les deux dates, touchez la variable et réglez
   le format de date sur **ISO 8601**.
4. Après « Fin de la répétition » : **Combiner le texte** sur les résultats de la répétition,
   séparateur « Nouvelle ligne ».
5. **Test** : ajoutez « Copier dans le presse-papiers », lancez le raccourci, ouvrez Nébuleuse et touchez
   l'icône presse-papiers en haut à droite. L'app indique combien de lignes elle a comprises.
6. Quand ça marche, remplacez l'étape 5 par l'action **Importer le sommeil** de Nébuleuse
   (cherchez Nébuleuse dans les actions) et donnez-lui le texte combiné dans « Données ».
7. Facultatif : Raccourcis › Automatisation › « Alarme arrêtée » pour lancer le raccourci chaque matin.

Chaque ligne envoyée ressemble à : `2026-10-16T01:12:00+02:00;2026-10-16T01:48:00+02:00;Profond`.
L'app reconnaît les libellés français et anglais (Profond/Deep, Cœur/Core, Paradoxal/REM, Éveil/Awake).
Je n'ai pas pu tester le raccourci sur un iPhone : si le texte copié n'est pas compris, copiez-en
quelques lignes dans la conversation avec Claude pour qu'il adapte la lecture.

## Compatibilité Apple Watch

Séries 3 à 12 : la durée de sommeil apparaît dès que le suivi du sommeil est activé sur la montre.
Les phases (profond / léger / paradoxal) exigent watchOS 9 ou plus, donc Series 4 et suivantes.

## Compiler sans Mac (PC Windows)

1. Dépôt GitHub **public**, avec tout le contenu de ce dossier (y compris `.github/workflows/build.yml`).
2. Onglet **Actions** › « Build IPA » › Run workflow, puis téléchargez l'artefact **SommeilTracker-ipa**.
3. Sur le PC : iTunes et iCloud (depuis apple.com) puis Sideloadly. Branchez l'iPhone, activez le mode
   développeur, glissez le `.ipa` dans Sideloadly, entrez votre Apple ID, Start.
4. Sur l'iPhone : Réglages › Général › VPN et gestion de l'appareil › faire confiance au profil.

Avec un Apple ID gratuit, l'app expire après 7 jours : refaites l'étape 3.
Le widget utilise un App Group, que certains comptes gratuits refusent : il peut rester vide.

## Avec un Mac

`brew install xcodegen`, `xcodegen generate`, ouvrez `SommeilTracker.xcodeproj`, choisissez votre Team,
changez `com.example` par un identifiant à vous (aussi dans `project.yml`), puis Run.

## Publication

App Store ou TestFlight : Apple Developer Program, 99 $/an. Il débloquerait aussi l'accès direct à Santé.
