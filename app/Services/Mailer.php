<?php
declare(strict_types=1);

namespace App\Services;

/**
 * Envoi d'emails SIMULÉ : au lieu de partir sur Internet, chaque email est
 * écrit dans un fichier .eml (format standard d'un email) dans var/mails/.
 * Ouvrez-le avec un client mail (Thunderbird, Outlook…) ou un éditeur de texte.
 *
 * En production, seule cette classe changerait (envoi SMTP) : le reste du code
 * appelle envoyer() sans savoir comment l'email part.
 */
final class Mailer
{
    private const EXPEDITEUR = 'Souk Atlas <ne-pas-repondre@souk-atlas.test>';

    public function __construct(private readonly string $dossier)
    {
    }

    /** Renvoie le chemin du fichier écrit */
    public function envoyer(string $destinataire, string $sujet, string $texte): string
    {
        // Un saut de ligne dans un en-tête permettrait d'injecter d'autres
        // en-têtes (ex. "Bcc:") : on refuse toute adresse ou sujet multiligne
        if (preg_match('/[\r\n]/', $destinataire . $sujet) === 1
            || filter_var($destinataire, FILTER_VALIDATE_EMAIL) === false) {
            throw new \InvalidArgumentException('Destinataire ou sujet invalide');
        }

        $contenu = implode("\r\n", [
            'From: ' . self::EXPEDITEUR,
            'To: ' . $destinataire,
            // Un en-tête d'email doit être en ASCII : le sujet accentué est encodé (RFC 2047)
            'Subject: ' . mb_encode_mimeheader($sujet, 'UTF-8', 'B'),
            'Date: ' . date(DATE_RFC2822),
            'MIME-Version: 1.0',
            'Content-Type: text/plain; charset=UTF-8',
            'Content-Transfer-Encoding: 8bit',
            '',
            str_replace("\n", "\r\n", $texte),
        ]);

        if (!is_dir($this->dossier) && !mkdir($this->dossier, 0755, true) && !is_dir($this->dossier)) {
            throw new \RuntimeException('Dossier des emails impossible à créer : ' . $this->dossier);
        }
        // Nom unique et triable : date, puis partie aléatoire
        $fichier = $this->dossier . '/' . date('Ymd-His') . '-' . bin2hex(random_bytes(4)) . '.eml';
        if (file_put_contents($fichier, $contenu) === false) {
            throw new \RuntimeException('Écriture de l\'email impossible : ' . $fichier);
        }
        return $fichier;
    }
}
