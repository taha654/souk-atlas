<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Auth;
use App\Core\Controller;
use App\Core\Erreurs\ErreurMetier;
use App\Core\Erreurs\RouteIntrouvable;
use App\Core\Response;
use App\Core\Session;
use App\Models\Administration;
use App\Models\Categorie;
use App\Models\Moderation;
use App\Models\Promotion;
use App\Services\ErreurMoteur;
use App\Services\Recommandations;

/**
 * Espace administrateur. Chaque action commence par admin() (rôle ADMIN exigé
 * côté serveur). Les règles métier restent dans les packages PL/SQL.
 */
final class AdminController extends Controller
{
    // ------------------------------------------------------------------ tableau de bord

    public function index(): Response
    {
        $this->admin();
        $administration = new Administration($this->db);
        return $this->vue('admin/index', [
            'aTraiter' => $administration->aTraiter(),
            'stats' => $administration->statistiques(30),
            'recommandations' => $administration->etatRecommandations(),
        ], 'Administration');
    }

    /** GET /api/admin/statistiques?jours=… */
    public function apiStatistiques(): Response
    {
        $this->admin();
        $jours = (int) $this->request->parametre('jours');
        $jours = in_array($jours, [7, 30, 90, 365], true) ? $jours : 30;
        return Response::json((new Administration($this->db))->statistiques($jours));
    }

    // ------------------------------------------------------------------ modération

    public function moderation(): Response
    {
        $this->admin();
        return $this->vue('admin/moderation', ['annonces' => (new Moderation($this->db))->annoncesAVerifier()], 'Annonces à vérifier');
    }

    public function modererAnnonce(string $id): Response
    {
        $this->admin();
        $decision = $this->request->champ('decision');
        return $this->executer('/admin/moderation',
            fn () => (new Moderation($this->db))->modererAnnonce($this->id($id), $decision, $this->request->champ('motif')),
            $decision === 'APPROUVER' ? 'Annonce mise en ligne.' : 'Annonce refusée.');
    }

    public function signalements(): Response
    {
        $this->admin();
        $statut = in_array($this->request->parametre('statut'), ['OUVERT', 'APPROUVE', 'REJETE'], true)
            ? $this->request->parametre('statut') : 'OUVERT';
        return $this->vue('admin/signalements', [
            'signalements' => (new Moderation($this->db))->signalements($statut), 'statut' => $statut,
        ], 'Signalements');
    }

    public function signalement(string $id): Response
    {
        $this->admin();
        $signalement = (new Moderation($this->db))->signalement($this->id($id));
        if ($signalement === null) {
            throw new RouteIntrouvable('/admin/signalements/' . $id);
        }
        return $this->vue('admin/signalement', ['signalement' => $signalement], 'Signalement');
    }

    public function traiterSignalement(string $id): Response
    {
        $moi = $this->admin();
        $decision = $this->request->champ('decision');
        return $this->executer('/admin/signalements',
            fn () => (new Moderation($this->db))->traiterSignalement($this->id($id), $moi['id'], $decision),
            $decision === 'APPROUVER' ? 'Signalement approuvé : le contenu a été retiré.' : 'Signalement rejeté : le contenu reste en ligne.');
    }

    public function avis(): Response
    {
        $this->admin();
        return $this->vue('admin/avis', ['avis' => (new Moderation($this->db))->avis()], 'Avis');
    }

    public function statutAvis(string $id): Response
    {
        $this->admin();
        $statut = $this->request->champ('statut');
        return $this->executer('/admin/avis',
            fn () => (new Moderation($this->db))->changerStatutAvis($this->id($id), $statut),
            $statut === 'MASQUE' ? 'Avis masqué.' : 'Avis republié.');
    }

    // ------------------------------------------------------------------ vendeurs et utilisateurs

    public function boutiques(): Response
    {
        $this->admin();
        $statut = $this->request->parametre('statut');
        $statut = in_array($statut, ['EN_ATTENTE', 'VALIDEE', 'REFUSEE', 'SUSPENDUE'], true) ? $statut : null;
        return $this->vue('admin/boutiques', ['boutiques' => (new Administration($this->db))->boutiques($statut),
            'statut' => $statut], 'Boutiques');
    }

    public function statutBoutique(string $id): Response
    {
        $this->admin();
        return $this->executer('/admin/boutiques',
            fn () => (new Administration($this->db))->changerStatutBoutique($this->id($id), $this->request->champ('statut')),
            'Boutique mise à jour.');
    }

    public function utilisateurs(): Response
    {
        $this->admin();
        $recherche = mb_substr($this->request->parametre('q'), 0, 100);
        return $this->vue('admin/utilisateurs', ['utilisateurs' => (new Administration($this->db))->utilisateurs($recherche),
            'recherche' => $recherche], 'Utilisateurs');
    }

