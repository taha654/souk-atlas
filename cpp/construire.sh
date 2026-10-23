#!/usr/bin/env bash
# =============================================================================
# Compile les composants C++ et lance leurs tests, dans un conteneur Docker
# (rien à installer sous WSL : g++ et CMake viennent de l'image).
#   ./cpp/construire.sh             compilation + tests
#   ./cpp/construire.sh --sanitizers  idem avec AddressSanitizer et UBSan
# Le résultat va dans cpp/build/ (ignoré par git).
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

options=""
dossier=build
lanceur=""
docker_options=()
if [[ "${1:-}" == "--sanitizers" ]]; then
    options="-DSOUK_SANITIZERS=ON"
    dossier=build-sanitizers
    # AddressSanitizer de GCC 12 se bloque au hasard sur les noyaux Linux >= 6.5
    # (adresses mémoire trop aléatoires). "setarch -R" coupe cet aléa (ASLR) pour
    # les tests ; Docker n'autorise ce réglage qu'avec seccomp=unconfined, ce qui
    # est acceptable pour ce conteneur jetable, jamais pour le site.
    lanceur="setarch -R"
    docker_options=(--security-opt seccomp=unconfined)
fi

docker build -q -t souk-cpp -f ../docker/cpp/Dockerfile .. > /dev/null
docker run --rm "${docker_options[@]}" -u "$(id -u):$(id -g)" -v "$PWD":/src -w /src souk-cpp sh -c "
    cmake -S . -B $dossier -DCMAKE_BUILD_TYPE=Debug $options > /dev/null &&
    cmake --build $dossier -j \$(nproc) &&
    $lanceur ctest --test-dir $dossier --output-on-failure"
