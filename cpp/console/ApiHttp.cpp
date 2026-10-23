#include "Api.hpp"

namespace souk {

ApiHttp::ApiHttp(ClientHttp client, std::string jeton) : client_(std::move(client)), jeton_(std::move(jeton)) {}

Json ApiHttp::get(const std::string& chemin) {
    return traiter(client_.executer("GET", chemin, {{"Accept", "application/json"},
                                                     {"Authorization", "Bearer " + jeton_}}));
}

Json ApiHttp::post(const std::string& chemin, const Json& corps) {
    return traiter(client_.executer("POST", chemin, {{"Accept", "application/json"},
                                                      {"Authorization", "Bearer " + jeton_},
                                                      {"Content-Type", "application/json; charset=UTF-8"}},
                                    corps.serialiser()));
}

Json ApiHttp::traiter(const ReponseHttp& reponse) const {
    Json json;
    try {
        json = Json::analyser(reponse.corps);
    } catch (const ErreurJson&) {
        throw ErreurApi(reponse.statut, "réponse non JSON du serveur (HTTP " + std::to_string(reponse.statut) + ")");
    }
    if (reponse.statut < 200 || reponse.statut >= 300) {
        // Le site répond {"erreur": "Titre", "message": "Explication"}
        throw ErreurApi(reponse.statut, json.texteOu("message", json.texteOu("erreur", "erreur HTTP " + std::to_string(reponse.statut))));
    }
    return json;
}

}  // namespace souk
