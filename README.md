<p align="center">
  <img src="Media/Logo.png" alt="ForeverEgo" width="96">
</p>

<h1 align="center">ForeverEgo</h1>

<p align="center">
  <b>Tous vos personnages WoW Forever, d'un seul coup d'œil.</b><br>
  <i>All your WoW Forever characters, at a glance.</i>
</p>

<p align="center">
  <a href="#-français">🇫🇷 Français</a> · <a href="#-english">🇬🇧 English</a>
</p>

---

## 🇫🇷 Français

**ForeverEgo** est un addon pour **World of Warcraft Forever** qui regroupe dans une seule fenêtre les informations de tous vos personnages : niveau, or, métiers, réputations, équipement, verrous de donjons et bien plus.

Connectez-vous une fois sur chaque personnage : l'addon enregistre ses données automatiquement. Il suffit ensuite d'ouvrir la fenêtre depuis n'importe quel personnage pour tout comparer.

### ✨ Fonctionnalités

- **Vue d'ensemble en colonnes** : un personnage par colonne, avec son icône de classe, son nom et son nom de famille, sa faction, son niveau et le type de serveur.
- **Groupes par type de serveur** : les personnages sont regroupés (PvE, PvP, RP, RP-PvP, Hardcore), chaque groupe a un bandeau coloré, et ils sont triés par niveau dans chaque groupe.
- **Filtre intelligent** : par défaut, seuls les personnages du même type de serveur que celui connecté sont affichés. La case **« Tous les types de serveur »** affiche tout le monde.
- **Sections repliables** :
  - **Général** : faction, race, classe, guilde, rang de guilde, niveau d'objet, zone, dernière connexion
  - **Progression** : expérience, XP de repos estimée, temps de jeu, temps à ce niveau, or (avec total de tous les personnages)
  - **Métiers** et **compétences secondaires**, avec barres de progression
  - **JcJ** : rang et victoires honorables
  - **Réputations**, classées par groupe de factions
  - **Donjons & raids verrouillés**, avec la progression et la date de réinitialisation
- **Fenêtre d'équipement** : un clic gauche sur un personnage affiche tout son équipement.
- **Recettes des métiers** :
  - Pour le personnage connecté, un clic sur un métier ouvre la vraie fenêtre de métier.
  - Pour les autres personnages, il ouvre la liste de leurs recettes, avec recherche, composants, couleurs de difficulté et liens cliquables.
