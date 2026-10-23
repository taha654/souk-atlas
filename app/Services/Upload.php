<?php
declare(strict_types=1);

namespace App\Services;

use App\Core\Erreurs\ErreurMetier;

/**
 * Réception des photos envoyées par les utilisateurs.
 *
 * Règles de sécurité :
 *  1. le TYPE RÉEL est lu dans le contenu du fichier (finfo), jamais dans son
 *     nom ni dans le type annoncé par le navigateur (tous deux falsifiables) ;
 *  2. taille limitée ;
 *  3. getimagesize vérifie qu'il s'agit vraiment d'une image décodable ;
 *  4. le fichier est RENOMMÉ au hasard, avec une extension déduite du type
 *     réel : "photo.php.jpg" ou "../../index.php" ne veulent plus rien dire ;
 *  5. le dossier uploads/ n'exécute jamais de PHP (configuration Apache).
 */
final class Upload
{
    public const TAILLE_MAX = 5 * 1024 * 1024;   // 5 Mo
    private const DIMENSION_MAX = 8000;           // pixels, en largeur comme en hauteur

    // Type réel → extension du fichier enregistré
    private const TYPES = [
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
    ];

    public function __construct(private readonly string $dossierPublic)
    {
    }

    /**
     * Enregistre une photo envoyée par formulaire ; renvoie son chemin public
     * ("/uploads/produits/3f9c…a1.jpg").
     *
     * @param array{tmp_name: string, error: int, size: int}|null $fichier
     */
    public function photo(?array $fichier, string $sousDossier): string
    {
        if ($fichier === null) {
            throw self::refus('Aucune photo reçue.');
        }
        $extension = self::verifier($fichier['tmp_name'], (int) $fichier['size'], $fichier['error']);
        // is_uploaded_file : le chemin vient bien d'un envoi HTTP (et pas, par
        // exemple, de /etc/passwd glissé dans la requête)
        if (!is_uploaded_file($fichier['tmp_name'])) {
            throw self::refus('Envoi de fichier invalide.');
        }

        $dossier = $this->dossierPublic . '/uploads/' . $sousDossier;
        if (!is_dir($dossier) && !mkdir($dossier, 0755, true) && !is_dir($dossier)) {
            throw new \RuntimeException('Dossier d\'envoi impossible à créer : ' . $dossier);
        }
        $nom = bin2hex(random_bytes(16)) . '.' . $extension;
        if (!move_uploaded_file($fichier['tmp_name'], $dossier . '/' . $nom)) {
            throw new \RuntimeException('Déplacement du fichier envoyé impossible');
        }
        return '/uploads/' . $sousDossier . '/' . $nom;
    }

    /**
     * Contrôles sur le fichier temporaire (fonction pure : testable sans vrai envoi).
     * Renvoie l'extension à utiliser.
     */
    public static function verifier(string $chemin, int $taille, int $codeErreur): string
    {
        if ($codeErreur === UPLOAD_ERR_INI_SIZE || $codeErreur === UPLOAD_ERR_FORM_SIZE || $taille > self::TAILLE_MAX) {
            throw self::refus('Photo trop lourde : 5 Mo au maximum.');
        }
        if ($codeErreur === UPLOAD_ERR_NO_FILE) {
            throw self::refus('Aucune photo choisie.');
        }
        if ($codeErreur !== UPLOAD_ERR_OK || $taille === 0 || !is_file($chemin)) {
            throw self::refus('L\'envoi de la photo a échoué. Réessayez.');
        }

        $type = (new \finfo(FILEINFO_MIME_TYPE))->file($chemin);
        if (!isset(self::TYPES[$type])) {
            throw self::refus('Format refusé : seules les photos JPEG, PNG et WebP sont acceptées.');
        }
        $dimensions = @getimagesize($chemin);
        if ($dimensions === false || $dimensions[0] < 1 || $dimensions[1] < 1
            || $dimensions[0] > self::DIMENSION_MAX || $dimensions[1] > self::DIMENSION_MAX) {
            throw self::refus('Image illisible ou trop grande (8000 pixels au maximum).');
        }
        return self::TYPES[$type];
    }

    /** Supprime un fichier envoyé ; ignore tout chemin hors de uploads/ */
    public function supprimer(string $cheminPublic): void
    {
        // Seuls les chemins "/uploads/<dossier>/<nom aléatoire>.<ext>" sont acceptés :
        // impossible de remonter dans l'arborescence avec "../"
        if (preg_match('#^/uploads/[a-z]+/[0-9a-f]{32}\.(jpg|png|webp)$#', $cheminPublic) !== 1) {
            return;
        }
        $fichier = $this->dossierPublic . $cheminPublic;
        if (is_file($fichier)) {
            unlink($fichier);
        }
    }

    private static function refus(string $message): ErreurMetier
    {
        return new ErreurMetier(ErreurMetier::DONNEE_INVALIDE, $message);
    }
}
