#include "Actions.hpp"
#include "Verif.hpp"

using namespace souk;

int main() {
    const Registre registre;

    // Recommandations
    const Json reco = registre.traiter(Json::analyser(
        R"({"action":"recommandations","paniers":[[1,2],[1,2,3],[1,2],[3,4]],"limite":3,"support_min":2})"));
    VERIFIER(reco["ok"].booleen());
    VERIFIER_EGAL(4.0, reco["paniers"].nombre());
    const auto& pour1 = reco["recommandations"]["1"].elements();
    VERIFIER_EGAL(1u, pour1.size());   // 1-3 vu une seule fois : sous le support minimal
    VERIFIER_EGAL(2.0, pour1[0]["produit"].nombre());
    VERIFIER_EGAL(3.0, pour1[0]["communs"].nombre());
    VERIFIER_EGAL(1.0, pour1[0]["score"].nombre());   // 3/√(3×3)
    VERIFIER(reco["recommandations"]["4"].elements().empty());

    const Json cible = registre.traiter(Json::analyser(
        R"({"action":"recommandations","paniers":[[1,2],[1,2]],"produits":[2]})"));
    VERIFIER_EGAL(1u, cible["recommandations"].membres().size());

    // Risque annonce
    const Json annonce = registre.traiter(Json::analyser(R"({"action":"risque_annonce",
        "annonce":{"titre":"Samsung S24 URGENT","description":"paiement d'avance par virement","prix":900},
        "categorie":{"prix_median":6000,"nb_annonces":8},"auteur":{"annonces_24h":1},"compte":{"anciennete_jours":1}})"));
    VERIFIER(annonce["score"].nombre() >= 60);
    VERIFIER_EGAL(std::string("ELEVE"), annonce["niveau"].texte());
    VERIFIER(annonce["raisons"].elements().size() >= 3);

    // Risque commande
    const Json commande = registre.traiter(Json::analyser(R"({"action":"risque_commande",
        "commande":{"total_ttc":300,"quantite_max":1,"mode_paiement":"CARTE"},
        "client":{"commandes_precedentes":3,"panier_moyen":250,"commandes_24h":1}})"));
    VERIFIER_EGAL(0.0, commande["score"].nombre());

    // Requêtes invalides
    VERIFIER_EXCEPTION(registre.traiter(Json::analyser(R"({"action":"inconnue"})")), RequeteInvalide);
    VERIFIER_EXCEPTION(registre.traiter(Json::analyser(R"([1,2])")), RequeteInvalide);
    VERIFIER_EXCEPTION(registre.traiter(Json::analyser(R"({"action":"recommandations"})")), RequeteInvalide);
    VERIFIER_EXCEPTION(registre.traiter(Json::analyser(R"({"action":"recommandations","paniers":[["a"]]})")), RequeteInvalide);
    VERIFIER_EXCEPTION(registre.traiter(Json::analyser(R"({"action":"recommandations","paniers":[],"limite":0})")), RequeteInvalide);
    VERIFIER_EXCEPTION(registre.traiter(Json::analyser(R"({"action":"risque_annonce","annonce":{"titre":"x"}})")), RequeteInvalide);
    VERIFIER_EXCEPTION(registre.traiter(Json::analyser(R"({"action":"risque_commande"})")), RequeteInvalide);
    return verif::bilan();
}
