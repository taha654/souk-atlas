#!/bin/bash
# =============================================================================
# Tests HTTP de l'étape 9 : jetons d'API et outil console C++ (souk-console),
# lancé DANS le conteneur PHP (le site y répond sur http://localhost).
#   ./tests/http/test_console.sh
# Critère : « Import d'un CSV de 100 produits avec rapport d'erreurs ».
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/../.."
source tests/http/outils.sh

nettoyer() { supprimer_comptes_test; rm -rf "$TMP"; }
supprimer_comptes_test
trap nettoyer EXIT

V="$TMP/vendeur"; C="$TMP/client"; ADM="$TMP/admin"
: > "$V"; : > "$C"; : > "$ADM"
inscrire "$V" test-console-vendeur@exemple.ma VENDEUR > /dev/null
inscrire "$C" test-console-client@exemple.ma > /dev/null
connecter "$ADM" admin@exemple.ma > /dev/null
poster "$V" /vendeur/boutique 'nom=Boutique Console Test' ville=Rabat > /dev/null
CSV=/var/www/html/cpp/console/exemples/catalogue_100.csv

# console JETON commande… : lance souk-console dans le conteneur ; sortie dans $TMP/sortie, code renvoyé
console() {
    local jeton="$1"; shift
    docker compose exec -T -e SOUK_JETON="$jeton" php souk-console "$@" > "$TMP/sortie" 2>&1
    echo $?
}
# Jeton lu dans la page affichée juste après sa création
creer_jeton() {   # creer_jeton jar libellé
    poster "$1" /compte/jetons "libelle=$2" jours=7 > /dev/null
    grep -o 'id="jeton-cree"[^>]*value="souk_[0-9a-f]*"' "$TMP/corps" | grep -o 'souk_[0-9a-f]*'
}

echo "--- Jetons d'accès (site)"
verifier "client : page des jetons interdite (403)" 403 "$(code "$C" /compte/jetons)"
verifier "client : création interdite (403)" 403 "$(poster "$C" /compte/jetons libelle=x jours=7)"
verifier "vendeur : page des jetons" 200 "$(code "$V" /compte/jetons)"
verifier "création sans jeton CSRF : 403" 403 "$(curl -s -o /dev/null -w '%{http_code}' -b "$V" --data 'libelle=x&jours=7' "$BASE/compte/jetons")"
verifier "durée non proposée : 422" 422 "$(poster "$V" /compte/jetons libelle=x jours=1000)"
verifier "création : 201" 201 "$(poster "$V" /compte/jetons libelle=test-console jours=7)"
JV=$(grep -o 'value="souk_[0-9a-f]*"' "$TMP/corps" | grep -o 'souk_[0-9a-f]*')
verifier "jeton de 64 caractères hexadécimaux après « souk_ »" 1 "$(grep -c '^souk_[0-9a-f]\{64\}$' <<< "$JV")"
verifier_contient "page non mise en cache (secret)" "no-store" "$(grep -i '^cache-control' "$TMP/entetes")"
EMPREINTE=$(printf '%s' "$JV" | sha256sum | cut -d' ' -f1)
verifier "base : seule l'empreinte SHA-256 est stockée" 1 "$(sql "SELECT COUNT(*) FROM jeton_api WHERE empreinte = '$EMPREINTE';")"
verifier "base : le jeton en clair n'apparaît nulle part" 0 "$(sql "SELECT COUNT(*) FROM jeton_api WHERE empreinte = '$JV' OR libelle = '$JV';")"
verifier "jeton absent de la liste (affiché une seule fois)" 0 "$(page "$V" /compte/jetons | grep -c "$JV")"

echo "--- API : authentification par jeton"
verifier "sans jeton : 401" 401 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/console/moi")"
verifier "jeton inventé : 401" 401 "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer souk_$(printf 'a%.0s' {1..64})" "$BASE/api/console/moi")"
verifier "cookie de session seul (sans jeton) : 401" 401 "$(curl -s -o /dev/null -w '%{http_code}' -b "$V" "$BASE/api/console/moi")"
verifier "bon jeton : 200" 200 "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $JV" "$BASE/api/console/moi")"
verifier "POST sans CSRF mais avec jeton : accepté (corps invalide → 400)" 400 \
    "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $JV" -H 'Content-Type: application/json' --data '{"x":1}' "$BASE/api/console/produits")"
