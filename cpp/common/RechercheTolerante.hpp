// =============================================================================
// Recherche tolérante aux fautes de frappe sur une liste de titres.
//
// Chaque mot tapé doit correspondre à un mot du titre, à quelques fautes près :
// la tolérance grandit avec la longueur du mot (une faute sur un mot de 3
// lettres change tout ; sur "smartphone", deux fautes restent évidentes).
// Le dernier mot est souvent en cours de frappe : il peut aussi correspondre
// au DÉBUT d'un mot du titre ("sams" → "samsung").
//
//   index.ajouter(1, "Smartphone Samsung Galaxy A55");
//   index.rechercher("smartphon samsng", 5)   →   [{1, "Smartphone Samsung…", 2}]
// =============================================================================
#pragma once

#include <string>
#include <vector>

namespace souk {

struct ResultatTolerant {
    int id;
    std::string titre;
    int distance;   // total des fautes corrigées (0 = correspondance exacte)
};

class IndexTolerant {
public:
    void ajouter(int id, const std::string& titre);
    void vider() { entrees_.clear(); }
    std::size_t taille() const noexcept { return entrees_.size(); }

    // Meilleurs résultats d'abord : moins de fautes, puis titre le plus court
    std::vector<ResultatTolerant> rechercher(const std::string& requete, std::size_t limite) const;

    // Fautes admises pour un mot de cette longueur
    static std::size_t tolerance(std::size_t longueur);

private:
    struct Entree {
        int id;
        std::string titre;
        std::vector<std::u32string> mots;   // normalisés : minuscules, sans accents
    };
    std::vector<Entree> entrees_;
};

}  // namespace souk
