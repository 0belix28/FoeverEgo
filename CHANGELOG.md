# ForeverEgo - Historique des versions

Format des versions : **0.X.Y**
- **X** : mise à jour majeure (nouvelle fonctionnalité importante)
- **Y** : mise à jour mineure (correction, petit ajout)
- Passage en **1.0.0** quand l'addon sera terminé et stable.

Le numéro de version se change à un seul endroit : la ligne `## Version:` de `ForeverEgo.toc`.

---

## 0.6.3 - Hauteur automatique

- La hauteur de la fenêtre s'adapte automatiquement aux catégories dépliées :
  replier ou déplier une section agrandit ou réduit la fenêtre (sans dépasser la hauteur de l'écran ;
  au-delà, la barre de défilement prend le relais).
- La fenêtre est ancrée par son coin haut-gauche : elle grandit et rétrécit vers le bas.
- La poignée de redimensionnement et le bouton « Réinitialiser la taille » sont retirés (la taille est entièrement automatique).
- `/fego reset` recentre simplement la fenêtre au milieu de l'écran.

## 0.6.2 - Réinitialiser la taille

- Nouveau bouton « Réinitialiser la taille » en haut à droite de la fenêtre :
  remet la hauteur par défaut (580) et recentre la fenêtre.
- Nouvelle commande `/fego reset` qui fait la même chose (utile si la fenêtre est inaccessible).
- La hauteur ne peut plus dépasser celle de l'écran, ni au redimensionnement ni à l'ouverture.

## 0.6.1 - Section JcJ

