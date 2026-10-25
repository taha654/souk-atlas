<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Auth;
use App\Core\Config;
use App\Core\Controller;
use App\Core\Erreurs\ErreurMetier;
use App\Core\Erreurs\RouteIntrouvable;
use App\Core\Response;
use App\Core\Session;
use App\Models\Boutique;
use App\Models\Categorie;
use App\Models\Commande;
use App\Models\CommandeVendeur;
use App\Models\ProduitVendeur;
use App\Models\Statistiques;
use App\Services\ModeDemo;
use App\Services\Upload;

/**
 * Espace vendeur. Chaque action commence par boutique() : le vendeur connecté
 * n'agit QUE sur sa propre boutique. L'identifiant de boutique ne vient jamais
 * du formulaire ni de l'URL, et PKG_CATALOGUE / PKG_COMMANDE revérifient en base.
 */
final class VendeurController extends Controller
{
    // ------------------------------------------------------------------ tableau de bord

    public function index(): Response
    {
        $moi = Auth::exigerRole('VENDEUR');
        $boutique = (new Boutique($this->db))->duVendeur($moi['id']);
        if ($boutique === null) {
            return $this->vue('vendeur/boutique', ['boutique' => null, 'valeurs' => ['ville' => ''], 'erreurs' => []],
                'Ouvrir ma boutique');
        }
        return $this->vue('vendeur/index', [
            'boutique' => $boutique,
            'stats' => (new Statistiques($this->db))->tableauDeBord($boutique['id'], 30),
            'compteurs' => (new CommandeVendeur($this->db))->compteurs($boutique['id']),
            'alertesStock' => array_values(array_filter((new ProduitVendeur($this->db))->liste($boutique['id']),
                static fn (array $p) => $p['statut'] === 'ACTIF' && $p['stock'] <= 5)),
        ], 'Espace vendeur');
    }

    // ------------------------------------------------------------------ boutique

    public function formulaireBoutique(): Response
    {
        $boutique = $this->boutique();
        return $this->vue('vendeur/boutique', ['boutique' => $boutique, 'valeurs' => $boutique, 'erreurs' => []], 'Ma boutique');
    }

    public function enregistrerBoutique(): Response
    {
        $moi = Auth::exigerRole('VENDEUR');
        $modele = new Boutique($this->db);
        $existante = $modele->duVendeur($moi['id']);
        $valeurs = ['nom' => $this->request->champ('nom'), 'description' => $this->request->champ('description'),
                    'ville' => $this->request->champ('ville')];
        $erreurs = Boutique::validerFormulaire($valeurs);
        if ($erreurs === []) {
            try {
                if ($existante === null) {
                    $modele->creer($moi['id'], $valeurs['nom'], $valeurs['description'], $valeurs['ville']);
                    $message = 'Boutique créée. Elle sera visible dès que l\'administrateur l\'aura validée.';
                } else {
                    $modele->modifier($moi['id'], $valeurs['nom'], $valeurs['description'], $valeurs['ville']);
                    $message = 'Boutique mise à jour.';
                }
                $this->db->valider();
                Session::flash('succes', $message);
                return $this->rediriger('/vendeur');
            } catch (ErreurMetier $erreur) {
                $this->db->annuler();
                $erreurs['nom'] = $erreur->getMessage();
            }
        }
        return $this->vue('vendeur/boutique', ['boutique' => $existante, 'valeurs' => $valeurs, 'erreurs' => $erreurs],
            'Ma boutique', 422);
    }

    // ------------------------------------------------------------------ produits

    public function produits(): Response
    {
        $boutique = $this->boutique();
        return $this->vue('vendeur/produits', [
            'boutique' => $boutique,
            'produits' => (new ProduitVendeur($this->db))->liste($boutique['id']),
        ], 'Mes produits');
    }

    public function nouveauProduit(): Response
    {
        $this->boutique();
        return $this->formulaireProduit(null, ['nom' => '', 'description' => '', 'prix_ht' => '', 'stock' => '1',
                                               'id_categorie' => ''], []);
    }

