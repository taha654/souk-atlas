// Tests natifs du code compilé ensuite en WebAssembly (étape 10) : on vérifie
// la logique ici, avec CTest, avant de la livrer au navigateur
#include "Levenshtein.hpp"
#include "RechercheTolerante.hpp"
#include "Redimensionnement.hpp"
#include "Verif.hpp"

#include <algorithm>
#include <vector>

using namespace souk;

namespace {
std::size_t d(const char* a, const char* b, bool transpositions = true) {
    return distanceLevenshtein(versCodePoints(a), versCodePoints(b), transpositions);
}
}  // namespace

int main() {
    // --- Distance d'édition
    VERIFIER_EGAL(0u, d("samsung", "samsung"));
    VERIFIER_EGAL(1u, d("samsng", "samsung"));      // insertion
    VERIFIER_EGAL(1u, d("smartphon", "smartphone"));
    VERIFIER_EGAL(1u, d("samsunf", "samsung"));     // remplacement
    VERIFIER_EGAL(1u, d("smasung", "samsung"));     // transposition (Damerau)
    VERIFIER_EGAL(2u, d("smasung", "samsung", false));
    VERIFIER_EGAL(3u, d("chat", "chien"));
    VERIFIER_EGAL(5u, d("", "tapis"));
    VERIFIER_EGAL(d("abcdef", "azced"), d("azced", "abcdef"));   // symétrique
    VERIFIER_EGAL(2u, d("ete", "été"));             // é est UN caractère (2 remplacements, pas 4 octets) ;
                                                    // l'index retire les accents AVANT de comparer
    VERIFIER_EGAL(3u, versCodePoints("été").size());
    VERIFIER_EGAL(2u, versCodePoints("😀a").size());   // caractère sur 4 octets

    // --- Index tolérant
    IndexTolerant index;
    index.ajouter(1, "Smartphone Samsung Galaxy A55 128 Go");
    index.ajouter(2, "Smartphone Xiaomi Redmi Note 13 256 Go");
    index.ajouter(3, "Tablette Samsung Galaxy Tab A9+ 64 Go");
    index.ajouter(4, "Téléphone fixe sans fil");
    index.ajouter(5, "Coque silicone pour Galaxy A55");
    VERIFIER_EGAL(5u, index.taille());

    auto r = index.rechercher("smartphon samsng", 10);
    VERIFIER_EGAL(1u, r.size());                    // critère de l'étape 10
    VERIFIER_EGAL(1, r[0].id);
    VERIFIER_EGAL(2, r[0].distance);                // "smartphon" (1 faute) + "samsng" (1 faute)
    VERIFIER_EGAL(std::string("Smartphone Samsung Galaxy A55 128 Go"), r[0].titre);

    r = index.rechercher("sams", 10);               // mot en cours de frappe : début de mot
    VERIFIER_EGAL(3u, r.size());                    // les 2 « Samsung » (0 faute) et « sans » (1 faute)
    VERIFIER_EGAL(1, r[0].id);                      // à distance égale, le titre le plus court
    VERIFIER_EGAL(0, r[1].distance);
    VERIFIER_EGAL(4, r[2].id);
    r = index.rechercher("telefone", 10);           // sans accent ET avec une faute
    VERIFIER_EGAL(1u, r.size());
    VERIFIER_EGAL(4, r[0].id);
    r = index.rechercher("galaxy a55", 10);
    VERIFIER_EGAL(2u, r.size());
    VERIFIER_EGAL(0, r[0].distance);
    VERIFIER(index.rechercher("tv", 10).empty());   // mot court : aucune faute admise
    VERIFIER(index.rechercher("frigo", 10).empty());
    VERIFIER(index.rechercher("   ", 10).empty());
    VERIFIER_EGAL(1u, index.rechercher("samsung", 1).size());   // limite
    VERIFIER_EGAL(0u, IndexTolerant::tolerance(3));
    VERIFIER_EGAL(2u, IndexTolerant::tolerance(9));
    index.vider();
    VERIFIER_EGAL(0u, index.taille());

    // --- Redimensionnement
    VERIFIER(dimensionsReduites(4000, 3000, 1600) == std::make_pair(1600, 1200));
    VERIFIER(dimensionsReduites(3000, 4000, 1600) == std::make_pair(1200, 1600));
    VERIFIER(dimensionsReduites(800, 600, 1600) == std::make_pair(800, 600));    // jamais agrandie
    VERIFIER(dimensionsReduites(10000, 10, 1600) == std::make_pair(1600, 2));
    VERIFIER_EXCEPTION(dimensionsReduites(0, 10, 100), std::invalid_argument);

    // 4×4 → 2×2 : chaque pixel d'arrivée = moyenne d'un bloc 2×2
    std::vector<std::uint8_t> src(4 * 4 * 4);
    for (int y = 0; y < 4; ++y)
        for (int x = 0; x < 4; ++x)
            for (int c = 0; c < 4; ++c) src[static_cast<std::size_t>((y * 4 + x) * 4 + c)] = static_cast<std::uint8_t>(c == 3 ? 255 : (x + y) * 20);
    std::vector<std::uint8_t> dst(2 * 2 * 4);
    reduireRgba(src.data(), 4, 4, dst.data(), 2, 2);
    VERIFIER_EGAL(20, int(dst[0]));                 // (0 + 20 + 20 + 40) / 4
    VERIFIER_EGAL(60, int(dst[4]));                 // bloc en haut à droite : (40 + 60 + 60 + 80) / 4
    VERIFIER_EGAL(100, int(dst[3 * 4]));            // en bas à droite
    VERIFIER_EGAL(255, int(dst[3]));                // opacité conservée

    // 3 → 2 : pixels coupés en deux, pondérés (0, 90, 180 → 30, 150)
    std::vector<std::uint8_t> ligne = {0, 0, 0, 255, 90, 90, 90, 255, 180, 180, 180, 255};
    std::vector<std::uint8_t> deux(2 * 4);
    reduireRgba(ligne.data(), 3, 1, deux.data(), 2, 1);
    VERIFIER_EGAL(30, int(deux[0]));
    VERIFIER_EGAL(150, int(deux[4]));

    // Couleur uniforme : inchangée quelle que soit l'échelle
    std::vector<std::uint8_t> uni(97 * 61 * 4, 77);
    std::vector<std::uint8_t> petit(13 * 8 * 4);
    reduireRgba(uni.data(), 97, 61, petit.data(), 13, 8);
    VERIFIER(std::all_of(petit.begin(), petit.end(), [](std::uint8_t v) { return v == 77; }));
    VERIFIER_EXCEPTION(reduireRgba(uni.data(), 97, 61, petit.data(), 200, 8), std::invalid_argument);
    return verif::bilan();
}
