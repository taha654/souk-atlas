#include "Levenshtein.hpp"

#include <algorithm>
#include <numeric>
#include <vector>

namespace souk {

std::size_t distanceLevenshtein(std::u32string_view a, std::u32string_view b, bool transpositions) {
    if (a.size() < b.size()) std::swap(a, b);   // b est le plus court : lignes plus petites
    if (b.empty()) return a.size();

    // avant-dernière (pour les transpositions), précédente, courante
    std::vector<std::size_t> avantDerniere(b.size() + 1);
    std::vector<std::size_t> precedente(b.size() + 1);
    std::vector<std::size_t> courante(b.size() + 1);
    std::iota(precedente.begin(), precedente.end(), 0);   // de "" à b[0..j) : j insertions

    for (std::size_t i = 1; i <= a.size(); ++i) {
        courante[0] = i;   // de a[0..i) à "" : i suppressions
        for (std::size_t j = 1; j <= b.size(); ++j) {
            const std::size_t cout = a[i - 1] == b[j - 1] ? 0 : 1;
            courante[j] = std::min({precedente[j] + 1,            // suppression
                                    courante[j - 1] + 1,          // insertion
                                    precedente[j - 1] + cout});   // remplacement (ou rien)
            if (transpositions && i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
                courante[j] = std::min(courante[j], avantDerniere[j - 2] + 1);
            }
        }
        // Rotation des lignes sans copie : swap échange seulement les pointeurs internes
        std::swap(avantDerniere, precedente);
        std::swap(precedente, courante);
    }
    return precedente[b.size()];
}

std::u32string versCodePoints(std::string_view utf8) {
    std::u32string resultat;
    for (std::size_t i = 0; i < utf8.size();) {
        const auto c = static_cast<unsigned char>(utf8[i]);
        // Le premier octet indique la longueur : 0xxxxxxx (1), 110xxxxx (2), 1110xxxx (3), 11110xxx (4)
        const std::size_t longueur = c < 0x80 ? 1 : (c >> 5) == 0x6 ? 2 : (c >> 4) == 0xE ? 3 : (c >> 3) == 0x1E ? 4 : 1;
        if (i + longueur > utf8.size()) break;   // séquence tronquée : on s'arrête
        char32_t code = longueur == 1 ? c : longueur == 2 ? (c & 0x1F) : longueur == 3 ? (c & 0x0F) : (c & 0x07);
        for (std::size_t k = 1; k < longueur; ++k) code = (code << 6) | (static_cast<unsigned char>(utf8[i + k]) & 0x3F);
        resultat += code;
        i += longueur;
    }
    return resultat;
}

}  // namespace souk