verifier "JSON mal formé : 400" 400 \
    "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $JV" --data '{"produits":[' "$BASE/api/console/produits")"
LOT=$(python3 -c "import json; print(json.dumps({'produits': [{'nom': 'x'}] * 101}))")
verifier "plus de 100 produits par requête : 400" 400 \
    "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $JV" --data "$LOT" "$BASE/api/console/produits")"
verifier "vendeur : signalements interdits (403)" 403 "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $JV" "$BASE/api/console/signalements")"
verifier "date de dernière utilisation notée" 1 "$(sql "SELECT COUNT(*) FROM jeton_api WHERE empreinte = '$EMPREINTE' AND date_derniere_utilisation IS NOT NULL;")"

echo "--- souk-console : vendeur"
verifier "sans SOUK_JETON : code 3" 3 "$(console '' moi)"
verifier_contient "sans SOUK_JETON : explication" "Jetons d'accès" "$(cat "$TMP/sortie")"
verifier "jeton invalide : code 3" 3 "$(console "souk_$(printf 'b%.0s' {1..64})" moi)"
verifier_contient "jeton invalide : HTTP 401 signalé" "HTTP 401" "$(cat "$TMP/sortie")"
verifier "moi : code 0" 0 "$(console "$JV" moi)"
verifier_contient "moi : compte et boutique" "Boutique : Boutique Console Test" "$(cat "$TMP/sortie")"
verifier "categories : code 0" 0 "$(console "$JV" categories)"
verifier_contient "categories : arbre" "    Smartphones" "$(cat "$TMP/sortie")"
verifier "import --essai : code 1 (lignes fausses)" 1 "$(console "$JV" import-csv "$CSV" --essai)"
verifier_contient "import --essai : 94 valides localement" "Lignes lues : 100 | valides : 94 | rejetées : 6" "$(cat "$TMP/sortie")"
verifier "import --essai : rien d'enregistré" 0 "$(sql "SELECT COUNT(*) FROM produit p JOIN boutique b ON b.id = p.id_boutique WHERE b.nom = 'Boutique Console Test';")"

verifier "import-csv : code 1 (terminé avec des refus)" 1 "$(console "$JV" import-csv "$CSV" --rapport /tmp/rapport-import.csv)"
SORTIE=$(cat "$TMP/sortie")
verifier_contient "import : bilan 100 / 91 / 9" "Lignes lues : 100 | importées : 91 | rejetées : 9" "$SORTIE"
verifier_contient "erreur locale : prix illisible (ligne 8)" "ligne 8 : prix_ht invalide « douze »" "$SORTIE"
verifier_contient "erreur locale : colonne manquante" "4 colonne(s) au lieu de 5" "$SORTIE"
verifier_contient "erreur serveur : catégorie inconnue" "refusé par le serveur : catégorie inconnue « Hoverboards »" "$SORTIE"
verifier "base : 91 produits dans la boutique" 91 "$(sql "SELECT COUNT(*) FROM produit p JOIN boutique b ON b.id = p.id_boutique WHERE b.nom = 'Boutique Console Test';")"
verifier "base : prix « 1 299,90 » bien converti (aucun prix nul)" 0 "$(sql "SELECT COUNT(*) FROM produit p JOIN boutique b ON b.id = p.id_boutique WHERE b.nom = 'Boutique Console Test' AND (p.prix_ht <= 0 OR p.prix_ht IS NULL);")"
verifier "base : guillemets et « ; » conservés dans les descriptions" 1 "$(sql "SELECT CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END FROM produit WHERE description LIKE '%; garantie 1 an, dit \"solide\".';")"
verifier "audit : produits créés au nom du vendeur" 91 "$(sql "SELECT COUNT(*) FROM journal_audit j JOIN utilisateur u ON TO_CHAR(u.id) = j.auteur WHERE u.email = 'test-console-vendeur@exemple.ma' AND j.nom_table = 'PRODUIT' AND j.operation = 'INSERT';")"
docker compose exec -T php cat /tmp/rapport-import.csv > "$TMP/rapport.csv"
verifier "rapport : une ligne par produit + en-tête" 101 "$(wc -l < "$TMP/rapport.csv")"
verifier "rapport : 91 IMPORTE" 91 "$(grep -c ';IMPORTE;' "$TMP/rapport.csv")"
verifier "rapport : 9 REJETE" 9 "$(grep -c ';REJETE;' "$TMP/rapport.csv")"
verifier "rapport du vendeur : code 0" 0 "$(console "$JV" rapport --debut 2026-01-01 --fin 2026-01-31)"
verifier_contient "rapport du vendeur : sa boutique seulement" "(boutique " "$(cat "$TMP/sortie")"
verifier "moderation par un vendeur : refusée (code 3)" 3 "$(console "$JV" moderation liste)"
verifier_contient "moderation par un vendeur : HTTP 403" "HTTP 403" "$(cat "$TMP/sortie")"
verifier "option mal orthographiée : code 2" 2 "$(console "$JV" rapport --dbut 2026-01-01)"

