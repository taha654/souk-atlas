// =============================================================================
// souk-console : outil d'administration en ligne de commande de Souk Atlas.
// Il passe par l'API JSON du site (jamais directement par la base) : les
// mêmes règles de rôle et de validation s'appliquent qu'en ligne.
//
//   export SOUK_JETON=souk_…              (Mon compte → Jetons d'accès)
//   souk-console import-csv catalogue.csv --rapport erreurs.csv
//   souk-console rapport --debut 2026-01-01 --fin 2026-03-31 --sortie ventes.csv
//   souk-console moderation liste
//
// Le jeton se passe par une variable d'environnement plutôt qu'en argument :
// un argument est visible de tous les utilisateurs de la machine (commande ps)
// et reste dans l'historique du shell.
// =============================================================================
#include "Console.hpp"

#include <cstdlib>
#include <iostream>

int main(int argc, char* argv[]) {
    const std::vector<std::string> args(argv + 1, argv + argc);

    const char* url = std::getenv("SOUK_URL");
    const char* jeton = std::getenv("SOUK_JETON");

    std::unique_ptr<souk::ServiceApi> api;
    try {
        if (jeton != nullptr && *jeton != '\0') {
            api = std::make_unique<souk::ApiHttp>(
                souk::ClientHttp(souk::Url::analyser(url != nullptr && *url != '\0' ? url : "http://localhost")), jeton);
        } else {
            api = std::make_unique<souk::ApiSansJeton>();
        }
    } catch (const std::invalid_argument& e) {
        std::cerr << "SOUK_URL invalide : " << e.what() << '\n';
        return souk::kUsage;
    }

    souk::Contexte contexte{*api, std::cout, std::cerr};
    return souk::Console().lancer(args, contexte);
}
