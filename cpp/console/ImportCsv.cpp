#include "ImportCsv.hpp"

#include "Csv.hpp"
#include "Texte.hpp"

#include <map>

namespace souk {

namespace {

constexpr double kPrixMax = 10'000'000;   // mêmes limites que ProduitVendeur.php
constexpr long kStockMax = 1'000'000;

std::string sansEspacesAutour(const std::string& texte) {
    const std::size_t debut = texte.find_first_not_of(" \t");
    if (debut == std::string::npos) return "";
    return texte.substr(debut, texte.find_last_not_of(" \t") - debut + 1);
}

// Citation courte d'une valeur fautive dans un message d'erreur
std::string citer(const std::string& valeur) {
    return "« " + (valeur.size() > 40 ? valeur.substr(0, 40) + "…" : valeur) + " »";
}

}  // namespace

std::size_t longueurUtf8(const std::string& texte) {
    std::size_t n = 0;
    // En UTF-8, les octets de continuation sont de la forme 10xxxxxx : on ne les compte pas
    for (const char c : texte) n += (static_cast<unsigned char>(c) & 0xC0) != 0x80 ? 1 : 0;
    return n;
}

std::optional<std::string> normaliserPrix(const std::string& texte) {
    std::string prix;
    for (std::size_t i = 0; i < texte.size(); ++i) {
        const char c = texte[i];
        if (c == ' ') continue;
        // Espaces insécables qu'Excel met dans "1 299,90" : U+00A0 et U+202F
        if (texte.compare(i, 2, "\xC2\xA0") == 0) { i += 1; continue; }
        if (texte.compare(i, 3, "\xE2\x80\xAF") == 0) { i += 2; continue; }
        prix += c == ',' ? '.' : c;
    }
    // Chiffres, puis éventuellement un point et 1 ou 2 décimales
    const std::size_t point = prix.find('.');
    const std::string entiere = prix.substr(0, point);
    const std::string decimales = point == std::string::npos ? "" : prix.substr(point + 1);
    auto chiffres = [](const std::string& s) { return s.find_first_not_of("0123456789") == std::string::npos; };
    if (entiere.empty() || entiere.size() > 9 || !chiffres(entiere) || !chiffres(decimales)
        || (point != std::string::npos && (decimales.empty() || decimales.size() > 2))) {
        return std::nullopt;
    }
    const double valeur = std::stod(prix);
    if (valeur <= 0 || valeur > kPrixMax) return std::nullopt;
    return prix;
}

LectureCatalogue lireCatalogue(const std::string& texte) {
    LecteurCsv lecteur(texte);
    EnregistrementCsv enregistrement;
    if (!lecteur.suivant(enregistrement)) throw ErreurCsv("fichier vide", 1);

    // En-tête : nom de colonne → position
    std::map<std::string, std::size_t> colonnes;
    for (std::size_t i = 0; i < enregistrement.champs.size(); ++i) {
        colonnes[texte::normaliser(sansEspacesAutour(enregistrement.champs[i]))] = i;
    }
    for (const char* obligatoire : {"nom", "prix_ht", "stock", "categorie"}) {
        if (colonnes.count(obligatoire) == 0) {
            throw ErreurCsv(std::string("colonne « ") + obligatoire
                            + " » absente de l'en-tête (attendu : nom;description;prix_ht;stock;categorie)", 1);
        }
    }
    const std::size_t nbColonnes = enregistrement.champs.size();
    auto champ = [&](const EnregistrementCsv& e, const std::string& nom) {
        const auto it = colonnes.find(nom);
        return it == colonnes.end() ? std::string() : sansEspacesAutour(e.champs[it->second]);
    };

    LectureCatalogue resultat;
    while (lecteur.suivant(enregistrement)) {
        ++resultat.nbLignes;
        const std::size_t ligne = enregistrement.ligne;
        if (enregistrement.champs.size() != nbColonnes) {
            resultat.rejets.push_back({ligne, std::to_string(enregistrement.champs.size()) + " colonne(s) au lieu de "
                                                  + std::to_string(nbColonnes)});
            continue;
        }
        ProduitImporte p;
        p.ligne = ligne;
        p.nom = champ(enregistrement, "nom");
        p.description = champ(enregistrement, "description");
        p.categorie = champ(enregistrement, "categorie");
        const std::string prix = champ(enregistrement, "prix_ht");
        const std::string stock = champ(enregistrement, "stock");

        // Toutes les erreurs de la ligne d'un coup : l'utilisateur corrige tout en une fois
        std::vector<std::string> erreurs;
        const std::size_t longueurNom = longueurUtf8(p.nom);
        if (longueurNom < 3 || longueurNom > 200) erreurs.push_back("nom de 3 à 200 caractères attendu");
        if (longueurUtf8(p.description) > 4000) erreurs.push_back("description de plus de 4000 caractères");
        if (const auto normalise = normaliserPrix(prix)) {
            p.prixHt = *normalise;
        } else {
            erreurs.push_back("prix_ht invalide " + citer(prix));
        }
        if (stock.empty() || stock.size() > 7 || stock.find_first_not_of("0123456789") != std::string::npos
            || std::stol(stock) > kStockMax) {
            erreurs.push_back("stock invalide " + citer(stock) + " (entier de 0 à 1000000)");
        } else {
            p.stock = std::stol(stock);
        }
        if (p.categorie.empty()) erreurs.push_back("catégorie manquante");

        if (erreurs.empty()) {
            resultat.produits.push_back(std::move(p));
        } else {
            std::string message;
            for (std::size_t i = 0; i < erreurs.size(); ++i) message += (i > 0 ? " ; " : "") + erreurs[i];
            resultat.rejets.push_back({ligne, message});
        }
    }
    return resultat;
}

}  // namespace souk
