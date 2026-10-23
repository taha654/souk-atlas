#include "Json.hpp"

#include <cmath>
#include <cstdio>
#include <cstdlib>

namespace souk {

ErreurJson::ErreurJson(const std::string& message, std::size_t position)
    : std::runtime_error(message + " (position " + std::to_string(position) + ")"), position_(position) {}

namespace {

// Analyseur à descente récursive : il avance dans le texte caractère par caractère
class Analyseur {
public:
    explicit Analyseur(std::string_view texte) : texte_(texte) {}

    Json document() {
        Json resultat = valeur(0);
        espaces();
        if (pos_ != texte_.size()) {
            erreur("caractères en trop après la valeur JSON");
        }
        return resultat;
    }

private:
    // Profondeur maximale : un texte malveillant "[[[[[[…" ne doit pas faire
    // déborder la pile d'appels (chaque niveau = un appel récursif)
    static constexpr int kProfondeurMax = 64;

    std::string_view texte_;
    std::size_t pos_ = 0;

    [[noreturn]] void erreur(const std::string& message) const { throw ErreurJson(message, pos_); }

    void espaces() {
        while (pos_ < texte_.size() && (texte_[pos_] == ' ' || texte_[pos_] == '\t'
                                        || texte_[pos_] == '\n' || texte_[pos_] == '\r')) {
            ++pos_;
        }
    }

    char courant() const { return pos_ < texte_.size() ? texte_[pos_] : '\0'; }

    void attendre(char c) {
        if (courant() != c) {
            erreur(std::string("'") + c + "' attendu");
        }
        ++pos_;
    }

    Json valeur(int profondeur) {
        if (profondeur > kProfondeurMax) {
            erreur("imbrication trop profonde");
        }
        espaces();
        switch (courant()) {
            case '{': return objet(profondeur);
            case '[': return tableau(profondeur);
            case '"': return Json(chaine());
            case 't': litteral("true"); return Json(true);
            case 'f': litteral("false"); return Json(false);
            case 'n': litteral("null"); return Json();
            default: return Json(nombre());
        }
    }

    void litteral(std::string_view mot) {
        if (texte_.substr(pos_, mot.size()) != mot) {
            erreur("valeur inconnue");
        }
        pos_ += mot.size();
    }

    Json objet(int profondeur) {
        attendre('{');
        Json::Objet membres;
        espaces();
        if (courant() == '}') {
            ++pos_;
            return Json(std::move(membres));
        }
        while (true) {
            espaces();
            if (courant() != '"') {
                erreur("nom de membre attendu");
            }
            std::string cle = chaine();
            espaces();
            attendre(':');
            membres[std::move(cle)] = valeur(profondeur + 1);
            espaces();
            if (courant() == ',') { ++pos_; continue; }
            attendre('}');
            return Json(std::move(membres));
        }
    }

    Json tableau(int profondeur) {
        attendre('[');
        Json::Tableau elements;
        espaces();
        if (courant() == ']') {
            ++pos_;
            return Json(std::move(elements));
        }
        while (true) {
            elements.push_back(valeur(profondeur + 1));
            espaces();
            if (courant() == ',') { ++pos_; continue; }
            attendre(']');
            return Json(std::move(elements));
        }
    }

    double nombre() {
        // Grammaire JSON : -?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?
        const std::size_t debut = pos_;
        auto chiffres = [this] {
            const std::size_t avant = pos_;
            while (courant() >= '0' && courant() <= '9') ++pos_;
            return pos_ > avant;
        };
        if (courant() == '-') ++pos_;
        if (courant() == '0') {
            ++pos_;
        } else if (!chiffres()) {
            erreur("valeur JSON attendue");
        }
        if (courant() == '.') {
            ++pos_;
            if (!chiffres()) erreur("chiffre attendu après le point");
        }
        if (courant() == 'e' || courant() == 'E') {
            ++pos_;
            if (courant() == '+' || courant() == '-') ++pos_;
            if (!chiffres()) erreur("exposant invalide");
        }
        // strtod convertit le morceau validé ; std::string garantit le '\0' final
        const std::string morceau(texte_.substr(debut, pos_ - debut));
        return std::strtod(morceau.c_str(), nullptr);
    }

