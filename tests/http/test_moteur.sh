#!/bin/bash
# =============================================================================
# Tests HTTP de l'étape 8 : le moteur C++ appelé par PHP.
#   ./tests/http/test_moteur.sh
# Critère : « Les recommandations s'affichent sur la fiche produit ; une annonce
# suspecte part en modération ».
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/../.."
source tests/http/outils.sh

nettoyer() { supprimer_comptes_test; rm -rf "$TMP"; }
supprimer_comptes_test
trap nettoyer EXIT

A="$TMP/auteur"; C="$TMP/client"; V="$TMP/vendeur"; ADM="$TMP/admin"
: > "$A"; : > "$C"; : > "$V"; : > "$ADM"
inscrire "$A" test-moteur-auteur@exemple.ma > /dev/null
inscrire "$C" test-moteur-client@exemple.ma > /dev/null
connecter "$V" youssef.benali@exemple.ma > /dev/null
connecter "$ADM" admin@exemple.ma > /dev/null

echo "--- Le moteur dans le conteneur PHP"
REPONSE=$(echo '{"action":"risque_annonce","annonce":{"titre":"Test","prix":10}}' | docker compose exec -T php souk-moteur)
verifier_contient "souk-moteur répond en JSON" '"ok":true' "$REPONSE"
verifier "requête invalide : code de sortie 2" 2 "$(echo '{' | docker compose exec -T php souk-moteur > /dev/null; echo $?)"

echo "--- Score de risque des annonces"
poster "$A" /annonces 'titre=iPhone 15 Pro neuf URGENT' \
    'description=Jamais servi. Paiement par virement ou Western Union, envoi par transporteur.' \
    prix=900 ville=Casablanca id_categorie=3 > /dev/null
SUSPECTE=$(location | sed 's|.*/mes-annonces/||')
verifier "annonce suspecte : EN_MODERATION" EN_MODERATION "$(sql "SELECT statut FROM annonce WHERE id = $SUSPECTE;")"
verifier "annonce suspecte : score >= 60" 1 "$(sql "SELECT COUNT(*) FROM annonce WHERE id = $SUSPECTE AND score_risque >= 60;")"
verifier_contient "l'auteur est prévenu de la vérification" "vérifiée par notre équipe" "$(page "$A" "/mes-annonces/$SUSPECTE")"
verifier "pas visible du public avant modération (404)" 404 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/annonce/$SUSPECTE")"
verifier_contient "listée dans la file de modération de l'admin" "iPhone 15 Pro neuf URGENT" "$(page "$ADM" /admin/moderation)"

poster "$A" /annonces 'titre=Vélo de ville test moteur' 'description=Bon état, pneus neufs.' \
    prix=1200 ville=Rabat id_categorie=24 > /dev/null
NORMALE=$(location | sed 's|.*/mes-annonces/||')
verifier "annonce ordinaire : EN_LIGNE" EN_LIGNE "$(sql "SELECT statut FROM annonce WHERE id = $NORMALE;")"
verifier "annonce ordinaire : score calculé et < 60" 1 \
    "$(sql "SELECT COUNT(*) FROM annonce WHERE id = $NORMALE AND score_risque < 60;")"

poster "$A" "/mes-annonces/$NORMALE" 'titre=Vélo de ville test moteur' \
    'description=Paiement d avance par virement, envoi par transporteur, contact 06 12 34 56 78' \
    prix=100 ville=Rabat id_categorie=24 > /dev/null
verifier "modifiée en arnaque : repart EN_MODERATION" EN_MODERATION "$(sql "SELECT statut FROM annonce WHERE id = $NORMALE;")"

echo "--- Recommandations « souvent achetés ensemble »"
verifier "client : recalcul interdit (403)" 403 "$(poster "$C" /admin/recommandations)"
verifier "admin : recalcul (303)" 303 "$(poster "$ADM" /admin/recommandations)"
verifier_contient "admin : message de succès" "recalculées par le moteur C++" "$(page "$ADM" /admin)"
verifier "table RECOMMANDATION remplie" 1 "$(sql "SELECT CASE WHEN COUNT(*) > 20 THEN 1 ELSE 0 END FROM recommandation;")"
NOM_RECO=$(sql "SELECT REPLACE(p.nom, '''', '&#039;') FROM recommandation r JOIN produit p ON p.id = r.id_produit_recommande
                 WHERE r.id_produit = 1 AND p.stock > 0 ORDER BY r.score DESC FETCH FIRST 1 ROWS ONLY;")
FICHE=$(curl -s "$BASE/produit/1")
verifier_contient "fiche produit : section affichée" "Souvent achetés ensemble" "$FICHE"
verifier_contient "fiche produit : meilleur produit recommandé" "$NOM_RECO" "$(tr -d ' \t\n' <<< "$FICHE")"
SANS_RECO=$(sql "SELECT MIN(p.id) FROM produit p JOIN boutique b ON b.id = p.id_boutique
    WHERE p.statut = 'ACTIF' AND b.statut = 'VALIDEE' AND NOT EXISTS (SELECT 1 FROM recommandation r
      JOIN produit q ON q.id = r.id_produit_recommande WHERE r.id_produit = p.id AND q.stock > 0);")
verifier "produit sans recommandation : fiche affichée (200)" 200 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/produit/$SANS_RECO")"
verifier "produit sans recommandation : pas de section vide" 0 \
    "$(curl -s "$BASE/produit/$SANS_RECO" | grep -c 'Souvent achetés ensemble')"

echo "--- Score de risque des commandes"
poster "$C" /panier/ajouter id_produit=2 quantite=10 retour=/panier > /dev/null
verifier "grosse commande à la livraison, nouveau compte : 303" 303 \
    "$(poster "$C" /commande mode=LIVRAISON 'adresse=3 rue Test' ville=Rabat 'telephone=06 00 00 00 01')"
verifier "score de risque enregistré (>= 60)" 1 "$(sql "SELECT COUNT(*) FROM commande c JOIN utilisateur u ON u.id = c.id_client
    WHERE u.email = 'test-moteur-client@exemple.ma' AND c.score_risque >= 60;")"
NUMERO=$(sql "SELECT c.numero FROM commande c JOIN utilisateur u ON u.id = c.id_client WHERE u.email = 'test-moteur-client@exemple.ma';")
verifier_contient "vendeur : badge « À vérifier » dans la liste" "À vérifier" "$(page "$V" /vendeur/commandes)"
verifier_contient "vendeur : avertissement sur la commande" "confirmez-la par téléphone" "$(page "$V" "/vendeur/commandes/$NUMERO")"
verifier_contient "admin : compteur des commandes à risque" "commande(s) à risque" "$(page "$ADM" /admin)"

bilan "MOTEUR C++"
