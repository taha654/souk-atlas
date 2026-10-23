#include "GrapheCoAchats.hpp"
#include "Texte.hpp"
#include "Verif.hpp"

using namespace souk;

int main() {
    // --- Texte
    VERIFIER_EGAL(std::string("telephone ete a fes"), texte::normaliser("Téléphone ÉTÉ à Fès"));
    VERIFIER_EGAL(std::string("garcon noel"), texte::normaliser("Garçon Noël"));
    VERIFIER_EGAL(3u, texte::mots("paiement par virement!").size());
    VERIFIER(texte::contientExpression("paiement par western union svp", "western union"));
    VERIFIER(!texte::contientExpression("virements", "virement"));     // mot entier seulement
    VERIFIER(!texte::contientExpression("western", "western union"));
    VERIFIER_EGAL(1.0, texte::partDeMajuscules("URGENT !!!"));
    VERIFIER_EGAL(0.0, texte::partDeMajuscules("123"));

    // --- Graphe des co-achats
    GrapheCoAchats g;
    g.ajouterPanier({1, 2});
    g.ajouterPanier({1, 2, 3});
    g.ajouterPanier({2, 1, 1});   // doublon ignoré
    g.ajouterPanier({1, 3});
    g.ajouterPanier({4});
    g.ajouterPanier({});          // panier vide ignoré
    VERIFIER_EGAL(5u, g.nbPaniers());
    VERIFIER_EGAL(4, g.occurrences(1));
    VERIFIER_EGAL(3, g.ensemble(1, 2));
    VERIFIER_EGAL(3, g.ensemble(2, 1));   // arête dans les deux sens
    VERIFIER_EGAL(0, g.ensemble(1, 4));

    const auto recos = g.recommandations(1, 10, 1);
    VERIFIER_EGAL(2u, recos.size());
    VERIFIER_EGAL(2, recos[0].produit);   // 3/√(4×3) ≈ 0.866 > 2/√(4×2) ≈ 0.707
    VERIFIER(recos[0].score > 0.86 && recos[0].score < 0.87);
    VERIFIER_EGAL(3, recos[1].produit);

    VERIFIER_EGAL(1u, g.recommandations(1, 10, 3).size());   // support minimal
    VERIFIER_EGAL(1u, g.recommandations(1, 1, 1).size());    // limite
    VERIFIER(g.recommandations(4, 10, 1).empty());           // jamais acheté avec autre chose
    VERIFIER(g.recommandations(99, 10, 1).empty());          // inconnu
    VERIFIER_EGAL(4u, g.produits().size());
    return verif::bilan();
}