    unsigned hexa4() {
        unsigned code = 0;
        for (int i = 0; i < 4; ++i) {
            const char c = courant();
            ++pos_;
            code <<= 4;
            if (c >= '0' && c <= '9') code |= static_cast<unsigned>(c - '0');
            else if (c >= 'a' && c <= 'f') code |= static_cast<unsigned>(c - 'a' + 10);
            else if (c >= 'A' && c <= 'F') code |= static_cast<unsigned>(c - 'A' + 10);
            else erreur("séquence \\u invalide");
        }
        return code;
    }

    // Écrit un point de code Unicode en UTF-8 (1 à 4 octets)
    static void ajouterUtf8(std::string& sortie, unsigned code) {
        if (code < 0x80) {
            sortie += static_cast<char>(code);
        } else if (code < 0x800) {
            sortie += static_cast<char>(0xC0 | (code >> 6));
            sortie += static_cast<char>(0x80 | (code & 0x3F));
        } else if (code < 0x10000) {
            sortie += static_cast<char>(0xE0 | (code >> 12));
            sortie += static_cast<char>(0x80 | ((code >> 6) & 0x3F));
            sortie += static_cast<char>(0x80 | (code & 0x3F));
        } else {
            sortie += static_cast<char>(0xF0 | (code >> 18));
            sortie += static_cast<char>(0x80 | ((code >> 12) & 0x3F));
            sortie += static_cast<char>(0x80 | ((code >> 6) & 0x3F));
            sortie += static_cast<char>(0x80 | (code & 0x3F));
        }
    }