- **Liste « Personnages »** pour cocher ou décocher les personnages à afficher.
- **Fenêtre à taille automatique** : la largeur suit le nombre de personnages et la hauteur suit les sections dépliées.
- **Style EllesmereUI** : si [EllesmereUI](https://www.curseforge.com/wow/addons/ellesmereui) est installé, l'addon reprend automatiquement son look (fond sombre, couleur d'accent, police). Sinon, il garde le style Blizzard.
- **Bouton de minicarte** et **page dans le menu Options** (Échap › Options › Add-ons › ForeverEgo).
- **Léger et sûr** : aucune lecture pendant les combats, mises à jour regroupées, données stockées uniquement sur votre ordinateur.

### 📦 Installation

1. Téléchargez la dernière version.
2. Placez le dossier `ForeverEgo` dans `World of Warcraft\_forever_\Interface\AddOns\`.
3. Lancez le jeu, puis connectez-vous une fois sur chacun de vos personnages.
4. Ouvrez la fenêtre avec `/fego` ou le bouton de la minicarte.

> 💡 Pour enregistrer les recettes d'un métier, ouvrez une fois la fenêtre de ce métier sur le personnage concerné.

### ⌨️ Commandes

| Commande | Description |
|---|---|
| `/fego` | Ouvrir / fermer la fenêtre |
| `/fego options` | Ouvrir la page d'options |
| `/fego type [pve/pvp/rp/rppvp/hc]` | Définir le type du serveur actuel (détecté automatiquement si possible) |
| `/fego tous` | Afficher / filtrer les personnages de tous les types de serveur |
| `/fego suppr Prénom Nom` | Supprimer un personnage de la base |
| `/fego afficher` | Ré-afficher les personnages masqués |
| `/fego nettoyer [jours]` | Lister les personnages absents depuis longtemps (90 jours par défaut) |
| `/fego nettoyer confirmer [jours]` | Supprimer ces personnages absents |
| `/fego minimap` | Afficher / masquer le bouton de la minicarte |
| `/fego scan` | Forcer la mise à jour du personnage actuel |
| `/fego style` | Basculer entre le style EllesmereUI (auto) et Blizzard (puis `/reload`) |
| `/fego reset` | Recentrer la fenêtre |
| `/fego version` | Afficher la version de l'addon |

**Raccourcis souris**
- **Clic gauche** sur un personnage : voir son équipement.
- **Maj + clic droit** sur un personnage : le masquer.
- **Clic gauche** sur un métier : ouvrir la fenêtre du métier ou la liste des recettes.

### 🔧 Compatibilité

- Client **WoW Forever**, Interface `16001`
- Dépendance optionnelle : **EllesmereUI**
- Interface de l'addon en **français**

---

## 🇬🇧 English

**ForeverEgo** is an addon for **World of Warcraft Forever** that shows information about all your characters in a single window: level, gold, professions, reputations, gear, dungeon lockouts and more.

Log in once on each character and the addon saves its data automatically. Then open the window from any character to compare them all.

### ✨ Features

- **Column overview**: one character per column, with class icon, name and surname, faction, level and realm type.
- **Grouped by realm type**: characters are grouped by realm type (PvE, PvP, RP, RP-PvP, Hardcore). Each group has a colored banner, and characters are sorted by level within each group.
- **Smart filter**: by default, only characters from the same realm type as the one you're playing are shown. The **"Tous les types de serveur"** (all realm types) checkbox shows everyone.
- **Collapsible sections**:
  - **General**: faction, race, class, guild, guild rank, item level, zone, last seen
  - **Progress**: experience, estimated rested XP, played time, time at this level, gold (with a total across all characters)
  - **Professions** and **secondary skills**, with progress bars
  - **PvP**: rank and honorable kills
  - **Reputations**, grouped by faction category
  - **Saved dungeons & raids**, with progress and reset time
- **Gear window**: left-click a character to see all their equipped gear.
- **Profession recipes**:
  - For the character you're logged in on, clicking a profession opens the real profession window.
  - For other characters, it opens their recipe list, with search, reagents, difficulty colors and clickable links.
- **"Personnages" list** to choose which characters are shown.
- **Auto-sizing window**: the width follows the number of characters and the height follows the expanded sections.
- **EllesmereUI style**: if [EllesmereUI](https://www.curseforge.com/wow/addons/ellesmereui) is installed, the addon automatically matches its look (dark background, accent color, font). Otherwise it keeps the Blizzard style.
- **Minimap button** and **options page** (Esc › Options › AddOns › ForeverEgo).
- **Lightweight and safe**: no data reads during combat, batched updates, and data stored only on your computer.

### 📦 Installation

1. Download the latest release.
2. Put the `ForeverEgo` folder in `World of Warcraft\_forever_\Interface\AddOns\`.
3. Start the game and log in once on each of your characters.
4. Open the window with `/fego` or the minimap button.

> 💡 To save a profession's recipes, open that profession's window once on the character.

### ⌨️ Commands

| Command | Description |
|---|---|
| `/fego` | Open / close the window |
| `/fego options` | Open the options page |
| `/fego type [pve/pvp/rp/rppvp/hc]` | Set the current realm type (auto-detected when possible) |
| `/fego tous` | Toggle showing characters from all realm types |
| `/fego suppr Firstname Lastname` | Delete a character from the database |
| `/fego afficher` | Show hidden characters again |
| `/fego nettoyer [days]` | List characters not seen for a long time (90 days by default) |
| `/fego nettoyer confirmer [days]` | Delete those inactive characters |
| `/fego minimap` | Show / hide the minimap button |
| `/fego scan` | Force an update of the current character |
| `/fego style` | Switch between EllesmereUI (auto) and Blizzard style (then `/reload`) |
| `/fego reset` | Re-center the window |
| `/fego version` | Show the addon version |

**Mouse shortcuts**
- **Left-click** a character: show their gear.
- **Shift + right-click** a character: hide it.
- **Left-click** a profession: open the profession window or the recipe list.

### 🔧 Compatibility

- **WoW Forever** client, Interface `16001`
- Optional dependency: **EllesmereUI**
- Addon interface is in **French**

---

<p align="center"><sub>ForeverEgo · version 0.6.3</sub></p>
