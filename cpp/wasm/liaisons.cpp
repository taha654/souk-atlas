// =============================================================================
// Liaisons WebAssembly (Emscripten + embind) : ce que le JavaScript peut appeler.
//
// Le code C++ lui-même (common/RechercheTolerante, common/Redimensionnement)
// est le MÊME que celui testé en natif par CTest : on ne compile ici qu'une
// fine couche de "traduction" entre types C++ et valeurs JavaScript.
//
// Côté JavaScript (public/assets/js/wasm.js) :
//   const index = new module.RechercheTolerante();
//   index.ajouter(12, "Smartphone Samsung");
//   index.rechercher("smartphon samsng", 8)   →   [{id: 12, nom: "…", distance: 2}]
// =============================================================================
#include "RechercheTolerante.hpp"
#include "Redimensionnement.hpp"

#include <emscripten/bind.h>
#include <emscripten/val.h>

#include <cstdint>

using emscripten::val;

namespace {

// Classe exposée au JavaScript : enveloppe l'index et convertit les résultats
// en objets JavaScript ({id, nom, distance})
class RechercheTolerante {
public:
    void ajouter(int id, const std::string& titre) { index_.ajouter(id, titre); }
    void vider() { index_.vider(); }
    int taille() const { return static_cast<int>(index_.taille()); }

    val rechercher(const std::string& requete, int limite) const {
        val resultats = val::array();
        if (limite <= 0) return resultats;
        for (const auto& r : index_.rechercher(requete, static_cast<std::size_t>(limite))) {
            val objet = val::object();
            objet.set("id", r.id);
            objet.set("nom", r.titre);
            objet.set("distance", r.distance);
            resultats.call<void>("push", objet);
        }
        return resultats;
    }

private:
    souk::IndexTolerant index_;
};

val dimensionsReduites(int largeur, int hauteur, int cote) {
    val dimensions = val::object();
    if (largeur <= 0 || hauteur <= 0 || cote <= 0) return val::null();
    const auto [l, h] = souk::dimensionsReduites(largeur, hauteur, cote);
    dimensions.set("largeur", l);
    dimensions.set("hauteur", h);
    return dimensions;
}

// Les pixels ne sont pas copiés un par un entre JavaScript et WebAssembly : le
// JavaScript les écrit directement dans la mémoire du module (Module.HEAPU8, un
// grand tableau d'octets) à une adresse obtenue par _malloc, et passe cette
// ADRESSE (un simple entier) à la fonction C++.
// Les exceptions C++ sont désactivées dans ce module (plus léger) : on vérifie
// les arguments ici et on renvoie false au lieu de lever une exception.
bool reduireRgba(std::uintptr_t source, int largeur, int hauteur,
                 std::uintptr_t destination, int nouvelleLargeur, int nouvelleHauteur) {
    if (source == 0 || destination == 0 || largeur <= 0 || hauteur <= 0 || nouvelleLargeur <= 0
        || nouvelleHauteur <= 0 || nouvelleLargeur > largeur || nouvelleHauteur > hauteur) {
        return false;
    }
    souk::reduireRgba(reinterpret_cast<const std::uint8_t*>(source), largeur, hauteur,
                      reinterpret_cast<std::uint8_t*>(destination), nouvelleLargeur, nouvelleHauteur);
    return true;
}

}  // namespace

EMSCRIPTEN_BINDINGS(souk_atlas) {
    emscripten::class_<RechercheTolerante>("RechercheTolerante")
        .constructor<>()
        .function("ajouter", &RechercheTolerante::ajouter)
        .function("vider", &RechercheTolerante::vider)
        .function("taille", &RechercheTolerante::taille)
        .function("rechercher", &RechercheTolerante::rechercher);
    emscripten::function("dimensionsReduites", &dimensionsReduites);
    emscripten::function("reduireRgba", &reduireRgba);
}
