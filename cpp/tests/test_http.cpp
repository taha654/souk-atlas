#include "ClientHttp.hpp"
#include "Socket.hpp"
#include "Verif.hpp"

using namespace souk;

int main() {
    // --- URL
    const Url u = Url::analyser("http://localhost:8000/souk/");
    VERIFIER_EGAL(std::string("localhost"), u.hote);
    VERIFIER_EGAL(8000, u.port);
    VERIFIER_EGAL(std::string("/souk"), u.prefixe);
    VERIFIER_EGAL(80, Url::analyser("http://exemple.ma").port);
    VERIFIER_EXCEPTION(Url::analyser("https://exemple.ma"), std::invalid_argument);
    VERIFIER_EXCEPTION(Url::analyser("ftp://exemple.ma"), std::invalid_argument);
    VERIFIER_EXCEPTION(Url::analyser("http://:80"), std::invalid_argument);
    VERIFIER_EXCEPTION(Url::analyser("http://hote:99999"), std::invalid_argument);
    VERIFIER_EXCEPTION(Url::analyser("http://hote:8a"), std::invalid_argument);

    // --- Encodage d'URL
    VERIFIER_EGAL(std::string("2026-01-31"), encoderUrl("2026-01-31"));
    VERIFIER_EGAL(std::string("a%20b%26c%3Dd"), encoderUrl("a b&c=d"));
    VERIFIER_EGAL(std::string("%C3%A9t%C3%A9"), encoderUrl("été"));

    // --- Analyse d'une réponse
    const auto r = ReponseHttp::analyser("HTTP/1.1 401 Unauthorized\r\nContent-Type: application/json\r\n"
                                         "WWW-Authenticate:  Bearer \r\nContent-Length: 13\r\n\r\n{\"ok\":false}\nRESTE");
    VERIFIER_EGAL(401, r.statut);
    VERIFIER_EGAL(std::string("Bearer"), r.entetes.at("www-authenticate"));   // nom en minuscules, espaces retirés
    VERIFIER_EGAL(std::string("{\"ok\":false}\n"), r.corps);                   // coupé à Content-Length
    const auto c = ReponseHttp::analyser("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n4\r\nSouk\r\n6\r\n Atlas\r\n0\r\n\r\n");
    VERIFIER_EGAL(std::string("Souk Atlas"), c.corps);
    VERIFIER_EXCEPTION(ReponseHttp::analyser("HTTP/1.1 200 OK\r\n"), std::runtime_error);   // en-têtes incomplets
    VERIFIER_EXCEPTION(ReponseHttp::analyser("BONJOUR\r\n\r\n"), std::runtime_error);
    VERIFIER_EXCEPTION(ReponseHttp::analyser("HTTP/1.0 200 OK\r\nContent-Length: 50\r\n\r\ncourt"), std::runtime_error);

    // --- Réseau : port fermé et nom inconnu → ErreurReseau (pas de plantage)
    VERIFIER_EXCEPTION(Socket("127.0.0.1", 1, std::chrono::seconds(2)), ErreurReseau);
    VERIFIER_EXCEPTION(Socket("hote.inexistant.invalid", 80, std::chrono::seconds(2)), ErreurReseau);
    const ClientHttp client(Url::analyser("http://127.0.0.1:1"));
    VERIFIER_EXCEPTION(client.executer("GET", "/", {{"X-Test", "a\r\nInjecte: oui"}}), std::invalid_argument);
    return verif::bilan();
}
