# Outils de compilation C++ (g++ 12, CMake) pour cpp/construire.sh :
# compiler et tester sans rien installer sous WSL.
# (L'image du site compile le moteur avec la même base : docker/php/Dockerfile.)
FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends g++ cmake make util-linux \
    && rm -rf /var/lib/apt/lists/*
