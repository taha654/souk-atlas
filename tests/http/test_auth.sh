#!/bin/bash
# =============================================================================
# Tests de bout en bout de l'authentification, avec curl (comme un navigateur).
# À lancer depuis la machine hôte, site démarré :
#
#   ./tests/http/test_auth.sh
#
# Vérifie : matrice d'accès par rôle, CSRF, cookies et en-têtes de sécurité,
# fixation de session, mode strict, inscription, limitation par email et par IP,
# expiration après inactivité, flag Secure forcé.
#
# Effets de bord, tous annulés à la fin :
#   - comptes créés (emails test-http-…), supprimés ;
#   - tentatives de connexion échouées effacées (sinon VOTRE navigateur, qui
#     passe par la même IP, serait bloqué 15 minutes) ;
#   - le conteneur php est relancé deux fois avec des réglages de test, puis
#     remis dans sa configuration normale.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/../.."

BASE="${BASE:-http://localhost:8000}"
MDP_DEMO='Demo1234!'
TMP=$(mktemp -d)
OK=0
ECHECS=0

verifier() {   # verifier "libellé" attendu obtenu
    if [[ "$2" == "$3" ]]; then
        OK=$((OK + 1)); echo "OK     $1"
    else
        ECHECS=$((ECHECS + 1)); echo "ÉCHEC  $1 — attendu : $2, obtenu : $3"
    fi
}
verifier_contient() {   # verifier_contient "libellé" "texte cherché" "texte"
    if grep -qF -- "$2" <<< "$3"; then
        OK=$((OK + 1)); echo "OK     $1"
    else
        ECHECS=$((ECHECS + 1)); echo "ÉCHEC  $1 — « $2 » introuvable"
    fi
}

sql() {   # exécute du SQL dans le schéma SOUK
    docker compose exec -T oracle bash -c \
        'sqlplus -s -L "$APP_USER/$APP_USER_PASSWORD@//localhost/FREEPDB1"' > /dev/null
}
effacer_echecs() {
    sql <<'SQL'
DELETE FROM tentative_connexion WHERE reussie = 0;
COMMIT;
SQL
}
nettoyer() {
    sql <<'SQL'
DELETE FROM journal_audit WHERE nom_table = 'UTILISATEUR'
   AND id_ligne IN (SELECT id FROM utilisateur WHERE email LIKE 'test-http-%');
DELETE FROM utilisateur WHERE email LIKE 'test-http-%';
DELETE FROM tentative_connexion WHERE reussie = 0 OR email LIKE 'test-http-%';
COMMIT;
SQL
    rm -rf "$TMP"
}

# Relance php avec des variables d'environnement données, puis attend qu'il réponde
relancer_php() {
    env "$@" docker compose up -d php > /dev/null 2>&1
    for _ in $(seq 1 30); do
        curl -s -o /dev/null "$BASE/" && return
        sleep 1
    done
}
restaurer() {
    relancer_php SESSION_INACTIVITE_SECONDES=1800 SESSION_COOKIE_SECURE=0
    nettoyer
}
trap restaurer EXIT

# --- Petits outils HTTP (un "jar" = le fichier de cookies d'un navigateur) ---
code() {      # code jar URL : code HTTP d'un GET
    curl -s -o /dev/null -w '%{http_code}' -b "$1" -c "$1" "$BASE$2"
}
jeton() {     # jeton jar URL : jeton CSRF lu dans le formulaire de la page
    curl -s -b "$1" -c "$1" "$BASE$2" | grep -o 'name="_csrf" value="[^"]*"' | head -1 | cut -d'"' -f4
}
poster() {    # poster jar URL champ=valeur… : POST avec le jeton CSRF ; écrit le corps dans $TMP/corps
    local jar="$1" url="$2"; shift 2
    local args=()
    for champ in "$@"; do args+=(--data-urlencode "$champ"); done
    curl -s -o "$TMP/corps" -D "$TMP/entetes" -w '%{http_code}' -b "$jar" -c "$jar" \
        --data-urlencode "_csrf=$(jeton "$jar" "$url")" "${args[@]}" "$BASE$url"
}
connecter() { # connecter jar email [mot de passe]
    poster "$1" /connexion "email=$2" "mot_de_passe=${3:-$MDP_DEMO}"
}
location() { grep -i '^location:' "$TMP/entetes" | tr -d '\r' | cut -d' ' -f2; }
session_id() { awk '$6 == "SOUKSESSID" { print $7 }' "$1"; }

