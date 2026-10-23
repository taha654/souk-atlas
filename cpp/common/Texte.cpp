#include "Texte.hpp"

#include <cctype>

namespace souk::texte {

namespace {
// Lettres accentuées françaises en UTF-8 (2 octets : 0xC3 puis un second
// octet) → lettre sans accent, en minuscule
char sansAccent(unsigned char second) {
    switch (second) {
        case 0xA0: case 0xA2: case 0xA4: case 0xA1: case 0xA3: case 0xA5:   // à â ä á ã å
        case 0x80: case 0x82: case 0x84: case 0x81: case 0x83: case 0x85:   // À Â Ä Á Ã Å
            return 'a';
        case 0xA7: case 0x87: return 'c';                                    // ç Ç
        case 0xA8: case 0xA9: case 0xAA: case 0xAB:                          // è é ê ë
        case 0x88: case 0x89: case 0x8A: case 0x8B: return 'e';              // È É Ê Ë
        case 0xAC: case 0xAD: case 0xAE: case 0xAF:                          // ì í î ï
        case 0x8C: case 0x8D: case 0x8E: case 0x8F: return 'i';
        case 0xB1: case 0x91: return 'n';                                    // ñ Ñ
        case 0xB2: case 0xB3: case 0xB4: case 0xB5: case 0xB6:               // ò ó ô õ ö
        case 0x92: case 0x93: case 0x94: case 0x95: case 0x96: return 'o';
        case 0xB9: case 0xBA: case 0xBB: case 0xBC:                          // ù ú û ü
        case 0x99: case 0x9A: case 0x9B: case 0x9C: return 'u';
        case 0xBD: case 0xBF: case 0x9D: return 'y';                         // ý ÿ Ý
        default: return 0;
    }
}
}  // namespace

std::string normaliser(std::string_view texte) {
    std::string resultat;
    resultat.reserve(texte.size());
    for (std::size_t i = 0; i < texte.size(); ++i) {
        const auto c = static_cast<unsigned char>(texte[i]);
        if (c == 0xC3 && i + 1 < texte.size()) {
            const char lettre = sansAccent(static_cast<unsigned char>(texte[i + 1]));
            if (lettre != 0) {
                resultat += lettre;
                ++i;   // le second octet est consommé
                continue;
            }
        }
        resultat += static_cast<char>(c < 0x80 ? std::tolower(c) : c);
    }
    return resultat;
}

std::vector<std::string> mots(std::string_view normalise) {
    std::vector<std::string> resultat;
    std::string courant;
    for (const char c : normalise) {
        if (std::isalnum(static_cast<unsigned char>(c))) {
            courant += c;
        } else if (!courant.empty()) {
            resultat.push_back(std::move(courant));
            courant.clear();
        }
    }
    if (!courant.empty()) resultat.push_back(std::move(courant));
    return resultat;
}

bool contientExpression(std::string_view normalise, std::string_view expression) {
    const std::vector<std::string> texte = mots(normalise);
    const std::vector<std::string> cherches = mots(expression);
    if (cherches.empty() || cherches.size() > texte.size()) return false;
    for (std::size_t debut = 0; debut + cherches.size() <= texte.size(); ++debut) {
        bool egal = true;
        for (std::size_t k = 0; k < cherches.size() && egal; ++k) {
            egal = texte[debut + k] == cherches[k];
        }
        if (egal) return true;
    }
    return false;
}

double partDeMajuscules(std::string_view texte) {
    int lettres = 0;
    int majuscules = 0;
    for (const char c : texte) {
        const auto u = static_cast<unsigned char>(c);
        if (std::isalpha(u)) {
            ++lettres;
            if (std::isupper(u)) ++majuscules;
        }
    }
    return lettres == 0 ? 0.0 : static_cast<double>(majuscules) / lettres;
}

}  // namespace souk::texte
