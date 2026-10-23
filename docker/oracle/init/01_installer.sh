#!/bin/bash
# Exécuté une seule fois, à la création de la base (premier démarrage du conteneur) :
# installe le schéma complet de Souk Atlas avec les données de démonstration.
set -e
/opt/souk/database/installer.sh
