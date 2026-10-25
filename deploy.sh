#!/bin/bash
# =============================================================================
# Déploie (ou met à jour) Souk Atlas sur le serveur de production.
# À lancer SUR LE SERVEUR, dans le dossier cloné :
#
#   ./deploy.sh                                   premier déploiement ou mise à jour
#   DOMAINE=souk.exemple.ma ACME_EMAIL=moi@exemple.ma ./deploy.sh   (sans questions)
#
# Options : --sans-maj   ne pas faire "git pull" (déployer le code tel qu'il est)
#           --sans-cron  ne pas installer les tâches planifiées
#
# 1er lancement : crée le .env DU SERVEUR, avec des mots de passe générés ici.
# Lancements suivants : récupère la dernière version, reconstruit l'image PHP,
# redémarre ce qui a changé. La base, les photos et les certificats sont gardés.
# Guide pas à pas : docs/deploiement.md
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

COMPOSE=(docker compose -f docker-compose.prod.yml)
SANS_MAJ=0
SANS_CRON=0
for option in "$@"; do
    case "$option" in
        --sans-maj) SANS_MAJ=1 ;;
        --sans-cron) SANS_CRON=1 ;;
        *) echo "Option inconnue : $option (voir l'en-tête du script)" >&2; exit 2 ;;
    esac
done

erreur() { echo "ERREUR : $*" >&2; exit 1; }
etape() { echo; echo "==> $*"; }
# Valeur d'une variable du .env (format simple NOM=valeur, sans guillemets)
valeur_env() { sed -n "s/^$1=//p" .env | tail -n 1; }

# --- 1. Dernière version du code ---------------------------------------------
# "git pull" peut modifier CE script pendant qu'il tourne (bash le lit au fur
# et à mesure). On relance donc le script à jour avec "exec", une seule fois.
if [[ $SANS_MAJ -eq 0 && -z "${SOUK_DEPLOY_A_JOUR:-}" && -d .git ]]; then
    etape "Récupération de la dernière version (git pull)"
    git pull --ff-only
    SOUK_DEPLOY_A_JOUR=1 exec "$0" "$@"
fi

# --- 2. Prérequis ------------------------------------------------------------
etape "Vérification des prérequis"
command -v docker >/dev/null || erreur "Docker n'est pas installé (docs/deploiement.md, étape 4)."
docker compose version >/dev/null 2>&1 || erreur "Le plugin « docker compose » est absent."
docker info >/dev/null 2>&1 \
    || erreur "Docker refuse la connexion : déconnectez-vous puis reconnectez-vous après « usermod -aG docker »."
if [[ "$(uname -m)" != aarch64 ]]; then
    echo "Remarque : machine $(uname -m) et non ARM64. Ça fonctionne aussi, le guide vise une VM Ampere."
fi
echo "Docker $(docker version --format '{{.Server.Version}}'), $(docker compose version --short) : OK"

