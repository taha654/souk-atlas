// =============================================================================
// Socket : une connexion TCP, enveloppe RAII d'un descripteur de fichier POSIX.
//
// RAII ("l'acquisition d'une ressource est une initialisation") : le
// constructeur ouvre la connexion, le destructeur la ferme TOUJOURS (même si
// une exception est levée entre les deux). Impossible d'oublier close().
// La classe est "move-only" : copier un descripteur créerait deux objets qui
// fermeraient le même numéro ; on peut seulement transférer la propriété.
// =============================================================================
#pragma once

#include <chrono>
#include <stdexcept>
#include <string>
#include <string_view>

namespace souk {

class ErreurReseau : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

class Socket {
public:
    // Résout le nom (DNS), se connecte ; lève ErreurReseau en cas d'échec
    Socket(const std::string& hote, int port, std::chrono::seconds delai);
    ~Socket();

    Socket(const Socket&) = delete;
    Socket& operator=(const Socket&) = delete;
    Socket(Socket&& autre) noexcept;
    Socket& operator=(Socket&& autre) noexcept;

    void envoyerTout(std::string_view donnees);
    // Lit jusqu'à la fermeture par le serveur (HTTP/1.0), au plus tailleMax octets
    std::string lireTout(std::size_t tailleMax);

private:
    int fd_ = -1;
};

}  // namespace souk
