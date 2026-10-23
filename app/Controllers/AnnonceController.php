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
use App\Models\Annonce;
use App\Models\Categorie;
use App\Models\FiltresAnnonces;
use App\Models\Messagerie;
use App\Services\ScoreRisque;
use App\Services\Upload;

/** Petites annonces : liste publique, fiche, publication, gestion par l'auteur, favoris, signalement */
final class AnnonceController extends Controller
{
    // Clients et vendeurs publient des annonces ; l'admin modère (étape 7)
    private const MEMBRES = ['CLIENT', 'VENDEUR'];

    public function index(): Response
    {
        $filtres = FiltresAnnonces::depuisRequete($this->request->query);
        $modele = new Annonce($this->db);
        $resultat = $modele->rechercher($filtres);
        return $this->vue('annonces/index', [
            'filtres' => $filtres, 'annonces' => $resultat['annonces'], 'total' => $resultat['total'],
            'villes' => $modele->villes(), 'categories' => (new Categorie($this->db))->arbre(),
        ], 'Annonces Occasion');
    }

    public function fiche(string $id): Response
    {
        $annonce = $this->annonceVisible($id);
        return $this->vue('annonces/fiche', [
            'annonce' => $annonce,
            'chemin' => (new Categorie($this->db))->chemin($annonce['id_categorie']),
        ], $annonce['titre']);
    }

    // ------------------------------------------------------------------ publication

    public function nouvelle(): Response
    {
        Auth::exigerRole(...self::MEMBRES);
        return $this->formulaire(null, ['titre' => '', 'description' => '', 'prix' => '', 'ville' => '', 'id_categorie' => ''], []);
    }

    public function publier(): Response
    {
        $moi = Auth::exigerRole(...self::MEMBRES);
        [$valeurs, $erreurs] = Annonce::validerFormulaire($this->champs());
        if ($erreurs === []) {
            try {
                // Score de risque calculé par le moteur C++ ; PKG_ANNONCE décide du statut
                $risque = (new ScoreRisque($this->db, $this->moteur()))->annonce($moi['id'], $valeurs);
                $modele = new Annonce($this->db);
                $id = $modele->publier($moi['id'], $valeurs, $risque['score'] ?? null);
                $this->db->valider();
                // On ne détaille PAS les raisons à l'auteur : ce serait apprendre aux
                // fraudeurs à contourner les règles
                Session::flash('succes', $modele->statut($id) === 'EN_MODERATION'
                    ? 'Annonce enregistrée. Elle sera vérifiée par notre équipe avant sa mise en ligne.'
                    : 'Annonce publiée. Ajoutez des photos pour la rendre plus attractive.');
                return $this->rediriger('/mes-annonces/' . $id);
            } catch (ErreurMetier $erreur) {
                $this->db->annuler();
                $erreurs['general'] = $erreur->getMessage();
            }
        }
        return $this->formulaire(null, $this->champs(), $erreurs, 422);
    }

    // ------------------------------------------------------------------ gestion par l'auteur

    public function mesAnnonces(): Response
    {
        $moi = Auth::exigerRole(...self::MEMBRES);
        return $this->vue('annonces/mes_annonces', ['annonces' => (new Annonce($this->db))->mesAnnonces($moi['id'])],
            'Mes annonces');
    }

    public function edition(string $id): Response
    {
        $annonce = $this->annonceDeLAuteur($id);
        return $this->formulaire($annonce, [
            'titre' => $annonce['titre'], 'description' => $annonce['description'],
            'prix' => number_format($annonce['prix'], 2, ',', ''), 'ville' => $annonce['ville'],
            'id_categorie' => (string) $annonce['id_categorie'],
        ], []);
    }

    public function modifier(string $id): Response
    {
        $annonce = $this->annonceDeLAuteur($id);
        [$valeurs, $erreurs] = Annonce::validerFormulaire($this->champs());
        if ($erreurs === []) {
            try {
                $moi = Auth::utilisateur();
                $risque = (new ScoreRisque($this->db, $this->moteur()))->annonce($moi['id'], $valeurs);
                $modele = new Annonce($this->db);
                $modele->modifier($annonce['id'], $moi['id'], $valeurs, $risque['score'] ?? null);
                $this->db->valider();
                Session::flash('succes', $annonce['statut'] === 'EN_LIGNE' && $modele->statut($annonce['id']) === 'EN_MODERATION'
                    ? 'Annonce enregistrée. Elle sera vérifiée par notre équipe avant de revenir en ligne.'
                    : 'Annonce enregistrée.');
                return $this->rediriger('/mes-annonces/' . $annonce['id']);
            } catch (ErreurMetier $erreur) {
                $this->db->annuler();
                $erreurs['general'] = $erreur->getMessage();
            }
        }
        return $this->formulaire($annonce, $this->champs(), $erreurs, 422);
    }

    /** POST /mes-annonces/{id}/{action} : renouveler ou marquer vendue */
    public function action(string $id, string $action): Response
    {
        $annonce = $this->annonceDeLAuteur($id);
        if (!in_array($action, ['renouveler', 'vendue'], true)) {
            throw new RouteIntrouvable('/mes-annonces/' . $id . '/' . $action);
        }
        try {
            (new Annonce($this->db))->action($action, $annonce['id'], Auth::utilisateur()['id']);
            $this->db->valider();
            Session::flash('succes', $action === 'vendue' ? 'Annonce marquée comme vendue. Félicitations !'
                                                            : 'Annonce renouvelée pour 30 jours.');
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            Session::flash('erreur', $erreur->getMessage());
        }
        return $this->rediriger('/mes-annonces');
    }

