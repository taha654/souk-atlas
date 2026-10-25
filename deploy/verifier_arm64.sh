#!/bin/bash
# =============================================================================
# À lancer sur VOTRE PC (WSL), pas sur le serveur : vérifie que l'image PHP de
# production se construit et fonctionne en linux/arm64, l'architecture des VM
# Ampere d'Oracle Cloud. Docker Desktop émule le processeur ARM64 (QEMU) :
# c'est lent (15 à 30 minutes la première fois), mais fidèle.
#
#   ./deploy/verifier_arm64.sh
#
# Vérifie : moteur C++ (compilé + tests CTest en ARM64), Instant Client ARM64,
# extension OCI8 (avec une vraie connexion à la base locale, si elle tourne),
# GD (JPEG, PNG, WebP), OPcache.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE=souk-atlas-prod-php:arm64
PLATEFORME=linux/arm64
ECHECS=0

verifier() {   # verifier "libellé" commande…
    local libelle="$1"; shift
    if "$@"; then echo "OK     $libelle"; else echo "ÉCHEC  $libelle"; ECHECS=$((ECHECS + 1)); fi
}
dans_image() { docker run --rm --platform "$PLATEFORME" "$IMAGE" "$@"; }

echo "==> Construction de l'image de production en $PLATEFORME (buildx)"
docker buildx build --platform "$PLATEFORME" --target production \
    --build-context cpp=./cpp --build-context code=. \
    -f docker/php/Dockerfile -t "$IMAGE" --load docker/php

echo
echo "==> Vérifications dans un conteneur $PLATEFORME"
verifier "architecture aarch64" test "$(dans_image uname -m)" = aarch64
# En-tête ELF : les octets 18-19 donnent le processeur visé (0xB7 = AArch64)
verifier "Instant Client : bibliothèques ARM64" \
    bash -c "docker run --rm --platform $PLATEFORME $IMAGE od -An -tx1 -j18 -N2 /opt/oracle/instantclient/libclntsh.so | grep -q 'b7 00'"
verifier "OCI8 : aucune bibliothèque manquante (ldd)" \
    bash -c "! docker run --rm --platform $PLATEFORME $IMAGE sh -c 'ldd \$(php-config --extension-dir)/oci8.so' | grep -q 'not found'"
modules="$(dans_image php -m)"
for module in oci8 gd timezonedb 'Zend OPcache'; do
    verifier "extension PHP chargée : $module" grep -qx "$module" <<< "$modules"
done
verifier "GD : JPEG, PNG et WebP" dans_image php -r '
    $i = gd_info();
    exit($i["JPEG Support"] && $i["PNG Support"] && $i["WebP Support"] ? 0 : 1);'
verifier "GD : création et encodage d'une image WebP" dans_image php -r '
    $img = imagecreatetruecolor(800, 600);
    imagefilledrectangle($img, 0, 0, 799, 599, imagecolorallocate($img, 31, 58, 147));
    ob_start(); imagewebp($img); $webp = ob_get_clean();
    exit(substr($webp, 8, 4) === "WEBP" ? 0 : 1);'
verifier "moteur C++ : souk-moteur répond en JSON" bash -c \
    "echo '{\"action\":\"risque_annonce\",\"annonce\":{\"titre\":\"URGENT\",\"prix\":100}}' \
     | docker run --rm -i --platform $PLATEFORME $IMAGE souk-moteur | grep -q '\"score\"'"
verifier "console C++ : souk-console s'exécute" bash -c \
    "docker run --rm --platform $PLATEFORME $IMAGE souk-console 2>&1 | grep -q Utilisation"
verifier "PHP de production : display_errors désactivé" \
    bash -c "docker run --rm --platform $PLATEFORME $IMAGE php -r 'exit(ini_get(\"display_errors\") ? 1 : 0);'"
verifier "aucun secret dans l'image (.env absent)" \
    bash -c "! docker run --rm --platform $PLATEFORME $IMAGE test -e /var/www/html/.env"

# Connexion réelle à la base Oracle LOCALE (amd64) depuis le conteneur ARM64 :
# prouve que l'Instant Client ARM64 et OCI8 parlent vraiment à Oracle
conteneur_oracle="$(docker compose ps -q oracle 2>/dev/null || true)"
if [[ -n "$conteneur_oracle" && -f .env ]]; then
    reseau="$(docker inspect -f '{{range $nom, $_ := .NetworkSettings.Networks}}{{$nom}}{{end}}' "$conteneur_oracle")"
    utilisateur="$(sed -n 's/^APP_USER=//p' .env)"
    verifier "OCI8 : requête sur la base Oracle locale" \
        docker run --rm --platform "$PLATEFORME" --network "$reseau" \
            -e DB_USER="$utilisateur" -e DB_PASSWORD="$(sed -n 's/^APP_USER_PASSWORD=//p' .env)" \
            "$IMAGE" php -r '
                $c = oci_connect(getenv("DB_USER"), getenv("DB_PASSWORD"), "//oracle:1521/FREEPDB1", "AL32UTF8");
                if (!$c) { fwrite(STDERR, oci_error()["message"] . "\n"); exit(1); }
                $s = oci_parse($c, "SELECT COUNT(*) AS nb FROM produit");
                oci_execute($s);
                $nb = (int) oci_fetch_assoc($s)["NB"];
                echo "       ($nb produits lus depuis ARM64)\n";
                exit($nb > 0 ? 0 : 1);'
else
    echo "-      base locale arrêtée : connexion OCI8 non testée (docker compose up -d, puis relancer)"
fi

echo
if [[ $ECHECS -eq 0 ]]; then
    echo "BILAN ARM64 : tout est OK"
else
    echo "BILAN ARM64 : $ECHECS échec(s)"
    exit 1
fi
