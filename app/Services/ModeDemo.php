<?php
declare(strict_types=1);

namespace App\Services;

use App\Core\Config;
use App\Core\Database;
use App\Core\Erreurs\ErreurMetier;

/**
 * Mode démonstration (DEMO_MODE=1) : le site est public et les comptes de démo
 * (mot de passe connu de tous) sont partagés par tous les visiteurs.
 *
 * On empêche donc ce qui gâcherait la visite des suivants avant la
 * réinitialisation de la nuit : désactiver ou rétrograder des comptes, toucher
 * à l'arbre des catégories, remplir le disque de photos.
 * Ces contrôles sont faits CÔTÉ SERVEUR : masquer un bouton ne suffirait pas.
 */
final class ModeDemo
{
    public const MESSAGE_REFUS = 'Action désactivée sur le site de démonstration.';

    public static function actif(): bool
    {
        return Config::get('demo')['actif'];
    }

    /** Taille maximale d'une photo, en octets (plus basse en démonstration) */
    public static function tailleMaxPhoto(): int
    {
        return self::actif() ? Config::get('demo')['photo_taille_max_mo'] * 1024 * 1024 : Upload::TAILLE_MAX;
    }

    /**
     * Avant d'enregistrer une photo : refuse si le compte, ou le site entier,
     * a atteint son quota. Ne fait rien hors du mode démonstration.
     *
     * @throws ErreurMetier quota atteint
     */
    public static function verifierQuotaPhotos(Database $db, int $idUtilisateur, string $dossierPublic): void
    {
        if (!self::actif()) {
            return;
        }
        $config = Config::get('demo');

        // Photos envoyées par ce compte : annonces dont il est l'auteur et
        // produits de sa boutique. Les photos de démo (/images/demo/…) ne comptent pas.
        $nbCompte = (int) $db->valeur(
            "SELECT (SELECT COUNT(*) FROM annonce_photo ap JOIN annonce a ON a.id = ap.id_annonce
                      WHERE a.id_utilisateur = :id AND ap.chemin LIKE '/uploads/%')
                  + (SELECT COUNT(*) FROM produit_photo pp JOIN produit p ON p.id = pp.id_produit
                      JOIN boutique b ON b.id = p.id_boutique
                      WHERE b.id_vendeur = :id AND pp.chemin LIKE '/uploads/%')
               FROM dual",
            ['id' => $idUtilisateur],
        );
        if ($nbCompte >= $config['photos_par_compte']) {
            throw new ErreurMetier(ErreurMetier::DONNEE_INVALIDE, sprintf(
                'Site de démonstration : %d photos par compte au maximum. Supprimez-en une pour en ajouter une autre.',
                $config['photos_par_compte'],
            ));
        }

        // Tous comptes confondus : on compte les fichiers sur le disque
        $fichiers = glob($dossierPublic . '/uploads/*/*') ?: [];
        if (count($fichiers) >= $config['photos_au_total']) {
            throw new ErreurMetier(ErreurMetier::DONNEE_INVALIDE,
                'Site de démonstration : la limite de photos du jour est atteinte. Réessayez demain.');
        }
    }
}
