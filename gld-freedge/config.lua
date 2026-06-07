Config = {}

-- Facteur de ralentissement de la degradation dans les frigos.
-- Exemple : 30 => les objets se degradent 30x moins vite tant qu'ils sont au frigo.
Config.FridgeMultiplier = 30

-- Affiche les logs de debug dans la console serveur (mettre false en production)
Config.Debug = false

-- Liste des frigos. Tu peux mettre directement le NOM DU MODELE du prop (lisible) :
-- le script le convertit en hash (GetHashKey), exactement comme hrs_base_building construit
-- son id de stash ('HRS'..hashModele..idProp..date).
--
-- (Tu peux aussi y coller un hash numerique ou un fragment d'id de stash : ca marche aussi.)
Config.HashFridge = {
    'prop_box_wood01a',
    'v_res_tt_fridge',
}
