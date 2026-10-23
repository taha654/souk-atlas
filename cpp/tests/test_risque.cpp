#include "ReglesAnnonce.hpp"
#include "ReglesCommande.hpp"
#include "Verif.hpp"

using namespace souk;

namespace {
ContexteAnnonce annonceNormale() {
    ContexteAnnonce c;
    c.titre = "Vélo de ville Btwin";
    c.description = "Bon état, pneus changés l'an dernier. À voir à Rabat.";
    c.prix = 1200;
    c.prixMedianCategorie = 1500;
    c.nbAnnoncesCategorie = 6;
    c.annoncesAuteur24h = 1;
    c.compte.ancienneteJours = 200;
    return c;
}

bool aRaison(const ResultatRisque& r, const std::string& regle) {
    for (const auto& raison : r.raisons) if (raison.regle == regle) return true;
    return false;
}

// Une règle de test, pour vérifier que l'analyseur accepte toute règle dérivée
class RegleToujours : public Regle<ContexteAnnonce> {
public:
    explicit RegleToujours(int points) : points_(points) {}
    std::string nom() const override { return "toujours"; }
    std::optional<Raison> evaluer(const ContexteAnnonce&) const override { return Raison{nom(), points_, "test"}; }
private:
    int points_;
};
}  // namespace

int main() {
    const auto analyseur = analyseurAnnonce();
    VERIFIER_EGAL(6u, analyseur.nbRegles());

    // Annonce ordinaire : aucun risque
    const auto normal = analyseur.analyser(annonceNormale());
    VERIFIER_EGAL(0, normal.score);
    VERIFIER_EGAL(std::string("FAIBLE"), normal.niveau());

    // Arnaque typique : prix cassé + virement + urgence → modération
    ContexteAnnonce arnaque = annonceNormale();
    arnaque.titre = "iPhone 15 Pro neuf URGENT";
    arnaque.description = "Paiement par virement ou Western Union, envoi par transporteur.";
    arnaque.prix = 1500;
    arnaque.prixMedianCategorie = 7000;
    const auto r = analyseur.analyser(arnaque);
    VERIFIER(r.score >= 60);
    VERIFIER_EGAL(std::string("ELEVE"), r.niveau());
    VERIFIER(aRaison(r, "mots_suspects"));
    VERIFIER(aRaison(r, "prix_anormal"));
    VERIFIER_EGAL(std::string("mots_suspects"), r.raisons.front().regle);   // la plus lourde d'abord (45)

    // Prix : médiane sur trop peu d'annonces → pas de jugement
    ContexteAnnonce peu = annonceNormale();
    peu.prix = 10;
    peu.nbAnnoncesCategorie = 2;
    VERIFIER(!ReglePrixAnormal().evaluer(peu).has_value());
    peu.nbAnnoncesCategorie = 3;
    VERIFIER_EGAL(35, ReglePrixAnormal().evaluer(peu)->points);

    // Mots : "virements" ne déclenche pas "virement" ; accents et casse ignorés
    ContexteAnnonce mots = annonceNormale();
    mots.description = "Pas de virements";
    VERIFIER(!RegleMotsSuspects().evaluer(mots).has_value());
    mots.description = "PRIX SACRIFIÉ";
    VERIFIER(RegleMotsSuspects().evaluer(mots).has_value());

    // Coordonnées
    ContexteAnnonce coord = annonceNormale();
    coord.description = "Appelez le 06 12 34 56 78";
    VERIFIER(RegleCoordonnees().evaluer(coord).has_value());
    coord.description = "Joignable au +212 6 12 34 56 78";
    VERIFIER(RegleCoordonnees().evaluer(coord).has_value());
    coord.description = "contact : vendeur@exemple.ma";
    VERIFIER(RegleCoordonnees().evaluer(coord).has_value());
    coord.description = "Année 2019, 120000 km";
    VERIFIER(!RegleCoordonnees().evaluer(coord).has_value());

    // Majuscules et volume
    ContexteAnnonce criard = annonceNormale();
    criard.titre = "SUPER AFFAIRE !!!";
    VERIFIER_EGAL(15, RegleMajuscules().evaluer(criard)->points);
    criard.titre = "TV LG";   // trop court pour juger
    VERIFIER(!RegleMajuscules().evaluer(criard).has_value());
    ContexteAnnonce volume = annonceNormale();
    volume.annoncesAuteur24h = 12;
    VERIFIER_EGAL(30, RegleVolumeAnnonces().evaluer(volume)->points);

    // Règle générique (template) compte récent
    ContexteAnnonce nouveau = annonceNormale();
    nouveau.compte.ancienneteJours = 0.5;
    VERIFIER_EGAL(20, RegleCompteRecent<ContexteAnnonce>().evaluer(nouveau)->points);

    // Plafond à 100
    AnalyseurRisque<ContexteAnnonce> extreme;
    extreme.ajouter(std::make_unique<RegleToujours>(70)).ajouter(std::make_unique<RegleToujours>(70));
    VERIFIER_EGAL(100, extreme.analyser(annonceNormale()).score);

    // --- Commandes
    const auto analyseurCmd = analyseurCommande();
    ContexteCommande cmd;
    cmd.totalTtc = 450;
    cmd.quantiteMax = 1;
    cmd.modePaiement = "CARTE";
    cmd.commandesPrecedentes = 6;
    cmd.panierMoyen = 500;
    cmd.commandes24h = 1;
    VERIFIER_EGAL(0, analyseurCmd.analyser(cmd).score);

    ContexteCommande louche = cmd;
    louche.totalTtc = 12000;
    louche.quantiteMax = 15;
    louche.modePaiement = "LIVRAISON";
    louche.commandes24h = 5;
    louche.compte.ancienneteJours = 1;
    const auto rc = analyseurCmd.analyser(louche);
    VERIFIER_EGAL(100, rc.score);   // 25 + 15 + 25 + 15 + 20 = 100
    VERIFIER_EGAL(5u, rc.raisons.size());

    ContexteCommande premiere = cmd;
    premiere.commandesPrecedentes = 0;
    premiere.totalTtc = 15000;
    VERIFIER_EGAL(20, RegleMontantInhabituel().evaluer(premiere)->points);
    return verif::bilan();
}