    public function creerProduit(): Response
    {
        $boutique = $this->boutique();
        [$valeurs, $erreurs] = ProduitVendeur::validerFormulaire($this->champsProduit(true), true);
        if ($erreurs === []) {
            try {
                $id = (new ProduitVendeur($this->db))->creer($boutique['id'], $valeurs);
                $this->db->valider();
                Session::flash('succes', 'Produit créé. Ajoutez-lui des photos.');
                return $this->rediriger('/vendeur/produits/' . $id);
            } catch (ErreurMetier $erreur) {
                $this->db->annuler();
                $erreurs['general'] = $erreur->getMessage();
            }
        }
        return $this->formulaireProduit(null, $this->champsProduit(true), $erreurs, 422);
    }

    public function produit(string $id): Response
    {
        $boutique = $this->boutique();
        $produit = $this->produitDeLaBoutique($id, $boutique['id']);
        return $this->formulaireProduit($produit, [
            'nom' => $produit['nom'], 'description' => $produit['description'],
            'prix_ht' => number_format($produit['prix_ht'], 2, ',', ''),
            'id_categorie' => (string) $produit['id_categorie'], 'statut' => $produit['statut'],
        ], []);
    }

    public function modifierProduit(string $id): Response
    {
        $boutique = $this->boutique();
        $produit = $this->produitDeLaBoutique($id, $boutique['id']);
        [$valeurs, $erreurs] = ProduitVendeur::validerFormulaire($this->champsProduit(false), false);
        if ($erreurs === []) {
            try {
                (new ProduitVendeur($this->db))->modifier($produit['id'], $boutique['id'], $valeurs);
                $this->db->valider();
                Session::flash('succes', 'Produit enregistré.');
                return $this->rediriger('/vendeur/produits/' . $produit['id']);
            } catch (ErreurMetier $erreur) {
                $this->db->annuler();
                $erreurs['general'] = $erreur->getMessage();
            }
        }
        return $this->formulaireProduit($produit, $this->champsProduit(false), $erreurs, 422);
    }

    public function ajusterStock(string $id): Response
    {
        $boutique = $this->boutique();
        $produit = $this->produitDeLaBoutique($id, $boutique['id']);
        $delta = $this->entier('delta', -ProduitVendeur::STOCK_MAX, ProduitVendeur::STOCK_MAX);
        try {
            if ($delta === null || $delta === 0) {
                throw new ErreurMetier(ErreurMetier::QUANTITE_INVALIDE, 'Indiquez une quantité à ajouter ou à retirer.');
            }
            (new ProduitVendeur($this->db))->ajusterStock($produit['id'], $boutique['id'], $delta);
            $this->db->valider();
            Session::flash('succes', $delta > 0 ? "$delta article(s) ajouté(s) au stock." : abs($delta) . ' article(s) retiré(s) du stock.');
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            Session::flash('erreur', $erreur->getMessage());
        }
        return $this->rediriger('/vendeur/produits/' . $produit['id']);
    }

    public function ajouterPhoto(string $id): Response
    {
        $boutique = $this->boutique();
        $produit = $this->produitDeLaBoutique($id, $boutique['id']);
        $upload = new Upload(Config::get('dossier_public'), ModeDemo::tailleMaxPhoto());
        $chemin = null;
        try {
            ModeDemo::verifierQuotaPhotos($this->db, Auth::utilisateur()['id'], Config::get('dossier_public'));
            $chemin = $upload->photo($this->request->fichier('photo'), 'produits');
            (new ProduitVendeur($this->db))->ajouterPhoto($produit['id'], $boutique['id'], $chemin);
            $this->db->valider();
            Session::flash('succes', 'Photo ajoutée.');
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            if ($chemin !== null) {
                $upload->supprimer($chemin);   // refusée en base (6 photos max) : pas de fichier orphelin
            }
            Session::flash('erreur', $erreur->getMessage());
        }
        return $this->rediriger('/vendeur/produits/' . $produit['id']);
    }

