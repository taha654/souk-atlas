#include "Actions.hpp"

#include "GrapheCoAchats.hpp"
#include "ReglesAnnonce.hpp"
#include "ReglesCommande.hpp"

#include <cmath>

namespace souk {

namespace {

// Lecture d'un champ numérique obligatoire (message d'erreur explicite sinon)
double nombreObligatoire(const Json& objet, const std::string& cle) {
    const Json& v = objet[cle];
    if (!v.estNombre()) throw RequeteInvalide("champ numérique \"" + cle + "\" manquant");
    return v.nombre();
}

int entier(const Json& objet, const std::string& cle, int defaut) {
    const double v = objet.nombreOu(cle, defaut);
    if (!std::isfinite(v) || v < -1e9 || v > 1e9) throw RequeteInvalide("champ \"" + cle + "\" hors limites");
    return static_cast<int>(v);
}

Json enJson(const ResultatRisque& resultat) {
    Json reponse = Json::objet();
    reponse["score"] = resultat.score;
    reponse["niveau"] = resultat.niveau();
    Json raisons = Json::tableau();
    for (const auto& r : resultat.raisons) {
        Json raison = Json::objet();
        raison["regle"] = r.regle;
        raison["points"] = r.points;
        raison["detail"] = r.detail;
        raisons.ajouter(std::move(raison));
    }
    reponse["raisons"] = std::move(raisons);
    return reponse;
}

Compte lireCompte(const Json& requete) {
    Compte compte;
    compte.ancienneteJours = requete["compte"].nombreOu("anciennete_jours", 365);
    return compte;
}

}  // namespace

// -----------------------------------------------------------------------------
// Entrée : {"paniers": [[12, 15], [12, 40, 15]], "produits": [12] (facultatif),
//           "limite": 4, "support_min": 2}
// Sortie : {"recommandations": {"12": [{"produit": 15, "score": 0.82, "communs": 5}]}}
Json ActionRecommandations::executer(const Json& requete) const {
    const Json& paniers = requete["paniers"];
    if (!paniers.estTableau()) throw RequeteInvalide("tableau \"paniers\" manquant");

    GrapheCoAchats graphe;
    for (const Json& panier : paniers.elements()) {
        if (!panier.estTableau()) throw RequeteInvalide("chaque panier doit être un tableau d'identifiants");
        std::vector<int> produits;
        for (const Json& id : panier.elements()) {
            if (!id.estNombre()) throw RequeteInvalide("identifiant de produit non numérique");
            produits.push_back(static_cast<int>(id.nombre()));
        }
        graphe.ajouterPanier(std::move(produits));
    }

    const int limite = entier(requete, "limite", 4);
    const int supportMin = entier(requete, "support_min", 2);
    if (limite < 1 || limite > 50) throw RequeteInvalide("\"limite\" doit être entre 1 et 50");

    // Produits demandés, ou tous les produits vus dans les paniers
    std::vector<int> cibles;
    if (requete["produits"].estTableau()) {
        for (const Json& id : requete["produits"].elements()) {
            if (!id.estNombre()) throw RequeteInvalide("identifiant de produit non numérique");
            cibles.push_back(static_cast<int>(id.nombre()));
        }
    } else {
        cibles = graphe.produits();
    }

    Json resultat = Json::objet();
    for (const int produit : cibles) {
        Json liste = Json::tableau();
        for (const auto& r : graphe.recommandations(produit, static_cast<std::size_t>(limite), supportMin)) {
            Json reco = Json::objet();
            reco["produit"] = r.produit;
            reco["score"] = std::round(r.score * 10000) / 10000;   // 4 décimales suffisent
            reco["communs"] = r.communs;
            liste.ajouter(std::move(reco));
        }
        resultat[std::to_string(produit)] = std::move(liste);
    }

    Json reponse = Json::objet();
    reponse["paniers"] = static_cast<long>(graphe.nbPaniers());
    reponse["recommandations"] = std::move(resultat);
    return reponse;
}

// -----------------------------------------------------------------------------
// Entrée : {"annonce": {"titre", "description", "prix"},
//           "categorie": {"prix_median", "nb_annonces"},
//           "auteur": {"annonces_24h"}, "compte": {"anciennete_jours"}}
Json ActionRisqueAnnonce::executer(const Json& requete) const {
    const Json& annonce = requete["annonce"];
    if (!annonce.estObjet()) throw RequeteInvalide("objet \"annonce\" manquant");

    ContexteAnnonce contexte;
    contexte.titre = annonce.texteOu("titre", "");
    contexte.description = annonce.texteOu("description", "");
    contexte.prix = nombreObligatoire(annonce, "prix");
    contexte.prixMedianCategorie = requete["categorie"].nombreOu("prix_median", 0);
    contexte.nbAnnoncesCategorie = entier(requete["categorie"], "nb_annonces", 0);
    contexte.annoncesAuteur24h = entier(requete["auteur"], "annonces_24h", 0);
    contexte.compte = lireCompte(requete);

    // L'analyseur est construit une fois (static) : les règles ne changent pas
    static const AnalyseurRisque<ContexteAnnonce> analyseur = analyseurAnnonce();
    return enJson(analyseur.analyser(contexte));
}

// -----------------------------------------------------------------------------
// Entrée : {"commande": {"total_ttc", "quantite_max", "mode_paiement"},
//           "client": {"commandes_precedentes", "panier_moyen", "commandes_24h"},
//           "compte": {"anciennete_jours"}}
Json ActionRisqueCommande::executer(const Json& requete) const {
    const Json& commande = requete["commande"];
    if (!commande.estObjet()) throw RequeteInvalide("objet \"commande\" manquant");

    ContexteCommande contexte;
    contexte.totalTtc = nombreObligatoire(commande, "total_ttc");
    contexte.quantiteMax = entier(commande, "quantite_max", 1);
    contexte.modePaiement = commande.texteOu("mode_paiement", "");
    contexte.commandesPrecedentes = entier(requete["client"], "commandes_precedentes", 0);
    contexte.panierMoyen = requete["client"].nombreOu("panier_moyen", 0);
    contexte.commandes24h = entier(requete["client"], "commandes_24h", 1);
    contexte.compte = lireCompte(requete);

    static const AnalyseurRisque<ContexteCommande> analyseur = analyseurCommande();
    return enJson(analyseur.analyser(contexte));
}

// -----------------------------------------------------------------------------
Registre::Registre() {
    actions_["recommandations"] = std::make_unique<ActionRecommandations>();
    actions_["risque_annonce"] = std::make_unique<ActionRisqueAnnonce>();
    actions_["risque_commande"] = std::make_unique<ActionRisqueCommande>();
}

Json Registre::traiter(const Json& requete) const {
    if (!requete.estObjet()) throw RequeteInvalide("la requête doit être un objet JSON");
    const std::string nom = requete.texteOu("action", "");
    const auto it = actions_.find(nom);
    if (it == actions_.end()) throw RequeteInvalide("action inconnue : \"" + nom + "\"");
    Json reponse = it->second->executer(requete);
    reponse["ok"] = true;
    return reponse;
}

}  // namespace souk