    std::string chaine() {
        attendre('"');
        std::string resultat;
        while (true) {
            if (pos_ >= texte_.size()) erreur("texte non terminé");
            const char c = texte_[pos_++];
            if (c == '"') return resultat;
            if (static_cast<unsigned char>(c) < 0x20) erreur("caractère de contrôle interdit dans un texte");
            if (c != '\\') { resultat += c; continue; }
            const char echappe = courant();
            ++pos_;
            switch (echappe) {
                case '"': resultat += '"'; break;
                case '\\': resultat += '\\'; break;
                case '/': resultat += '/'; break;
                case 'b': resultat += '\b'; break;
                case 'f': resultat += '\f'; break;
                case 'n': resultat += '\n'; break;
                case 'r': resultat += '\r'; break;
                case 't': resultat += '\t'; break;
                case 'u': {
                    unsigned code = hexa4();
                    // Caractère hors du plan de base (emoji…) : paire de substitution 😀
                    if (code >= 0xD800 && code <= 0xDBFF) {
                        if (courant() != '\\' || texte_.substr(pos_ + 1, 1) != "u") erreur("paire de substitution incomplète");
                        pos_ += 2;
                        const unsigned bas = hexa4();
                        if (bas < 0xDC00 || bas > 0xDFFF) erreur("paire de substitution invalide");
                        code = 0x10000 + ((code - 0xD800) << 10) + (bas - 0xDC00);
                    }
                    ajouterUtf8(resultat, code);
                    break;
                }
                default: erreur("séquence d'échappement inconnue");
            }
        }
    }
};

void serialiserTexte(const std::string& texte, std::string& sortie) {
    sortie += '"';
    for (const char c : texte) {
        switch (c) {
            case '"': sortie += "\\\""; break;
            case '\\': sortie += "\\\\"; break;
            case '\n': sortie += "\\n"; break;
            case '\r': sortie += "\\r"; break;
            case '\t': sortie += "\\t"; break;
            default:
                if (static_cast<unsigned char>(c) < 0x20) {
                    char code[8];
                    std::snprintf(code, sizeof code, "\\u%04x", static_cast<unsigned>(static_cast<unsigned char>(c)));
                    sortie += code;
                } else {
                    sortie += c;   // les octets UTF-8 (accents) passent tels quels
                }
        }
    }
    sortie += '"';
}

}  // namespace

Json Json::analyser(std::string_view texte) { return Analyseur(texte).document(); }

std::string Json::serialiser() const {
    std::string sortie;
    serialiserDans(sortie);
    return sortie;
}

void Json::serialiserDans(std::string& sortie) const {
    // std::visit appelle la bonne branche selon le type actif du variant
    std::visit([&sortie](const auto& v) {
        using T = std::decay_t<decltype(v)>;
        if constexpr (std::is_same_v<T, std::nullptr_t>) {
            sortie += "null";
        } else if constexpr (std::is_same_v<T, bool>) {
            sortie += v ? "true" : "false";
        } else if constexpr (std::is_same_v<T, double>) {
            if (!std::isfinite(v)) {
                sortie += "null";   // JSON n'a ni NaN ni infini
            } else if (v == std::floor(v) && std::fabs(v) < 1e15) {
                sortie += std::to_string(static_cast<long long>(v));   // 12 et non 12.000000
            } else {
                char nombre[32];
                std::snprintf(nombre, sizeof nombre, "%.15g", v);
                sortie += nombre;
            }
        } else if constexpr (std::is_same_v<T, std::string>) {
            serialiserTexte(v, sortie);
        } else if constexpr (std::is_same_v<T, Tableau>) {
            sortie += '[';
            for (std::size_t i = 0; i < v.size(); ++i) {
                if (i > 0) sortie += ',';
                v[i].serialiserDans(sortie);
            }
            sortie += ']';
        } else {
            sortie += '{';
            bool premier = true;
            for (const auto& [cle, valeur] : v) {
                if (!premier) sortie += ',';
                premier = false;
                serialiserTexte(cle, sortie);
                sortie += ':';
                valeur.serialiserDans(sortie);
            }
            sortie += '}';
        }
    }, valeur_);
}

namespace {
template <typename T>
const T& acces(const std::variant<std::nullptr_t, bool, double, std::string, Json::Tableau, Json::Objet>& v,
               const char* attendu) {
    if (const T* p = std::get_if<T>(&v)) return *p;
    throw std::runtime_error(std::string("JSON : ") + attendu + " attendu");
}
}  // namespace

bool Json::booleen() const { return acces<bool>(valeur_, "booléen"); }
double Json::nombre() const { return acces<double>(valeur_, "nombre"); }
const std::string& Json::texte() const { return acces<std::string>(valeur_, "texte"); }
const Json::Tableau& Json::elements() const { return acces<Tableau>(valeur_, "tableau"); }
const Json::Objet& Json::membres() const { return acces<Objet>(valeur_, "objet"); }

const Json& Json::operator[](const std::string& cle) const {
    static const Json nul;
    const auto* objet = std::get_if<Objet>(&valeur_);
    if (objet == nullptr) return nul;
    const auto it = objet->find(cle);
    return it == objet->end() ? nul : it->second;
}

bool Json::contient(const std::string& cle) const {
    const auto* objet = std::get_if<Objet>(&valeur_);
    return objet != nullptr && objet->count(cle) > 0;
}

double Json::nombreOu(const std::string& cle, double defaut) const {
    const Json& v = (*this)[cle];
    return v.estNombre() ? v.nombre() : defaut;
}

std::string Json::texteOu(const std::string& cle, const std::string& defaut) const {
    const Json& v = (*this)[cle];
    return v.estTexte() ? v.texte() : defaut;
}

Json& Json::operator[](const std::string& cle) {
    if (estNul()) valeur_ = Objet{};
    auto* objet = std::get_if<Objet>(&valeur_);
    if (objet == nullptr) throw std::runtime_error("JSON : objet attendu");
    return (*objet)[cle];
}

void Json::ajouter(Json valeur) {
    if (estNul()) valeur_ = Tableau{};
    auto* tableau = std::get_if<Tableau>(&valeur_);
    if (tableau == nullptr) throw std::runtime_error("JSON : tableau attendu");
    tableau->push_back(std::move(valeur));
}

}  // namespace souk
