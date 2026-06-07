# gld-freedge

Ralentit la dégradation des objets périssables (`degrade`) d'`ox_inventory` lorsqu'ils sont stockés dans un frigo. Fonctionne sur **ESX, QBCore et QBox** sans configuration spécifique : toute la logique passe par `ox_inventory`, le framework n'est utilisé que pour l'affichage du log de démarrage.

## Fonctionnement

Pour un objet périssable, ox_inventory stocke `metadata.durability` comme un **timestamp de fin de vie** (`os.time() + degrade*60`) et `metadata.degrade` en minutes.

Quand un objet **entre** dans un frigo, le script multiplie le temps restant **et** `degrade` par `Config.Multiplier` : le pourcentage affiché reste identique, mais l'objet se dégrade `Multiplier` fois moins vite. Quand il **sort**, l'effet est divisé pour reprendre une dégradation normale. Un flag `metadata.fridge` empêche toute double application.

## Détection des frigos

Un inventaire est reconnu comme frigo si son identifiant **commence par** un préfixe (`Config.FridgePrefixes`) **ou contient** un mot-clé (`Config.FridgeKeywords`). Exemple : un stash `fridge_house_12` ou `frigo_appart3` est détecté automatiquement.

## Configuration (`config.lua`)

- `Config.Debug` : logs console (laisser `false` en production).
- `Config.Multiplier` : facteur de ralentissement (ex. `4.0` = 4x plus lent).
- `Config.FridgePrefixes` / `Config.FridgeKeywords` : identification des frigos.

## Installation

1. Placer le dossier `fridge-degradation` dans vos ressources.
2. `ensure fridge-degradation` **après** `ox_inventory`.
3. Adapter `config.lua` à vos identifiants de stash.

## Notes

- Seuls les items ayant une propriété `degrade` (périssables) sont affectés. Les durabilités statiques (armes, etc.) sont ignorées.
- Aucune base de données : l'effet est porté par la metadata de l'item, donc persistant et compatible avec la sauvegarde native d'ox_inventory.

``['rizblanc'] = {
    label = 'Riz blanc',
    weight = 100,
    degrade = 10,    -- minutes avant 0%
    decay = true,    -- <- detruit l'item quand il atteint 0%
    ...
},``
