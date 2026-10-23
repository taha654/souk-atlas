#include "ClientHttp.hpp"

#include "Socket.hpp"

#include <cctype>
#include <cstdio>
#include <stdexcept>

namespace souk {

Url Url::analyser(const std::string& texte) {
    const std::string schema = "http://";
    if (texte.rfind("https://", 0) == 0) {
        throw std::invalid_argument("HTTPS n'est pas pris en charge par ce client minimal (voir ClientHttp.hpp)");
    }
    if (texte.rfind(schema, 0) != 0) throw std::invalid_argument("l'URL doit commencer par http://");

    std::string reste = texte.substr(schema.size());
    Url url;
    const std::size_t barre = reste.find('/');
    std::string autorite = reste.substr(0, barre);
    url.prefixe = barre == std::string::npos ? "" : reste.substr(barre);
    while (!url.prefixe.empty() && url.prefixe.back() == '/') url.prefixe.pop_back();

    const std::size_t deuxPoints = autorite.rfind(':');
    if (deuxPoints != std::string::npos) {
        const std::string port = autorite.substr(deuxPoints + 1);
        if (port.empty() || port.size() > 5 || port.find_first_not_of("0123456789") != std::string::npos) {
            throw std::invalid_argument("port invalide dans l'URL");
        }
        url.port = std::stoi(port);
        if (url.port < 1 || url.port > 65535) throw std::invalid_argument("port hors limites");
        autorite.resize(deuxPoints);
    }
    if (autorite.empty()) throw std::invalid_argument("nom de machine manquant dans l'URL");
    url.hote = autorite;
    return url;
}

namespace {

std::string minuscules(std::string texte) {
    for (char& c : texte) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return texte;
}

std::string sansEspaces(const std::string& texte) {
    const std::size_t debut = texte.find_first_not_of(" \t");
    const std::size_t fin = texte.find_last_not_of(" \t\r");
    return debut == std::string::npos ? "" : texte.substr(debut, fin - debut + 1);
}

// Corps "chunked" : suite de blocs "taille en hexa\r\n" + données + "\r\n", terminée par un bloc de taille 0
std::string decoderChunked(const std::string& corps) {
    std::string resultat;
    std::size_t pos = 0;
    while (true) {
        const std::size_t finLigne = corps.find("\r\n", pos);
        if (finLigne == std::string::npos) throw std::runtime_error("corps chunked tronqué");
        const std::size_t taille = std::stoul(corps.substr(pos, finLigne - pos), nullptr, 16);
        pos = finLigne + 2;
        if (taille == 0) return resultat;
        if (pos + taille > corps.size()) throw std::runtime_error("corps chunked tronqué");
        resultat.append(corps, pos, taille);
        pos += taille + 2;
    }
}

}  // namespace

ReponseHttp ReponseHttp::analyser(const std::string& brut) {
    const std::size_t finEntetes = brut.find("\r\n\r\n");
    if (finEntetes == std::string::npos) throw std::runtime_error("réponse HTTP incomplète");

    ReponseHttp reponse;
    std::size_t pos = brut.find("\r\n");
    const std::string ligneStatut = brut.substr(0, pos);   // "HTTP/1.1 200 OK"
    if (ligneStatut.rfind("HTTP/", 0) != 0 || ligneStatut.size() < 12) throw std::runtime_error("ligne de statut invalide");
    reponse.statut = std::stoi(ligneStatut.substr(ligneStatut.find(' ') + 1, 3));

    while (pos < finEntetes) {
        const std::size_t debut = pos + 2;
        pos = brut.find("\r\n", debut);
        const std::string ligne = brut.substr(debut, pos - debut);
        const std::size_t deuxPoints = ligne.find(':');
        if (deuxPoints != std::string::npos) {
            reponse.entetes[minuscules(ligne.substr(0, deuxPoints))] = sansEspaces(ligne.substr(deuxPoints + 1));
        }
    }
    reponse.corps = brut.substr(finEntetes + 4);

    const auto encodage = reponse.entetes.find("transfer-encoding");
    const auto longueur = reponse.entetes.find("content-length");
    if (encodage != reponse.entetes.end() && minuscules(encodage->second) == "chunked") {
        reponse.corps = decoderChunked(reponse.corps);
    } else if (longueur != reponse.entetes.end()) {
        const std::size_t annonce = std::stoul(longueur->second);
        if (reponse.corps.size() < annonce) throw std::runtime_error("réponse tronquée");
        reponse.corps.resize(annonce);
    }
    return reponse;
}

std::string encoderUrl(const std::string& texte) {
    std::string resultat;
    for (const char c : texte) {
        const auto u = static_cast<unsigned char>(c);
        if (std::isalnum(u) || c == '-' || c == '_' || c == '.' || c == '~') {
            resultat += c;
        } else {
            char code[4];
            std::snprintf(code, sizeof code, "%%%02X", static_cast<unsigned>(u));
            resultat += code;
        }
    }
    return resultat;
}

ClientHttp::ClientHttp(Url url, std::chrono::seconds delai) : url_(std::move(url)), delai_(delai) {}

ReponseHttp ClientHttp::executer(const std::string& methode, const std::string& chemin,
                                 const std::map<std::string, std::string>& entetes, const std::string& corps) const {
    std::string requete = methode + " " + url_.prefixe + chemin + " HTTP/1.0\r\n";
    requete += "Host: " + url_.hote + (url_.port == 80 ? "" : ":" + std::to_string(url_.port)) + "\r\n";
    requete += "User-Agent: souk-console/1.0\r\n";
    for (const auto& [nom, valeur] : entetes) {
        // Un saut de ligne dans une valeur permettrait d'injecter un en-tête
        if (valeur.find_first_of("\r\n") != std::string::npos) throw std::invalid_argument("en-tête HTTP invalide : " + nom);
        requete += nom + ": " + valeur + "\r\n";
    }
    if (!corps.empty() || methode == "POST") requete += "Content-Length: " + std::to_string(corps.size()) + "\r\n";
    requete += "\r\n";
    requete += corps;

    Socket socket(url_.hote, url_.port, delai_);
    socket.envoyerTout(requete);
    return ReponseHttp::analyser(socket.lireTout(64 * 1024 * 1024));
}

}  // namespace souk