    public function modifierUtilisateur(string $id): Response
    {
        $moi = $this->admin();
        $idUtilisateur = $this->id($id);
        $action = $this->request->champ('action');
        if ($idUtilisateur === $moi['id']) {
            // Un admin qui se retire ses droits par erreur ne pourrait plus rien corriger
            Session::flash('erreur', 'Vous ne pouvez pas modifier votre propre compte depuis cet écran.');
            return $this->rediriger('/admin/utilisateurs');
        }
        if (!in_array($action, ['role:CLIENT', 'role:VENDEUR', 'role:ADMIN', 'desactiver', 'reactiver'], true)) {
            Session::flash('erreur', 'Action inconnue.');
            return $this->rediriger('/admin/utilisateurs');
        }
        return $this->executer('/admin/utilisateurs',
            fn () => (new Administration($this->db))->modifierUtilisateur($idUtilisateur, $action), 'Compte mis à jour.');
    }

    // ------------------------------------------------------------------ catalogue

    public function categories(): Response
    {
        $this->admin();
        $modele = new Categorie($this->db);
        return $this->vue('admin/categories', ['arbre' => $modele->arbre(), 'annonces' => $modele->nbAnnoncesParCategorie()],
            'Catégories');
    }

    public function creerCategorie(): Response
    {
        $this->admin();
        $parent = $this->entier('id_parent', 1, PHP_INT_MAX);
        return $this->executer('/admin/categories',
            fn () => (new Categorie($this->db))->creer($this->request->champ('nom'), $parent), 'Catégorie créée.');
    }

    public function renommerCategorie(string $id): Response
    {
        $this->admin();
        return $this->executer('/admin/categories',
            fn () => (new Categorie($this->db))->renommer($this->id($id), $this->request->champ('nom')), 'Catégorie renommée.');
    }

    public function supprimerCategorie(string $id): Response
    {
        $this->admin();
        return $this->executer('/admin/categories',
            fn () => (new Categorie($this->db))->supprimer($this->id($id)), 'Catégorie supprimée.');
    }

    public function promotions(): Response
    {
        $this->admin();
        return $this->vue('admin/promotions', ['promotions' => (new Promotion($this->db))->liste(),
            'categories' => (new Categorie($this->db))->arbre()], 'Promotions');
    }

    public function creerPromotion(): Response
    {
        $this->admin();
        $date = static fn (string $v) => preg_match('/^\d{4}-\d{2}-\d{2}$/', $v) === 1 ? $v : '';
        $pourcentage = filter_var(str_replace(',', '.', $this->request->champ('pourcentage')), FILTER_VALIDATE_FLOAT);
        $cible = $this->request->champ('cible');   // "categorie:12" ou "produit:4"
        [$type, $idCible] = array_pad(explode(':', $cible, 2), 2, '');
        $idCible = filter_var($idCible, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        return $this->executer('/admin/promotions', function () use ($date, $pourcentage, $type, $idCible) {
            if ($pourcentage === false || $idCible === false || !in_array($type, ['produit', 'categorie'], true)
                || $date($this->request->champ('debut')) === '' || $date($this->request->champ('fin')) === '') {
                throw new ErreurMetier(ErreurMetier::PROMOTION_INVALIDE, 'Formulaire de promotion incomplet.');
            }
            (new Promotion($this->db))->creer($this->request->champ('libelle'), (float) $pourcentage,
                $this->request->champ('debut'), $this->request->champ('fin'),
                $type === 'produit' ? $idCible : null, $type === 'categorie' ? $idCible : null);
        }, 'Promotion créée.');
    }

    public function desactiverPromotion(string $id): Response
    {
        $this->admin();
        return $this->executer('/admin/promotions',
            fn () => (new Promotion($this->db))->desactiver($this->id($id)), 'Promotion arrêtée.');
    }

    /** POST /admin/recommandations : nouveau calcul immédiat par le moteur C++ */
    public function recalculerRecommandations(): Response
    {
        $this->admin();
        try {
            $nb = (new Recommandations($this->db, $this->moteur()))->recalculer();
            Session::flash('succes', "Recommandations recalculées par le moteur C++ : $nb paire(s).");
        } catch (ErreurMoteur $erreur) {
            $this->db->annuler();
            Session::flash('erreur', 'Moteur C++ indisponible : ' . $erreur->getMessage());
        }
        return $this->rediriger('/admin');
    }

    public function journal(): Response
    {
        $this->admin();
        $table = in_array($this->request->parametre('table'), ['UTILISATEUR', 'PRODUIT', 'COMMANDE'], true)
            ? $this->request->parametre('table') : null;
        return $this->vue('admin/journal', ['entrees' => (new Administration($this->db))->journal($table), 'table' => $table],
            'Journal d\'audit');
    }

    // ------------------------------------------------------------------ outils

    /** @return array{id: int, nom: string, email: string, role: string} */
    private function admin(): array
    {
        return Auth::exigerRole('ADMIN');
    }

    private function id(string $id): int
    {
        $valeur = filter_var($id, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        if ($valeur === false) {
            throw new RouteIntrouvable($id);
        }
        return $valeur;
    }

    /**
     * Exécute une action, valide la transaction, prépare le message, puis
     * redirige. Une erreur métier (package PL/SQL) annule tout et s'affiche.
     */
    private function executer(string $retour, callable $action, string $succes): Response
    {
        try {
            $action();
            $this->db->valider();
            Session::flash('succes', $succes);
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            Session::flash('erreur', $erreur->getMessage());
        }
        return $this->rediriger($retour);
    }
}
