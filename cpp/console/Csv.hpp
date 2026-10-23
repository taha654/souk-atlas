// =============================================================================
// Lecture et écriture de CSV (RFC 4180), le format d'export des tableurs.
//
//   nom;prix_ht;description
//   "Lampe ""Atlas""";129,90;"Sur deux
//   lignes"
//
// - un champ entre guillemets peut contenir le séparateur, des sauts de ligne,
//   et des guillemets doublés ("") ;
// - séparateur ";" (Excel en français) ou "," : détecté sur la première ligne ;
// - la marque d'ordre des octets (BOM) UTF-8 d'Excel est ignorée.
// =============================================================================
#pragma once

#include <stdexcept>
#include <string>
#include <vector>

namespace souk {

class ErreurCsv : public std::runtime_error {
public:
    ErreurCsv(const std::string& message, std::size_t ligne)
        : std::runtime_error("ligne " + std::to_string(ligne) + " : " + message), ligne_(ligne) {}
    std::size_t ligne() const noexcept { return ligne_; }

private:
    std::size_t ligne_;
};

struct EnregistrementCsv {
    std::size_t ligne = 0;               // numéro de la ligne du fichier où il commence (1 = en-tête)
    std::vector<std::string> champs;
};

class LecteurCsv {
public:
    // separateur = 0 : détection automatique (";" ou ",")
    explicit LecteurCsv(std::string texte, char separateur = 0);

    // Enregistrement suivant ; false à la fin. Les lignes vides sont ignorées.
    // Lève ErreurCsv pour un guillemet jamais refermé.
    bool suivant(EnregistrementCsv& enregistrement);

    char separateur() const noexcept { return separateur_; }

private:
    std::string texte_;
    std::size_t pos_ = 0;
    std::size_t ligne_ = 1;
    char separateur_;
};

// Un champ prêt à écrire : entre guillemets seulement si nécessaire
std::string champCsv(const std::string& valeur, char separateur = ';');
std::string ligneCsv(const std::vector<std::string>& champs, char separateur = ';');

}  // namespace souk
