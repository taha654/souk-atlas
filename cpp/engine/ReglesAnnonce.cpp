#include "ReglesAnnonce.hpp"

#include "Texte.hpp"

#include <cctype>
#include <cmath>
#include <string_view>

namespace souk {

RegleMotsSuspects::RegleMotsSuspects(std::vector<std::string> expressions) {
    for (const auto& e : expressions) expressions_.push_back(texte::normaliser(e));
}

std::vector<std::string> RegleMotsSuspects::expressionsParDefaut() {
    return {"western union", "moneygram", "mandat cash", "virement", "paiement d'avance", "payer d'avance",
            "avance", "urgent", "transporteur", "frais de douane", "frais d'envoi", "carte cadeau", "bitcoin",
            "whatsapp uniquement", "contactez moi sur whatsapp", "prix sacrifie"};
}

std::optional<Raison> RegleMotsSuspects::evaluer(const ContexteAnnonce& c) const {
    const std::string texte = texte::normaliser(c.titre + " " + c.description);
    std::string trouves;
    int nb = 0;
    for (const auto& expression : expressions_) {
        if (texte::contientExpression(texte, expression)) {
            trouves += (nb++ > 0 ? ", " : "") + ("« " + expression + " »");
        }
    }
    if (nb == 0) return std::nullopt;
    // 15 points par expression, plafonné : 3 expressions suffisent à être suspect
    return Raison{nom(), std::min(nb * 15, 45), "expressions suspectes : " + trouves};
}

std::optional<Raison> ReglePrixAnormal::evaluer(const ContexteAnnonce& c) const {
    // Une médiane calculée sur moins de 3 annonces n'est pas représentative
    if (c.prixMedianCategorie <= 0 || c.nbAnnoncesCategorie < 3 || c.prix <= 0) return std::nullopt;
    const double rapport = c.prix / c.prixMedianCategorie;
    const long pourcent = std::lround(rapport * 100);
    if (rapport < 0.25) {
        // Le cas classique d'arnaque : un prix trop beau pour être vrai
        return Raison{nom(), 35, "prix à " + std::to_string(pourcent) + " % de la médiane de la catégorie"};
    }
    if (rapport > 5) {
        return Raison{nom(), 10, "prix à " + std::to_string(pourcent) + " % de la médiane de la catégorie"};
    }
    return std::nullopt;
}

std::optional<Raison> RegleVolumeAnnonces::evaluer(const ContexteAnnonce& c) const {
    if (c.annoncesAuteur24h >= 10) return Raison{nom(), 30, std::to_string(c.annoncesAuteur24h) + " annonces en 24 h"};
    if (c.annoncesAuteur24h >= 5) return Raison{nom(), 15, std::to_string(c.annoncesAuteur24h) + " annonces en 24 h"};
    return std::nullopt;
}

std::optional<Raison> RegleMajuscules::evaluer(const ContexteAnnonce& c) const {
    int points = 0;
    std::string detail;
    int lettres = 0;
    for (const char ch : c.titre) lettres += std::isalpha(static_cast<unsigned char>(ch)) ? 1 : 0;
    if (lettres >= 8 && texte::partDeMajuscules(c.titre) > 0.7) {
        points += 10;
        detail = "titre en majuscules";
    }
    if ((c.titre + c.description).find("!!!") != std::string::npos) {
        points += 5;
        detail += detail.empty() ? "points d'exclamation répétés" : ", points d'exclamation répétés";
    }
    if (points == 0) return std::nullopt;
    return Raison{nom(), points, detail};
}

namespace {
// Numéro marocain : 0 puis 5, 6 ou 7, puis 8 chiffres (espaces, points ou
// tirets tolérés entre les chiffres), ou la forme internationale +212
bool contientTelephone(std::string_view texte) {
    std::string chiffres;
    for (std::size_t i = 0; i <= texte.size(); ++i) {
        const char ch = i < texte.size() ? texte[i] : '\n';
        if (std::isdigit(static_cast<unsigned char>(ch))) {
            chiffres += ch;
        } else if (ch == ' ' || ch == '.' || ch == '-' || ch == '+') {
            continue;   // séparateurs à l'intérieur d'un numéro
        } else {
            if (chiffres.size() >= 10) {
                if (chiffres.rfind("2126", 0) == 0 || chiffres.rfind("2127", 0) == 0 || chiffres.rfind("2125", 0) == 0) return true;
                for (std::size_t k = 0; k + 10 <= chiffres.size(); ++k) {
                    if (chiffres[k] == '0' && (chiffres[k + 1] >= '5' && chiffres[k + 1] <= '7')) return true;
                }
            }
            chiffres.clear();
        }
    }
    return false;
}

bool contientEmail(std::string_view texte) {
    const std::size_t arobase = texte.find('@');
    return arobase != std::string_view::npos && arobase > 0 && texte.find('.', arobase) != std::string_view::npos;
}
}  // namespace

std::optional<Raison> RegleCoordonnees::evaluer(const ContexteAnnonce& c) const {
    // Donner son numéro dans l'annonce pousse à quitter la messagerie du site,
    // donc à échapper à sa protection
    const std::string texte = c.titre + " " + c.description;
    if (contientTelephone(texte)) return Raison{nom(), 15, "numéro de téléphone dans le texte"};
    if (contientEmail(texte)) return Raison{nom(), 15, "adresse email dans le texte"};
    return std::nullopt;
}

AnalyseurRisque<ContexteAnnonce> analyseurAnnonce() {
    AnalyseurRisque<ContexteAnnonce> analyseur;
    // make_unique : pas de new/delete à la main, la mémoire est libérée toute seule
    analyseur.ajouter(std::make_unique<RegleMotsSuspects>())
        .ajouter(std::make_unique<ReglePrixAnormal>())
        .ajouter(std::make_unique<RegleCompteRecent<ContexteAnnonce>>())
        .ajouter(std::make_unique<RegleVolumeAnnonces>())
        .ajouter(std::make_unique<RegleMajuscules>())
        .ajouter(std::make_unique<RegleCoordonnees>());
    return analyseur;
}

}  // namespace souk