- « JcJ » redevient une section à part, placée juste au-dessus de « Réputations » (et non plus à l'intérieur).

## 0.6.0 - Panneau d'options

- Nouvelle page « ForeverEgo » dans Échap > Options > Add-ons :
  logo, nom de l'addon, version, bouton « Ouvrir ForeverEgo » et liste de toutes les commandes.
- Nouvelle commande `/fego options` pour ouvrir directement cette page.
- La liste des commandes est partagée entre l'aide du chat et le panneau d'options.
- Nouveau fichier `Options.lua` : un redémarrage complet du jeu est nécessaire.

## 0.5.3 - Largeur automatique

- Plus de pages : tous les personnages affichés sont visibles en même temps.
- Les boutons « < » et « > » et le texte « Page X / Y » sont retirés.
- La largeur de la fenêtre s'adapte automatiquement au nombre de personnages (et aux séparations entre groupes),
  sans dépasser la largeur de l'écran.
- La poignée en bas à droite ne règle plus que la hauteur.

## 0.5.2 - JcJ dans les Réputations

- La section « JcJ » devient une sous-catégorie de « Réputations », placée après les groupes de factions.
  Elle se replie comme les autres sous-catégories.

## 0.5.1 - Embellissements

- Icône de classe au-dessus du nom de chaque personnage, entourée de la couleur de sa classe.
- Barres de progression (XP, métiers, réputations, donjons) en dégradé, avec un léger reflet sur la moitié haute.
- Survoler un en-tête ou une case éclaire toute la colonne du personnage
  (couleur d'accent avec EllesmereUI, blanc sinon), avec un trait en haut de la colonne.

## 0.5.0 - Colonnes par type de serveur

- Les personnages sont regroupés par type de serveur : PvE, PvP, RP, RP-PvP, Hardcore, puis type inconnu.
- Chaque groupe a un bandeau coloré au-dessus de ses colonnes, avec le nom du type et le nombre de personnages.
- Un trait vertical et un espace séparent deux groupes.
- Dans chaque groupe, le tri reste par niveau décroissant, puis par nom.
- Les pages se remplissent en tenant compte de l'espace entre les groupes.
- La liste « Personnages » suit le même ordre : type de serveur, puis niveau.

## 0.4.1 - Cases à cocher

- Style EllesmereUI : les cases cochées ne se voyaient pas (la coche était cachée sous le fond).
  Une case cochée a maintenant une bordure et un carré intérieur à la couleur d'accent, comme dans EllesmereUI.

## 0.4.0 - Style EllesmereUI et optimisations

- Style EllesmereUI (si l'addon est installé) : fond sombre uni, bordures fines à la couleur d'accent,
  police d'EllesmereUI, barres plates, boutons, cases à cocher, recherche et barres de défilement assortis.
  La couleur d'accent suit celle choisie dans EllesmereUI.
- Nouvelle commande `/fego style` : bascule entre le style EllesmereUI (auto) et le style Blizzard
- Optimisations :
  - aucune lecture des données pendant un combat (reprise à la sortie du combat)
  - un changement de zone ne relit plus les métiers ni les réputations (ils ont leurs propres événements)
  - rafraîchissements de la fenêtre regroupés, redimensionnement fluide
  - recettes allégées : le nom des composants n'est plus enregistré (retrouvé à l'affichage)
- Nouvelle commande `/fego nettoyer [jours]` : liste puis supprime (avec `confirmer`) les personnages
  absents depuis longtemps (90 jours par défaut)

## 0.3.0 - Recettes des métiers

- Les recettes de chaque métier sont enregistrées quand tu ouvres la fenêtre du métier
  (seulement tes propres métiers, pas ceux d'un autre joueur)
- Clic gauche sur la barre d'un métier :
  - personnage connecté : ouvre la vraie fenêtre du métier du jeu
  - autre personnage : ouvre la fenêtre des recettes ForeverEgo (recettes classées par catégorie,
    couleur de difficulté, composants, quantité fabriquée, recherche par nom de recette ou de composant,
    infobulle de l'objet, Maj + clic = lien dans le chat)
- Les métiers de récolte (Dépeçage, Herboristerie, Pêche) indiquent qu'ils n'ont pas de recettes

## 0.2.5 - Tri automatique

- Retrait du bouton « Tri » : les personnages sont toujours triés par niveau (du plus haut au plus bas),
  puis par nom en cas d'égalité

## 0.2.4 - Correction de l'or

- L'or et l'XP des autres personnages n'étaient pas conservés : le jeu renvoie 0 au moment
  de la déconnexion et l'addon les écrasait. À la déconnexion, seule l'heure est maintenant enregistrée.

## 0.2.3 - Logo

- Nouveau logo ForeverEgo (Media\Logo.tga) pour le bouton de la minicarte et la liste des addons

## 0.2.2 - Allègement de l'affichage

- Retrait des sections Compétences d'armes, Armures, Langues et Compétences de classe
  (les données restent enregistrées et peuvent être réaffichées facilement)
- Retrait du bouton « Serveur » : le type de serveur (PvE, PvP...) s'affiche dans le cadre du personnage

## 0.2.1 - Corrections WoW Forever

- Personnages identifiés par leur identifiant unique (GUID) : deux personnages avec le même prénom
  ne s'écrasent plus. Les anciennes fiches sont effacées une fois : reconnecte chaque personnage.
- Affichage du prénom et du nom de famille ; le nom du serveur n'apparaît plus dans le cadre du personnage
- Type de serveur (PvE, PvP, RP, RP-PvP, Hardcore) détecté automatiquement via les règles du jeu
- Compétences (métiers, armes...) lues via l'API de WoW Forever (C_SkillInfo)
- Nouvelle commande `/fego debug` pour diagnostiquer

## 0.2.0 - Équipement et choix des personnages

- Nouvelle fenêtre d'équipement : clic gauche sur un personnage pour voir son stuff
  (emplacement, objet, niveau d'objet, enchantement). Survol = infobulle de l'objet,
  Maj + clic = lien dans le chat. Les emplacements enchantables sans enchantement sont signalés « Aucun ».
- Nouveau bouton « Personnages » : liste de tous les personnages avec case à cocher pour les afficher / masquer
- Retrait des lignes « Serveur » et « Pierre de foyer » de la section Général

## 0.1.0 - Première version

- Enregistrement automatique de chaque personnage à la connexion (compte entier, tous royaumes)
- Filtre par type de serveur (PvE, PvP, RP, RP-PvP, Hardcore), avec une case « Tous les types de serveur »
- Fenêtre en tableau, une colonne par personnage, avec des sections repliables :
  - Général : serveur, faction, niveau, race, classe, guilde, niveau d'objet, zone, foyer, dernière connexion
  - Progression : XP, XP de repos estimée, temps de jeu, or
  - Métiers, compétences secondaires, compétences d'armes, armures, langues
  - Réputations rangées par groupe
  - Donjons et raids verrouillés
  - JcJ : rang et victoires honorables
- Tri (niveau, nom, or, connexion), pagination, fenêtre redimensionnable
- Bouton de la minicarte et commandes `/fego`
- Message en jeu lors d'un changement de version, commande `/fego version`