# --- 3. Le .env du serveur ---------------------------------------------------
# 30 caractères : une lettre puis 29 lettres ou chiffres (≈ 170 bits de hasard).
# Pas de symboles : Oracle exige une lettre en tête, et "@" ou "/" casseraient
# les chaînes de connexion "utilisateur/motdepasse@//hôte/service".
generer_mot_de_passe() {
    local brut
    brut=$(openssl rand -base64 96)
    brut=${brut//[^A-Za-z0-9]/}
    printf 'S%s' "${brut:0:29}"
}

if [[ ! -f .env ]]; then
    etape "Création du .env du serveur"
    domaine="${DOMAINE:-}"
    email="${ACME_EMAIL:-}"
    if [[ -z "$domaine" ]]; then
        [[ -t 0 ]] || erreur "DOMAINE non fourni (DOMAINE=… ./deploy.sh)."
        read -rp "Nom de domaine du site (ex. souk.mondomaine.ma ou 1-2-3-4.sslip.io) : " domaine
    fi
    if [[ -z "$email" ]]; then
        [[ -t 0 ]] || erreur "ACME_EMAIL non fourni (ACME_EMAIL=… ./deploy.sh)."
        read -rp "Email pour Let's Encrypt (alertes de certificat) : " email
    fi
    domaine="${domaine,,}"
    [[ "$domaine" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$ || "$domaine" == localhost ]] \
        || erreur "Nom de domaine invalide : $domaine"
    [[ "$email" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] || erreur "Email invalide : $email"

    # umask 077 : le fichier est créé lisible par son seul propriétaire (600)
    (
        umask 077
        cat > .env <<EOF
# .env du SERVEUR, créé par deploy.sh le $(date '+%Y-%m-%d %H:%M').
# Mots de passe générés sur ce serveur : ne le copiez jamais ailleurs, ne le
# committez jamais (il est dans .gitignore). Sauvegardé par deploy/sauvegarder.sh.

# Comptes administrateurs Oracle (SYS, SYSTEM)
ORACLE_PASSWORD=$(generer_mot_de_passe)
# Propriétaire du schéma du site
APP_USER=SOUK
APP_USER_PASSWORD=$(generer_mot_de_passe)

# Adresse publique : Caddy demande le certificat HTTPS pour ce nom
DOMAINE=$domaine
ACME_EMAIL=$email

# 1 = site de démonstration public (bandeau, admin bridé, envois limités,
#     données réinitialisées chaque nuit par deploy/reinitialiser_demo.sh)
DEMO_MODE=1
EOF
    )
    echo ".env créé (droits 600). Mots de passe générés, jamais affichés."
else
    etape "Vérification du .env existant"
    # Garde-fou : un .env de développement copié par erreur sur le serveur
    if grep -q 'change_moi' .env; then
        erreur ".env contient encore « change_moi » : ce sont les valeurs d'exemple."
    fi
    for variable in ORACLE_PASSWORD APP_USER_PASSWORD DOMAINE ACME_EMAIL; do
        [[ -n "$(valeur_env "$variable")" ]] \
            || erreur "$variable manque dans .env (est-ce le .env du développement ? Renommez-le et relancez)."
    done
    [[ "$(stat -c %a .env)" == 600 ]] || { chmod 600 .env; echo ".env remis en droits 600."; }
    echo "OK"
fi
DOMAINE_SITE="$(valeur_env DOMAINE)"

# --- 4. Construction et lancement --------------------------------------------
etape "Construction de l'image PHP (première fois : 10 à 15 minutes)"
# --pull : repartir des dernières images de base (correctifs de sécurité)
"${COMPOSE[@]}" build --pull php

etape "Lancement des conteneurs"
"${COMPOSE[@]}" up -d --remove-orphans

etape "Attente de la base Oracle (premier lancement : création et installation du schéma, plusieurs minutes)"
for _ in $(seq 1 90); do
    etat=$("${COMPOSE[@]}" ps --format '{{.Health}}' oracle 2>/dev/null || true)
    [[ "$etat" == healthy ]] && break
    sleep 10
done
[[ "$etat" == healthy ]] || erreur "Oracle n'est pas prêt après 15 minutes : ${COMPOSE[*]} logs oracle"
echo "Oracle : prêt"

etape "Vérification du site (depuis le conteneur PHP)"
for _ in $(seq 1 30); do
    if "${COMPOSE[@]}" exec -T php curl -fsS -o /dev/null http://localhost/catalogue 2>/dev/null; then
        echo "PHP + Oracle : OK"
        break
    fi
    sleep 5
done
"${COMPOSE[@]}" exec -T php curl -fsS -o /dev/null http://localhost/catalogue \
    || erreur "Le site ne répond pas : ${COMPOSE[*]} logs php"

# Anciennes images PHP devenues inutiles après une mise à jour
docker image prune -f >/dev/null

# --- 5. Tâches planifiées ----------------------------------------------------
# L'heure de la VM est en UTC : 3 h UTC = 4 h au Maroc (UTC+1).
if [[ $SANS_CRON -eq 0 ]]; then
    etape "Installation des tâches planifiées (crontab de $(whoami))"
    dossier="$(pwd)"
    journaux="$HOME/souk-journaux"
    mkdir -p "$journaux"
    bloc="# >>> souk-atlas (géré par deploy.sh : modifications écrasées au prochain déploiement)
30 2 * * * $dossier/deploy/sauvegarder.sh >> $journaux/sauvegarde.log 2>&1
0 3 * * * $dossier/deploy/reinitialiser_demo.sh >> $journaux/reinitialisation.log 2>&1
# <<< souk-atlas"
    # On retire l'ancien bloc (s'il existe) puis on ajoute le nouveau : relancer
    # deploy.sh ne crée jamais de doublon, et les autres lignes sont gardées
    { crontab -l 2>/dev/null | sed '/^# >>> souk-atlas/,/^# <<< souk-atlas/d' || true; echo "$bloc"; } | crontab -
    echo "Sauvegarde à 2 h 30 UTC, réinitialisation de la démo à 3 h UTC (journaux : $journaux)"
fi

# --- 6. Résumé ---------------------------------------------------------------
etape "Terminé"
"${COMPOSE[@]}" ps
echo
echo "Site : https://$DOMAINE_SITE"
echo "(Le premier certificat HTTPS est obtenu à la première visite : quelques secondes.)"
echo "Journaux : ${COMPOSE[*]} logs -f"
