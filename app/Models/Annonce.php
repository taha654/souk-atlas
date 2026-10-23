<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\Database;

/** Petites annonces : lectures et appels à PKG_ANNONCE (propriété vérifiée en base) */
final class Annonce
{
    public const STATUTS = [
        'EN_MODERATION' => 'En cours de vérification', 'EN_LIGNE' => 'En ligne', 'REFUSEE' => 'Refusée',
        'VENDUE' => 'Vendue', 'EXPIREE' => 'Expirée',
    ];

    public function __construct(private readonly Database $db)
    {
    }

    /** @return array{annonces: list<array<string, mixed>>, total: int} */
    public function rechercher(FiltresAnnonces $f): array
    {
        $lignes = $this->db->curseur(
            'pkg_annonce.rechercher(p_texte => :q, p_id_categorie => :categorie, p_ville => :ville,
                                    p_prix_min => :min, p_prix_max => :max, p_tri => :tri,
                                    p_page => :page, p_taille_page => :taille)',
            ['q' => $f->texte === '' ? null : $f->texte, 'categorie' => $f->categorie,
             'ville' => $f->ville === '' ? null : $f->ville, 'min' => $f->prixMin, 'max' => $f->prixMax,
             'tri' => $f->tri, 'page' => $f->page, 'taille' => FiltresAnnonces::TAILLE_PAGE],
        );
        return [
            'annonces' => array_map(static fn (array $l) => [
                'id' => (int) $l['ID'], 'titre' => $l['TITRE'], 'prix' => (float) $l['PRIX'], 'ville' => $l['VILLE'],
                'categorie' => $l['CATEGORIE'], 'date' => $l['DATE_PUBLICATION'], 'photo' => $l['PHOTO'],
            ], $lignes),
            'total' => $lignes === [] ? 0 : (int) $lignes[0]['TOTAL'],
        ];
    }

    /** Villes ayant au moins une annonce en ligne (liste déroulante du filtre) @return list<string> */
    public function villes(): array
    {
        return array_column($this->db->lignes(
            "SELECT DISTINCT ville FROM annonce WHERE statut = 'EN_LIGNE' ORDER BY NLSSORT(ville, 'NLS_SORT=FRENCH')"), 'VILLE');
    }

    /**
     * Fiche d'une annonce. Visible par tous si EN_LIGNE ; sinon seulement par son
     * auteur (pour suivre une annonce en modération, vendue, expirée…).
     *
     * @return array<string, mixed>|null
     */
    public function fiche(int $id, ?int $idLecteur): ?array
    {
        $l = $this->db->ligne(
            "SELECT a.id, a.titre, a.description, a.prix, a.ville, a.statut, a.id_categorie, a.motif_refus,
                    a.date_publication, a.date_expiration, a.id_utilisateur, u.nom AS auteur, u.date_creation AS membre_depuis,
                    (SELECT COUNT(*) FROM favori f WHERE f.id_annonce = a.id AND f.id_utilisateur = :lecteur) AS en_favori
               FROM annonce a JOIN utilisateur u ON u.id = a.id_utilisateur
              WHERE a.id = :id AND (a.statut = 'EN_LIGNE' OR a.id_utilisateur = :lecteur)",
            ['id' => $id, 'lecteur' => $idLecteur ?? 0],
        );
        if ($l === null) {
            return null;
        }
        return [
            'id' => (int) $l['ID'], 'titre' => $l['TITRE'], 'description' => $l['DESCRIPTION'],
            'prix' => (float) $l['PRIX'], 'ville' => $l['VILLE'], 'statut' => $l['STATUT'],
            'id_categorie' => (int) $l['ID_CATEGORIE'], 'motif_refus' => $l['MOTIF_REFUS'],
            'date_publication' => $l['DATE_PUBLICATION'], 'date_expiration' => $l['DATE_EXPIRATION'],
            'id_auteur' => (int) $l['ID_UTILISATEUR'], 'auteur' => Produit::nomCourt($l['AUTEUR']),
            'membre_depuis' => $l['MEMBRE_DEPUIS'], 'en_favori' => (int) $l['EN_FAVORI'] > 0,
            'est_auteur' => $idLecteur !== null && (int) $l['ID_UTILISATEUR'] === $idLecteur,
            'photos' => array_map(static fn (array $p) => ['id' => (int) $p['ID'], 'chemin' => $p['CHEMIN']],
                $this->db->lignes('SELECT id, chemin FROM annonce_photo WHERE id_annonce = :id ORDER BY ordre', ['id' => $id])),
        ];
    }

    /** @return list<array<string, mixed>> */
    public function mesAnnonces(int $idUtilisateur): array
    {
        return array_map(static fn (array $l) => [
            'id' => (int) $l['ID'], 'titre' => $l['TITRE'], 'prix' => (float) $l['PRIX'], 'statut' => $l['STATUT'],
            'date_expiration' => $l['DATE_EXPIRATION'], 'photo' => $l['PHOTO'], 'nb_messages' => (int) $l['NB_CONVERSATIONS'],
        ], $this->db->lignes(
            'SELECT a.id, a.titre, a.prix, a.statut, a.date_expiration,
                    (SELECT MIN(ph.chemin) KEEP (DENSE_RANK FIRST ORDER BY ph.ordre) FROM annonce_photo ph WHERE ph.id_annonce = a.id) AS photo,
                    (SELECT COUNT(*) FROM conversation c WHERE c.id_annonce = a.id) AS nb_conversations
               FROM annonce a WHERE a.id_utilisateur = :u ORDER BY a.date_publication DESC',
            ['u' => $idUtilisateur]));
    }

    /** @return list<array<string, mixed>> */
    public function favoris(int $idUtilisateur): array
    {
        return array_map(static fn (array $l) => [
            'id' => (int) $l['ID'], 'titre' => $l['TITRE'], 'prix' => (float) $l['PRIX'], 'ville' => $l['VILLE'],
            'statut' => $l['STATUT'], 'photo' => $l['PHOTO'],
        ], $this->db->lignes(
            'SELECT a.id, a.titre, a.prix, a.ville, a.statut,
                    (SELECT MIN(ph.chemin) KEEP (DENSE_RANK FIRST ORDER BY ph.ordre) FROM annonce_photo ph WHERE ph.id_annonce = a.id) AS photo
               FROM favori f JOIN annonce a ON a.id = f.id_annonce
              WHERE f.id_utilisateur = :u ORDER BY f.date_ajout DESC',
            ['u' => $idUtilisateur]));
    }

    /** @param array{id_categorie: int, titre: string, description: string, prix: float, ville: string} $v */
    public function publier(int $idUtilisateur, array $v, ?int $scoreRisque = null): int
    {
        $p = ['u' => $idUtilisateur, 'cat' => $v['id_categorie'], 'titre' => $v['titre'], 'desc' => $v['description'],
              'prix' => $v['prix'], 'ville' => $v['ville'], 'score' => $scoreRisque, 'id' => null];
        $this->db->appeler('BEGIN pkg_annonce.publier(:u, :cat, :titre, :desc, :prix, :ville, :score, :id); END;', $p);
        return (int) $p['id'];
    }

    /** @param array{id_categorie: int, titre: string, description: string, prix: float, ville: string} $v */
    public function modifier(int $id, int $idUtilisateur, array $v, ?int $scoreRisque = null): void
    {
        $p = ['id' => $id, 'u' => $idUtilisateur, 'cat' => $v['id_categorie'], 'titre' => $v['titre'],
              'desc' => $v['description'], 'prix' => $v['prix'], 'ville' => $v['ville'], 'score' => $scoreRisque];
        $this->db->appeler('BEGIN pkg_annonce.modifier(:id, :u, :cat, :titre, :desc, :prix, :ville, :score); END;', $p);
    }

    public function statut(int $id): ?string
    {
        $statut = $this->db->valeur('SELECT statut FROM annonce WHERE id = :id', ['id' => $id]);
        return $statut === null ? null : (string) $statut;
    }

    /** $action : renouveler | marquer_vendue */
    public function action(string $action, int $id, int $idUtilisateur): void
    {
        $procedure = ['renouveler' => 'renouveler', 'vendue' => 'marquer_vendue'][$action] ?? null;
        if ($procedure === null) {
            throw new \InvalidArgumentException('Action inconnue : ' . $action);
        }
        $p = ['id' => $id, 'u' => $idUtilisateur];
        // Le nom de procédure vient d'une liste fermée ci-dessus, jamais de la requête
        $this->db->appeler("BEGIN pkg_annonce.$procedure(:id, :u); END;", $p);
    }

    public function basculerFavori(int $idUtilisateur, int $idAnnonce, bool $ajouter): void
    {
        $p = ['u' => $idUtilisateur, 'a' => $idAnnonce];
        $this->db->appeler($ajouter ? 'BEGIN pkg_annonce.ajouter_favori(:u, :a); END;'
                                    : 'BEGIN pkg_annonce.retirer_favori(:u, :a); END;', $p);
    }

    public function ajouterPhoto(int $id, int $idUtilisateur, string $chemin): void
    {
        $p = ['id' => $id, 'u' => $idUtilisateur, 'chemin' => $chemin, 'photo' => null];
        $this->db->appeler('BEGIN pkg_annonce.ajouter_photo(:id, :u, :chemin, :photo); END;', $p);
    }

    public function retirerPhoto(int $idPhoto, int $idUtilisateur): string
    {
        $p = ['photo' => $idPhoto, 'u' => $idUtilisateur, 'chemin' => null];
        $this->db->appeler('BEGIN pkg_annonce.retirer_photo(:photo, :u, :chemin); END;', $p);
        return (string) $p['chemin'];
    }

    public function signaler(int $idAuteur, int $idAnnonce, string $motif, string $commentaire): void
    {
        $p = ['u' => $idAuteur, 'a' => $idAnnonce, 'motif' => $motif, 'commentaire' => $commentaire, 'id' => null];
        $this->db->appeler("BEGIN pkg_moderation.signaler(:u, 'ANNONCE', :a, :motif, :commentaire, :id); END;", $p);
    }

    /**
     * Validation du formulaire d'annonce (fonction pure).
     *
     * @param array<string, string> $champs
     * @return array{0: array<string, mixed>, 1: array<string, string>}
     */
    public static function validerFormulaire(array $champs): array
    {
        $erreurs = [];
        $titre = $champs['titre'] ?? '';
        $description = $champs['description'] ?? '';
        $ville = $champs['ville'] ?? '';
        $prix = filter_var(str_replace([' ', "\u{00A0}", ','], ['', '', '.'], $champs['prix'] ?? ''), FILTER_VALIDATE_FLOAT);
        $categorie = filter_var($champs['id_categorie'] ?? '', FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        if (mb_strlen($titre) < 5 || mb_strlen($titre) > 150) {
            $erreurs['titre'] = 'Le titre doit faire entre 5 et 150 caractères.';
        }
        if (mb_strlen($description) < 10 || mb_strlen($description) > 4000) {
            $erreurs['description'] = 'Décrivez votre article (10 à 4000 caractères).';
        }
        if ($prix === false || $prix < 0 || $prix > 100_000_000 || round($prix, 2) != $prix) {
            $erreurs['prix'] = 'Prix invalide (0 pour un don).';
        }
        if (mb_strlen($ville) < 2 || mb_strlen($ville) > 60) {
            $erreurs['ville'] = 'Indiquez la ville.';
        }
        if ($categorie === false) {
            $erreurs['id_categorie'] = 'Choisissez une catégorie.';
        }
        return [['titre' => $titre, 'description' => $description, 'ville' => $ville,
                 'prix' => $prix === false ? 0.0 : (float) $prix, 'id_categorie' => $categorie === false ? 0 : $categorie], $erreurs];
    }
}
