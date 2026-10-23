// =============================================================================
// Actions du moteur. La requête JSON choisit l'action par son champ "action" :
//   {"action": "recommandations", ...}
//   {"action": "risque_annonce", ...}
//   {"action": "risque_commande", ...}
// Chaque action est une classe dérivée de Action (polymorphisme) ; le moteur
// les range dans une table nom → objet (Registre).
// =============================================================================
#pragma once

#include "Json.hpp"

#include <map>
#include <memory>
#include <stdexcept>
#include <string>

namespace souk {

// Erreur due à la requête (champ manquant, valeur invalide) : code de sortie 2
class RequeteInvalide : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

class Action {
public:
    virtual ~Action() = default;
    virtual Json executer(const Json& requete) const = 0;
};

class ActionRecommandations : public Action {
public:
    Json executer(const Json& requete) const override;
};

class ActionRisqueAnnonce : public Action {
public:
    Json executer(const Json& requete) const override;
};

class ActionRisqueCommande : public Action {
public:
    Json executer(const Json& requete) const override;
};

class Registre {
public:
    Registre();   // enregistre toutes les actions connues
    // Lève RequeteInvalide si l'action est inconnue
    Json traiter(const Json& requete) const;

private:
    std::map<std::string, std::unique_ptr<Action>> actions_;
};

}  // namespace souk