effacer_echecs

# =============================================================================
echo "--- Matrice d'accès par rôle"
# Colonnes : /  /connexion  /inscription  /compte  /vendeur  /admin
# 303 = redirection (vers /connexion pour un visiteur, vers son espace pour un connecté)
PAGES=(/ /connexion /inscription /compte /vendeur /admin)
declare -A ATTENDU=(
    [visiteur]="200 200 200 303 303 303"
    [client]="200 303 303 200 403 403"
    [vendeur]="200 303 303 200 200 403"
    [admin]="200 303 303 200 403 200"
)
declare -A EMAIL=([client]=amine.lahlou@exemple.ma [vendeur]=youssef.benali@exemple.ma [admin]=admin@exemple.ma)

for role in visiteur client vendeur admin; do
    jar="$TMP/$role"
    : > "$jar"
    if [[ $role != visiteur ]]; then
        verifier "$role : connexion réussie (303)" 303 "$(connecter "$jar" "${EMAIL[$role]}")"
    fi
    read -ra codes <<< "${ATTENDU[$role]}"
    for i in "${!PAGES[@]}"; do
        verifier "$role : GET ${PAGES[$i]}" "${codes[$i]}" "$(code "$jar" "${PAGES[$i]}")"
    done
done
verifier "page inexistante : 404" 404 "$(code "$TMP/visiteur" /nexistepas)"
verifier "GET /deconnexion : 405 (POST uniquement)" 405 "$(code "$TMP/client" /deconnexion)"
verifier "fichier hors de public/ inaccessible" 404 "$(code "$TMP/visiteur" /app/config.php)"

echo "--- Redirection après connexion"
connecter "$TMP/r1" youssef.benali@exemple.ma > /dev/null
verifier "vendeur : redirigé vers /vendeur" /vendeur "$(location)"
poster "$TMP/r2" /connexion email=amine.lahlou@exemple.ma "mot_de_passe=$MDP_DEMO" retour=/compte > /dev/null
verifier "retour interne respecté" /compte "$(location)"
poster "$TMP/r3" /connexion email=amine.lahlou@exemple.ma "mot_de_passe=$MDP_DEMO" retour=//pirate.ma > /dev/null
verifier "retour externe //pirate.ma ignoré (open redirect)" /compte "$(location)"
curl -s -o /dev/null -D "$TMP/entetes" "$BASE/compte"
verifier "page protégée : ?retour= mémorisé" "/connexion?retour=%2Fcompte" "$(location)"

echo "--- CSRF"
verifier "POST /connexion sans jeton : 403" 403 \
    "$(curl -s -o /dev/null -w '%{http_code}' -d 'email=a@b.ma&mot_de_passe=x' "$BASE/connexion")"
verifier "POST avec un faux jeton : 403" 403 \
    "$(curl -s -o /dev/null -w '%{http_code}' -b "$TMP/client" -d "_csrf=$(printf '0%.0s' {1..64})" "$BASE/deconnexion")"
verifier "après le POST refusé, toujours connecté" 200 "$(code "$TMP/client" /compte)"
verifier "déconnexion avec jeton : 303" 303 "$(poster "$TMP/client" /deconnexion)"
verifier "après déconnexion, /compte redirige" 303 "$(code "$TMP/client" /compte)"

