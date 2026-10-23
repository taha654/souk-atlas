#include "Socket.hpp"

#include <cerrno>
#include <cstring>
#include <netdb.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>
#include <utility>

namespace souk {

namespace {
std::string messageSysteme(const std::string& action) { return action + " : " + std::strerror(errno); }

// Ferme le résultat de getaddrinfo quoi qu'il arrive (RAII là aussi)
struct ListeAdresses {
    addrinfo* tete = nullptr;
    ~ListeAdresses() { if (tete != nullptr) freeaddrinfo(tete); }
};
}  // namespace

Socket::Socket(const std::string& hote, int port, std::chrono::seconds delai) {
    addrinfo criteres{};
    criteres.ai_family = AF_UNSPEC;       // IPv4 ou IPv6
    criteres.ai_socktype = SOCK_STREAM;   // TCP
    ListeAdresses adresses;
    const int code = getaddrinfo(hote.c_str(), std::to_string(port).c_str(), &criteres, &adresses.tete);
    if (code != 0) throw ErreurReseau("adresse « " + hote + " » introuvable : " + gai_strerror(code));

    // Une machine peut avoir plusieurs adresses : on essaie chacune
    std::string derniereErreur = "aucune adresse";
    for (addrinfo* a = adresses.tete; a != nullptr; a = a->ai_next) {
        const int fd = ::socket(a->ai_family, a->ai_socktype, a->ai_protocol);
        if (fd < 0) { derniereErreur = messageSysteme("socket"); continue; }
        // Délais d'envoi et de réception (sous Linux, SO_SNDTIMEO borne aussi connect())
        timeval tv{};
        tv.tv_sec = static_cast<time_t>(delai.count());
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof tv);
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof tv);
        if (::connect(fd, a->ai_addr, a->ai_addrlen) == 0) {
            fd_ = fd;
            return;
        }
        derniereErreur = messageSysteme("connexion à " + hote + ":" + std::to_string(port));
        ::close(fd);
    }
    throw ErreurReseau(derniereErreur);
}

Socket::~Socket() {
    if (fd_ >= 0) ::close(fd_);
}

Socket::Socket(Socket&& autre) noexcept : fd_(std::exchange(autre.fd_, -1)) {}

Socket& Socket::operator=(Socket&& autre) noexcept {
    if (this != &autre) {
        if (fd_ >= 0) ::close(fd_);
        fd_ = std::exchange(autre.fd_, -1);
    }
    return *this;
}

void Socket::envoyerTout(std::string_view donnees) {
    // send() peut n'envoyer qu'une partie : on boucle jusqu'au bout
    while (!donnees.empty()) {
        // MSG_NOSIGNAL : si le serveur a fermé, erreur EPIPE au lieu de tuer le programme (SIGPIPE)
        const ssize_t n = ::send(fd_, donnees.data(), donnees.size(), MSG_NOSIGNAL);
        if (n < 0) {
            if (errno == EINTR) continue;
            throw ErreurReseau(messageSysteme("envoi"));
        }
        donnees.remove_prefix(static_cast<std::size_t>(n));
    }
}

std::string Socket::lireTout(std::size_t tailleMax) {
    std::string resultat;
    char tampon[16384];
    while (true) {
        const ssize_t n = ::recv(fd_, tampon, sizeof tampon, 0);
        if (n == 0) return resultat;   // le serveur a fermé : réponse complète
        if (n < 0) {
            if (errno == EINTR) continue;
            if (errno == EAGAIN || errno == EWOULDBLOCK) throw ErreurReseau("le serveur ne répond plus (délai dépassé)");
            throw ErreurReseau(messageSysteme("réception"));
        }
        resultat.append(tampon, static_cast<std::size_t>(n));
        if (resultat.size() > tailleMax) throw ErreurReseau("réponse trop volumineuse");
    }
}

}  // namespace souk
