// =============================================================================
// Json : une valeur JSON (null, booléen, nombre, texte, tableau ou objet).
//
// Écrit à la main, sans bibliothèque, pour montrer :
//  - std::variant : une variable qui contient UN type parmi plusieurs, de façon
//    sûre (le type actif est connu ; un mauvais accès lève une exception) ;
//  - un analyseur "à descente récursive" : une fonction par règle de la
//    grammaire JSON (valeur → objet | tableau | texte | nombre | littéral).
// =============================================================================
#pragma once

#include <map>
#include <stdexcept>
#include <string>
#include <string_view>
#include <variant>
#include <vector>

namespace souk {

class ErreurJson : public std::runtime_error {
public:
    ErreurJson(const std::string& message, std::size_t position);
    std::size_t position() const noexcept { return position_; }

private:
    std::size_t position_;
};

class Json {
public:
    using Tableau = std::vector<Json>;
    // std::map : les clés sortent triées, donc une sortie toujours identique
    using Objet = std::map<std::string, Json>;

    Json() = default;                       // null
    Json(std::nullptr_t) {}
    Json(bool b) : valeur_(b) {}
    Json(int n) : valeur_(static_cast<double>(n)) {}
    Json(long n) : valeur_(static_cast<double>(n)) {}
    Json(double n) : valeur_(n) {}
    Json(const char* t) : valeur_(std::string(t)) {}
    Json(std::string t) : valeur_(std::move(t)) {}
    Json(Tableau t) : valeur_(std::move(t)) {}
    Json(Objet o) : valeur_(std::move(o)) {}

    static Json tableau() { return Json(Tableau{}); }
    static Json objet() { return Json(Objet{}); }

    // Lecture d'un texte JSON ; lève ErreurJson (avec la position) s'il est invalide
    static Json analyser(std::string_view texte);
    // Écriture compacte
    std::string serialiser() const;

    bool estNul() const { return std::holds_alternative<std::nullptr_t>(valeur_); }
    bool estBooleen() const { return std::holds_alternative<bool>(valeur_); }
    bool estNombre() const { return std::holds_alternative<double>(valeur_); }
    bool estTexte() const { return std::holds_alternative<std::string>(valeur_); }
    bool estTableau() const { return std::holds_alternative<Tableau>(valeur_); }
    bool estObjet() const { return std::holds_alternative<Objet>(valeur_); }

    // Accès typés : lèvent std::runtime_error si le type n'est pas le bon
    bool booleen() const;
    double nombre() const;
    const std::string& texte() const;
    const Tableau& elements() const;
    const Objet& membres() const;

    // Objet : membre (une valeur nulle partagée s'il est absent)
    const Json& operator[](const std::string& cle) const;
    bool contient(const std::string& cle) const;
    // Lecture tolérante, avec valeur par défaut si absent ou d'un autre type
    double nombreOu(const std::string& cle, double defaut) const;
    std::string texteOu(const std::string& cle, const std::string& defaut) const;

    // Construction : membre modifiable (transforme null en objet) et ajout à un tableau
    Json& operator[](const std::string& cle);
    void ajouter(Json valeur);

private:
    std::variant<std::nullptr_t, bool, double, std::string, Tableau, Objet> valeur_{nullptr};

    void serialiserDans(std::string& sortie) const;
};

}  // namespace souk
