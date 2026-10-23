// =============================================================================
// ServiceApi : ce dont les commandes ont besoin pour parler au site.
//
// C'est une INTERFACE (classe abstraite) : les commandes ne savent pas si elles
// parlent au vrai site (ApiHttp, par le réseau) ou à une fausse API écrite pour
// les tests (tests/test_console.cpp). On peut ainsi tester toute la logique de
// la console sans serveur : c'est l'"injection de dépendance".
// =============================================================================
#pragma once

#include "ClientHttp.hpp"
#include "Json.hpp"

#include <stdexcept>
#include <string>

namespace souk {

// Réponse d'erreur de l'API (401, 403, 422…) ou réponse illisible
class ErreurApi : public std::runtime_error {
public:
    ErreurApi(int statut, const std::string& message) : std::runtime_error(message), statut_(statut) {}
    int statut() const noexcept { return statut_; }

private:
    int statut_;
};

class ServiceApi {
public:
    virtual ~ServiceApi() = default;
    virtual Json get(const std::string& chemin) = 0;
    virtual Json post(const std::string& chemin, const Json& corps) = 0;
};

// L'implémentation réelle : HTTP + jeton "Authorization: Bearer …"
class ApiHttp : public ServiceApi {
public:
    ApiHttp(ClientHttp client, std::string jeton);
    Json get(const std::string& chemin) override;
    Json post(const std::string& chemin, const Json& corps) override;

private:
    ClientHttp client_;
    std::string jeton_;

    Json traiter(const ReponseHttp& reponse) const;
};

}  // namespace souk
