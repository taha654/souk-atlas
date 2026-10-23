#!/bin/bash
# =============================================================================
# Tests HTTP du catalogue et de l'API JSON (lecture seule : aucune donnée modifiée).
#   ./tests/http/test_catalogue.sh
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/../.."

BASE="${BASE:-http://localhost:8000}"
OK=0
ECHECS=0

verifier() {
    if [[ "$2" == "$3" ]]; then OK=$((OK + 1)); echo "OK     $1"
    else ECHECS=$((ECHECS + 1)); echo "ÉCHEC  $1 — attendu : $2, obtenu : $3"; fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$BASE$1"; }
# json URL EXPRESSION : évalue une expression Python sur la réponse JSON (variable d)
json() { curl -s "$BASE$1" | python3 -c "import json, sys; d = json.load(sys.stdin); print($2)"; }
# Valeur calculée directement en base, pour comparer avec ce que renvoie le site
sql() {
    docker compose exec -T oracle bash -c \
        'sqlplus -s -L "$APP_USER/$APP_USER_PASSWORD@//localhost/FREEPDB1"' <<< "SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
$1" | tr -d ' \t\r\n'
}

echo "--- Pages"
verifier "GET /catalogue" 200 "$(code /catalogue)"
verifier "GET /produit/1" 200 "$(code /produit/1)"
verifier "produit d'une boutique non validée : 404" 404 "$(code /produit/59)"
verifier "produit INACTIF : 404" 404 "$(code /produit/43)"
verifier "/produit/abc : 404" 404 "$(code /produit/abc)"
verifier "/produit/0 : 404" 404 "$(code /produit/0)"
verifier "paramètres invalides : page affichée quand même" 200 "$(code '/catalogue?page=-1&tri=x&categorie=abc&prix_min=zz')"

echo "--- API /api/produits"
verifier "Content-Type JSON" "application/json; charset=UTF-8" \
    "$(curl -s -o /dev/null -w '%{content_type}' "$BASE/api/produits")"
attendu=$(sql "SELECT COUNT(*) FROM produit p JOIN boutique b ON b.id = p.id_boutique WHERE p.statut = 'ACTIF' AND b.statut = 'VALIDEE';")
verifier "total = produits visibles en base" "$attendu" "$(json /api/produits "d['total']")"
verifier "12 produits par page" 12 "$(json /api/produits "len(d['produits'])")"
verifier "nombre de pages" "$(( (attendu + 11) / 12 ))" "$(json /api/produits "d['pages']")"
verifier "catégorie Smartphones : 4 produits" 4 "$(json '/api/produits?categorie=3' "d['total']")"
verifier "catégorie parente « Téléphones & tablettes » inclut ses sous-catégories" 11 \
    "$(json '/api/produits?categorie=2' "d['total']")"
verifier "« ECRAN » = « ecran » = « écran »" "8 8 8" \
    "$(json '/api/produits?q=ECRAN' "d['total']") $(json '/api/produits?q=ecran' "d['total']") $(json '/api/produits?q=%C3%A9cran' "d['total']")"
verifier "filtre prix : tous entre 1000 et 2000 TTC" True \
    "$(json '/api/produits?prix_min=1000&prix_max=2000' "all(1000 <= p['prix_courant_ttc'] <= 2000 for p in d['produits']) and d['total'] > 0")"
verifier "tri prix croissant" True \
    "$(json '/api/produits?tri=prix_asc' "[p['prix_courant_ttc'] for p in d['produits']] == sorted(p['prix_courant_ttc'] for p in d['produits'])")"
verifier "prix de l'API = prix calculé par Oracle" "$(sql 'SELECT TO_CHAR(pkg_catalogue.prix_courant_ttc(1), '"'"'FM99999990.00'"'"') FROM dual;')" \
    "$(json '/api/produits?q=galaxy+a55' "'%.2f' % next(p for p in d['produits'] if p['id'] == 1)['prix_courant_ttc']")"
verifier "page au-delà des résultats : liste vide, total conservé" "0 4" \
    "$(json '/api/produits?categorie=3&page=99' "str(len(d['produits'])) + ' ' + str(d['total'])")"
verifier "URL canonique renvoyée" "/catalogue?q=tapis&tri=prix_desc" \
    "$(json '/api/produits?tri=prix_desc&q=tapis&page=1' "d['url']")"
verifier "injection SQL dans q : aucun résultat, pas d'erreur" "200 0" \
    "$(code "/api/produits?q=%27%20OR%201%3D1%20--") $(json "/api/produits?q=%27%20OR%201%3D1%20--" "d['total']")"

echo "--- API /api/suggestions"
verifier "1 caractère : aucune suggestion" "[]" "$(curl -s "$BASE/api/suggestions?q=s")"
verifier "« smart » : 4 suggestions" 4 "$(json '/api/suggestions?q=smart' "len(d)")"
verifier "« ecou » trouve « Écouteurs » (accents)" "Écouteurs sans fil Bluetooth" "$(json '/api/suggestions?q=ecou' "d[0]['nom']")"
verifier "API inconnue : 404 en JSON" "404 Page introuvable" \
    "$(code /api/inexistant) $(json /api/inexistant "d['erreur']")"

echo "--- Sécurité"
page=$(curl -s "$BASE/catalogue?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E")
verifier "q=<script> échappé dans la page (titre, h1, champ)" 3 "$(grep -c '&lt;script&gt;alert(1)&lt;/script&gt;' <<< "$page")"
verifier "aucune balise <script>alert dans la page" 0 "$(grep -c '<script>alert' <<< "$page")"
verifier "CSP présente sur le catalogue" 1 \
    "$(curl -s -D - -o /dev/null "$BASE/catalogue" | grep -ci "^content-security-policy: default-src 'self'")"

echo "--- Charge"
# 300 requêtes, 16 à la fois. Avant oci_pconnect, environ 70 % échouaient (ORA-12516)
codes=$(seq 1 300 | xargs -P 16 -I{} curl -s -o /dev/null -w '%{http_code}\n' "$BASE/api/produits?q=samsung" | sort | uniq -c | tr -s ' ' | xargs)
verifier "300 requêtes simultanées (16 en parallèle) : toutes en 200" "300 200" "$codes"

echo
echo "BILAN HTTP CATALOGUE : $OK OK, $ECHECS ÉCHEC"
[[ $ECHECS -eq 0 ]]