    public function supprimerPhoto(string $id, string $photo): Response
    {
        $boutique = $this->boutique();
        $produit = $this->produitDeLaBoutique($id, $boutique['id']);
        $idPhoto = filter_var($photo, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        try {
            if ($idPhoto === false) {
                throw new ErreurMetier(ErreurMetier::INTROUVABLE, 'Photo introuvable.');
            }
            $chemin = (new ProduitVendeur($this->db))->retirerPhoto($idPhoto, $boutique['id']);
            $this->db->valider();
            // Le fichier n'est effacé qu'APRÈS la validation en base
            (new Upload(Config::get('dossier_public')))->supprimer($chemin);
            Session::flash('succes', 'Photo supprimée.');
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            Session::flash('erreur', $erreur->getMessage());
        }
        return $this->rediriger('/vendeur/produits/' . $produit['id']);
    }

    // ------------------------------------------------------------------ commandes reçues

    public function commandes(): Response
    {
        $boutique = $this->boutique();
        $statut = $this->request->parametre('statut');
        $statut = isset(Commande::STATUTS[$statut]) ? $statut : null;
        $modele = new CommandeVendeur($this->db);
        return $this->vue('vendeur/commandes', [
            'commandes' => $modele->liste($boutique['id'], $statut),
            'compteurs' => $modele->compteurs($boutique['id']),
            'statut' => $statut,
        ], 'Commandes reçues');
    }

    public function commande(string $numero): Response
    {
        $boutique = $this->boutique();
        $commande = (new CommandeVendeur($this->db))->detail($numero, $boutique['id']);
        if ($commande === null) {
            throw new RouteIntrouvable('/vendeur/commandes/' . $numero);
        }
        return $this->vue('vendeur/commande', ['commande' => $commande], 'Commande ' . $commande['numero']);
    }

    public function changerStatutCommande(string $numero): Response
    {
        $boutique = $this->boutique();
        $modele = new CommandeVendeur($this->db);
        $commande = $modele->detail($numero, $boutique['id']);
        if ($commande === null) {
            throw new RouteIntrouvable('/vendeur/commandes/' . $numero);
        }
        try {
            $modele->changerStatut($commande['id'], $boutique['id'], $this->request->champ('statut'));
            $this->db->valider();
            Session::flash('succes', 'Commande mise à jour.');
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            Session::flash('erreur', $erreur->getMessage());
        }
        return $this->rediriger('/vendeur/commandes/' . rawurlencode($numero));
    }

    // ------------------------------------------------------------------ outils

    /** Boutique du vendeur connecté ; sans boutique, renvoi vers sa création */
    private function boutique(): array
    {
        $moi = Auth::exigerRole('VENDEUR');
        $boutique = (new Boutique($this->db))->duVendeur($moi['id']);
        if ($boutique === null) {
            throw new RouteIntrouvable('Aucune boutique : la créer depuis /vendeur');
        }
        return $boutique;
    }

    /** Un produit d'une AUTRE boutique répond 404, comme s'il n'existait pas */
    private function produitDeLaBoutique(string $id, int $idBoutique): array
    {
        $idProduit = filter_var($id, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        $produit = $idProduit === false ? null : (new ProduitVendeur($this->db))->fiche($idProduit, $idBoutique);
        if ($produit === null) {
            throw new RouteIntrouvable('/vendeur/produits/' . $id);
        }
        return $produit;
    }

    /** @return array<string, string> */
    private function champsProduit(bool $creation): array
    {
        $champs = [];
        foreach (['nom', 'description', 'prix_ht', 'id_categorie', $creation ? 'stock' : 'statut'] as $nom) {
            $champs[$nom] = $this->request->champ($nom);
        }
        return $champs;
    }

    /**
     * @param array<string, mixed>|null $produit
     * @param array<string, string> $valeurs
     * @param array<string, string> $erreurs
     */
    private function formulaireProduit(?array $produit, array $valeurs, array $erreurs, int $statut = 200): Response
    {
        return $this->vue('vendeur/produit', [
            'produit' => $produit,
            'valeurs' => $valeurs,
            'erreurs' => $erreurs,
            'categories' => (new Categorie($this->db))->arbre(),
        ], $produit === null ? 'Nouveau produit' : $produit['nom'], $statut);
    }
}