echo "--- Session et cookies"
: > "$TMP/fix"
curl -s -o /dev/null -b "$TMP/fix" -c "$TMP/fix" "$BASE/connexion"
avant=$(session_id "$TMP/fix")
connecter "$TMP/fix" amine.lahlou@exemple.ma > /dev/null
apres=$(session_id "$TMP/fix")
verifier "identifiant de session changé à la connexion (fixation)" "oui" "$([[ -n $avant && $avant != "$apres" ]] && echo oui || echo non)"

entetes=$(curl -s -o /dev/null -D - -H 'Cookie: SOUKSESSID=identifiantinventeparunattaquant123' "$BASE/")
cookie=$(grep -i '^set-cookie: SOUKSESSID' <<< "$entetes" | tr -d '\r')
verifier "mode strict : identifiant inventé remplacé" "oui" \
    "$([[ -n $cookie && $cookie != *identifiantinventeparunattaquant123* ]] && echo oui || echo non)"
verifier_contient "cookie HttpOnly" "HttpOnly" "$cookie"
verifier_contient "cookie SameSite=Lax" "SameSite=Lax" "$cookie"
verifier "pas de Secure en HTTP local" "non" "$([[ $cookie == *Secure* ]] && echo oui || echo non)"
cookie=$(curl -s -o /dev/null -D - -H 'X-Forwarded-Proto: https' "$BASE/" | grep -i '^set-cookie: SOUKSESSID')
verifier "en-tête X-Forwarded-Proto ignoré (falsifiable)" "non" "$([[ $cookie == *Secure* ]] && echo oui || echo non)"
verifier_contient "en-tête X-Content-Type-Options" "nosniff" "$entetes"
verifier_contient "en-tête X-Frame-Options" "DENY" "$entetes"
verifier_contient "en-tête Content-Security-Policy" "default-src 'self'" "$entetes"
verifier "PHP ne révèle pas sa version" "" "$(grep -i '^x-powered-by' <<< "$entetes")"

echo "--- Inscription"
J="$TMP/inscription"
: > "$J"
verifier "mot de passe de 7 caractères : 422" 422 "$(poster "$J" /inscription role=CLIENT 'nom=Test Court' \
    email=test-http-court@exemple.ma mot_de_passe=1234567 confirmation=1234567)"
verifier_contient "message « au moins 8 caractères »" "au moins 8 caractères" "$(cat "$TMP/corps")"
verifier "confirmation différente : 422" 422 "$(poster "$J" /inscription role=CLIENT 'nom=Test Conf' \
    email=test-http-conf@exemple.ma mot_de_passe=motdepasse1 confirmation=motdepasse2)"
verifier "email déjà utilisé : 422" 422 "$(poster "$J" /inscription role=CLIENT 'nom=Test Doublon' \
    email=AMINE.LAHLOU@exemple.ma mot_de_passe=motdepasse1 confirmation=motdepasse1)"
verifier_contient "message du package (-20008)" "Un compte existe déjà" "$(cat "$TMP/corps")"
verifier "rôle ADMIN refusé à l'inscription : 422" 422 "$(poster "$J" /inscription role=ADMIN 'nom=Pirate' \
    email=test-http-admin@exemple.ma mot_de_passe=motdepasse1 confirmation=motdepasse1)"

verifier "inscription valide (nom piégé) : 303" 303 "$(poster "$J" /inscription role=CLIENT \
    'nom=<script>alert(1)</script>' email=test-http-xss@exemple.ma mot_de_passe=motdepasse1 confirmation=motdepasse1)"
verifier "connecté automatiquement, redirigé vers /compte" /compte "$(location)"
page=$(curl -s -b "$J" "$BASE/compte")
verifier_contient "nom échappé dans la page (XSS)" "&lt;script&gt;alert(1)&lt;/script&gt;" "$page"
verifier "aucune balise <script>alert dans la page" "0" "$(grep -c '<script>alert' <<< "$page")"
: > "$TMP/vendeur2"
verifier "inscription vendeur : 303" 303 "$(poster "$TMP/vendeur2" /inscription role=VENDEUR 'nom=Vendeur Test' \
    email=test-http-vendeur@exemple.ma mot_de_passe=motdepasse1 confirmation=motdepasse1)"