    public function ajouterPhoto(string $id): Response
    {
        $annonce = $this->annonceDeLAuteur($id);
        $upload = new Upload(Config::get('dossier_public'));
        $chemin = null;
        try {
            $chemin = $upload->photo($this->request->fichier('photo'), 'annonces');
            (new Annonce($this->db))->ajouterPhoto($annonce['id'], Auth::utilisateur()['id'], $chemin);
            $this->db->valider();
            Session::flash('succes', 'Photo ajoutée.');
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            if ($chemin !== null) {
                $upload->supprimer($chemin);
            }
            Session::flash('erreur', $erreur->getMessage());
        }
        return $this->rediriger('/mes-annonces/' . $annonce['id']);
    }

    public function supprimerPhoto(string $id, string $photo): Response
    {
        $annonce = $this->annonceDeLAuteur($id);
        $idPhoto = filter_var($photo, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        try {
            if ($idPhoto === false) {
                throw new ErreurMetier(ErreurMetier::INTROUVABLE, 'Photo introuvable.');
            }
            $chemin = (new Annonce($this->db))->retirerPhoto($idPhoto, Auth::utilisateur()['id']);
            $this->db->valider();
            (new Upload(Config::get('dossier_public')))->supprimer($chemin);
            Session::flash('succes', 'Photo supprimée.');
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            Session::flash('erreur', $erreur->getMessage());
        }
        return $this->rediriger('/mes-annonces/' . $annonce['id']);
    }

    // ------------------------------------------------------------------ visiteurs connectés

    public function favoris(): Response
    {
        $moi = Auth::exigerRole(...self::MEMBRES);
        return $this->vue('annonces/favoris', ['annonces' => (new Annonce($this->db))->favoris($moi['id'])], 'Mes favoris');
    }

    public function basculerFavori(string $id): Response
    {
        $moi = Auth::exigerRole(...self::MEMBRES);
        $annonce = $this->annonceVisible($id);
        $ajouter = $this->request->champ('favori') === '1';
        (new Annonce($this->db))->basculerFavori($moi['id'], $annonce['id'], $ajouter);
        $this->db->valider();
        Session::flash('succes', $ajouter ? 'Ajoutée à vos favoris.' : 'Retirée de vos favoris.');
        return $this->rediriger('/annonce/' . $annonce['id']);
    }

    /** POST /annonce/{id}/contacter : ouvre (ou retrouve) la conversation et envoie le 1er message */
    public function contacter(string $id): Response
    {
        $moi = Auth::exigerRole(...self::MEMBRES);
        $annonce = $this->annonceVisible($id);
        $messagerie = new Messagerie($this->db);
        try {
            $conversation = $messagerie->ouvrir($annonce['id'], $moi['id']);
            $messagerie->envoyer($conversation, $moi['id'], $this->request->champ('message'));
            $this->db->valider();
            return $this->rediriger('/messages/' . $conversation);
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            Session::flash('erreur', $erreur->getMessage());
            return $this->rediriger('/annonce/' . $annonce['id']);
        }
    }

    public function signaler(string $id): Response
    {
        $moi = Auth::exigerRole(...self::MEMBRES);
        $annonce = $this->annonceVisible($id);
        try {
            (new Annonce($this->db))->signaler($moi['id'], $annonce['id'], $this->request->champ('motif'),
                mb_substr($this->request->champ('commentaire'), 0, 1000));
            $this->db->valider();
            Session::flash('succes', 'Merci : votre signalement sera examiné par un modérateur.');
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            Session::flash('erreur', $erreur->getMessage());
        }
        return $this->rediriger('/annonce/' . $annonce['id']);
    }

    // ------------------------------------------------------------------ outils

    /** @return array<string, mixed> annonce en ligne, ou de l'utilisateur connecté ; 404 sinon */
    private function annonceVisible(string $id): array
    {
        $idAnnonce = filter_var($id, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        $annonce = $idAnnonce === false ? null : (new Annonce($this->db))->fiche($idAnnonce, Auth::utilisateur()['id'] ?? null);
        if ($annonce === null) {
            throw new RouteIntrouvable('/annonce/' . $id);
        }
        return $annonce;
    }

    /** @return array<string, mixed> annonce de l'utilisateur connecté ; 404 pour celle d'un autre */
    private function annonceDeLAuteur(string $id): array
    {
        Auth::exigerRole(...self::MEMBRES);
        $annonce = $this->annonceVisible($id);
        if (!$annonce['est_auteur']) {
            throw new RouteIntrouvable('/mes-annonces/' . $id);
        }
        return $annonce;
    }

    /** @return array<string, string> */
    private function champs(): array
    {
        $champs = [];
        foreach (['titre', 'description', 'prix', 'ville', 'id_categorie'] as $nom) {
            $champs[$nom] = $this->request->champ($nom);
        }
        return $champs;
    }

    /**
     * @param array<string, mixed>|null $annonce
     * @param array<string, string> $valeurs
     * @param array<string, string> $erreurs
     */
    private function formulaire(?array $annonce, array $valeurs, array $erreurs, int $statut = 200): Response
    {
        return $this->vue('annonces/formulaire', [
            'annonce' => $annonce, 'valeurs' => $valeurs, 'erreurs' => $erreurs,
            'categories' => (new Categorie($this->db))->arbre(),
        ], $annonce === null ? 'Publier une annonce' : 'Modifier mon annonce', $statut);
    }
}
