// =============================================================================
// Client HTTP minimal, écrit à la main pour voir ce que fait un navigateur :
//
//   GET /api/console/moi HTTP/1.0        ← ligne de requête
//   Host: localhost                      ← en-têtes
//   Authorization: Bearer souk_…
//                                        ← ligne vide
//   (corps éventuel)
//
// HTTP/1.0 et non 1.1 : le serveur ferme la connexion à la fin de la réponse
// et n'utilise pas l'encodage "chunked" ; lire jusqu'à la fermeture suffit.
// Limite assumée : pas de HTTPS (il faudrait une bibliothèque TLS, OpenSSL ou
// libcurl). Le site de développement est en HTTP sur localhost.
// =============================================================================
#pragma once

#include <chrono>
#include <map>
#include <string>

namespace souk {

struct Url {
    std::string hote;
    int port = 80;
    std::string prefixe;   // chemin de base, sans "/" final ("" ou "/souk")

    // "http://localhost:8000" → {localhost, 8000, ""} ; lève std::invalid_argument
    static Url analyser(const std::string& texte);
};

struct ReponseHttp {
    int statut = 0;
    std::map<std::string, std::string> entetes;   // noms en minuscules
    std::string corps;

    // Découpe une réponse brute (ligne de statut, en-têtes, corps) ;
    // décode aussi un corps "chunked" par précaution. Lève std::runtime_error.
    static ReponseHttp analyser(const std::string& brut);
};

// "Électroménager & co" → "%C3%89lectrom%C3%A9nager%20%26%20co"
std::string encoderUrl(const std::string& texte);

class ClientHttp {
public:
    explicit ClientHttp(Url url, std::chrono::seconds delai = std::chrono::seconds(20));

    ReponseHttp executer(const std::string& methode, const std::string& chemin,
                         const std::map<std::string, std::string>& entetes, const std::string& corps = "") const;

    const Url& url() const noexcept { return url_; }

private:
    Url url_;
    std::chrono::seconds delai_;
};

}  // namespace souk