verifier "vendeur inscrit : accès à /vendeur" 200 "$(code "$TMP/vendeur2" /vendeur)"

echo "--- Échecs de connexion"
verifier "mauvais mot de passe : 401" 401 "$(connecter "$TMP/x" test-http-xss@exemple.ma mauvais)"
message1=$(grep -o 'Email ou mot de passe incorrect' "$TMP/corps")
verifier "email inconnu : 401" 401 "$(connecter "$TMP/x" test-http-inconnu@exemple.ma mauvais)"
message2=$(grep -o 'Email ou mot de passe incorrect' "$TMP/corps")
verifier "même message que l'email existe ou non" "$message1" "$message2"
verifier "compte désactivé, bon mot de passe : 403" 403 "$(connecter "$TMP/x" nabil.sahraoui@exemple.ma)"

echo "--- Limitation par email (5 échecs en 15 minutes)"
effacer_echecs
for i in 1 2 3 4 5; do connecter "$TMP/x" test-http-xss@exemple.ma "mauvais$i" > /dev/null; done
verifier "6e essai avec le BON mot de passe : 429" 429 "$(connecter "$TMP/x" test-http-xss@exemple.ma motdepasse1)"
verifier_contient "message « Trop de tentatives »" "Trop de tentatives" "$(cat "$TMP/corps")"
verifier "un autre compte n'est pas bloqué" 303 "$(connecter "$TMP/autre" amine.lahlou@exemple.ma)"

echo "--- Limitation par IP (20 échecs en 15 minutes, emails tous différents)"
effacer_echecs
codes_ip=""
for i in $(seq 1 20); do codes_ip+="$(connecter "$TMP/x" "test-http-ip-$i@exemple.ma" mauvais) "; done
verifier "20 essais sur 20 emails différents : tous 401" "$(printf '401 %.0s' {1..20})" "$codes_ip"
verifier "21e essai, compte valide et bon mot de passe : 429" 429 "$(connecter "$TMP/x" amine.lahlou@exemple.ma)"
effacer_echecs
verifier "après effacement des échecs : connexion possible" 303 "$(connecter "$TMP/x" amine.lahlou@exemple.ma)"

echo "--- Expiration après inactivité (réglée à 3 secondes pour le test)"
relancer_php SESSION_INACTIVITE_SECONDES=3
: > "$TMP/exp"
connecter "$TMP/exp" amine.lahlou@exemple.ma > /dev/null
verifier "connecté : /compte accessible" 200 "$(code "$TMP/exp" /compte)"
sleep 2
verifier "activité à 2 s : toujours connecté (le délai repart)" 200 "$(code "$TMP/exp" /compte)"
sleep 4
curl -s -o /dev/null -D "$TMP/entetes" -b "$TMP/exp" -c "$TMP/exp" "$BASE/compte"
verifier "4 s sans activité : redirigé vers la connexion" "/connexion?retour=%2Fcompte" "$(location)"
verifier_contient "message « session a expiré »" "Votre session a expiré" "$(curl -s -b "$TMP/exp" -c "$TMP/exp" "$BASE/connexion")"

echo "--- Flag Secure forcé (SESSION_COOKIE_SECURE=1, comme en production HTTPS)"
relancer_php SESSION_COOKIE_SECURE=1
cookie=$(curl -s -o /dev/null -D - "$BASE/" | grep -i '^set-cookie: SOUKSESSID')
verifier_contient "cookie Secure" "secure" "$(tr 'A-Z' 'a-z' <<< "$cookie")"

echo
echo "BILAN HTTP : $OK OK, $ECHECS ÉCHEC"
[[ $ECHECS -eq 0 ]]