echo "--- souk-console : administrateur"
JA=$(creer_jeton "$ADM" test-console-admin)
poster "$V" /annonces 'titre=Vélo test console' 'description=Vélo de ville en bon état.' prix=900 ville=Rabat id_categorie=24 > /dev/null
ANN=$(location | sed 's|.*/mes-annonces/||')
poster "$C" "/annonce/$ANN/signaler" motif=DOUBLON > /dev/null
SIG=$(sql "SELECT id FROM signalement WHERE id_annonce = $ANN;")
verifier "moderation liste : code 0" 0 "$(console "$JA" moderation liste)"
verifier_contient "moderation liste : signalement visible" "Vélo test console" "$(cat "$TMP/sortie")"
verifier "moderation rejeter : code 0" 0 "$(console "$JA" moderation rejeter "$SIG")"
verifier "signalement rejeté en base" REJETE "$(sql "SELECT statut FROM signalement WHERE id = $SIG;")"
verifier "annonce toujours en ligne" EN_LIGNE "$(sql "SELECT statut FROM annonce WHERE id = $ANN;")"
verifier "rejeter deux fois : refus métier (code 3)" 3 "$(console "$JA" moderation rejeter "$SIG")"
verifier "rapport global en CSV : code 0" 0 "$(console "$JA" rapport --debut 2026-01-01 --fin 2026-03-31 --sortie /tmp/ventes.csv)"
verifier_contient "rapport global : classement des boutiques" "Boutiques :" "$(cat "$TMP/sortie")"
docker compose exec -T php cat /tmp/ventes.csv > "$TMP/ventes.csv"
verifier "CSV : 90 jours + en-tête" 91 "$(wc -l < "$TMP/ventes.csv")"
verifier "CSV : virgule décimale et point-virgule" 1 "$(grep -c '^2026-01-01;[0-9]*;[0-9]*,[0-9][0-9];' "$TMP/ventes.csv")"
CA_CSV=$(tail -1 "$TMP/ventes.csv" | tr -d '\r' | cut -d';' -f4 | tr ',' '.')
CA_BASE=$(sql "SELECT TO_CHAR(NVL(SUM(total_ht), 0), 'FM999999990.00') FROM commande WHERE statut <> 'ANNULEE' AND date_commande >= DATE '2026-01-01' AND date_commande < DATE '2026-04-01';")
verifier "CSV : CA cumulé = somme calculée en base" "$CA_BASE" "$CA_CSV"

echo "--- Révocation"
ID_JETON=$(sql "SELECT id FROM jeton_api WHERE empreinte = '$EMPREINTE';")
verifier "autre utilisateur : révocation impossible" "Révoquer" \
    "$(poster "$ADM" "/compte/jetons/$ID_JETON/revoquer" > /dev/null; page "$V" /compte/jetons | grep -o 'Révoquer' | head -1)"
poster "$V" "/compte/jetons/$ID_JETON/revoquer" > /dev/null
verifier "jeton révoqué : console refusée (code 3)" 3 "$(console "$JV" moi)"
verifier_contient "page : jeton marqué révoqué" "Révoqué" "$(page "$V" /compte/jetons)"

bilan "CONSOLE C++"
