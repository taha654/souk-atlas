<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Auth;
use App\Core\Controller;
use App\Core\Erreurs\ErreurMetier;
use App\Core\Erreurs\RouteIntrouvable;
use App\Core\Response;
use App\Core\Session;
use App\Models\Messagerie;

/**
 * Messagerie. La page fonctionne sans JavaScript (formulaire POST) ;
 * messagerie.js y ajoute l'envoi sans rechargement et le rafraîchissement
 * périodique (polling) via /api/messages/{id}.
 */
final class MessagerieController extends Controller
{
    public function index(): Response
    {
        $moi = Auth::exigerRole('CLIENT', 'VENDEUR');
        return $this->vue('messages/index', ['conversations' => (new Messagerie($this->db))->conversations($moi['id'])],
            'Mes messages');
    }

    public function conversation(string $id): Response
    {
        $moi = Auth::exigerRole('CLIENT', 'VENDEUR');
        $modele = new Messagerie($this->db);
        $conversation = $this->conversationDe($modele, $id, $moi['id']);
        $messages = $modele->messages($conversation['id'], $moi['id']);
        // Ouvrir la conversation = lire ses messages
        $modele->marquerLu($conversation['id'], $moi['id']);
        $this->db->valider();
        return $this->vue('messages/conversation', ['conversation' => $conversation, 'messages' => $messages],
            'Messages — ' . $conversation['titre']);
    }

    public function envoyer(string $id): Response
    {
        $moi = Auth::exigerRole('CLIENT', 'VENDEUR');
        $modele = new Messagerie($this->db);
        $conversation = $this->conversationDe($modele, $id, $moi['id']);
        try {
            $modele->envoyer($conversation['id'], $moi['id'], $this->request->champ('message'));
            $this->db->valider();
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            Session::flash('erreur', $erreur->getMessage());
        }
        return $this->rediriger('/messages/' . $conversation['id']);
    }

    // ------------------------------------------------------------------ API (messagerie.js)

    /** GET /api/messages/{id}?apres=42 : messages plus récents que l'id 42 */
    public function apiNouveaux(string $id): Response
    {
        $moi = Auth::exigerRole('CLIENT', 'VENDEUR');
        $modele = new Messagerie($this->db);
        $conversation = $this->conversationDe($modele, $id, $moi['id']);
        $apres = filter_var($this->request->parametre('apres'), FILTER_VALIDATE_INT, ['options' => ['min_range' => 0]]);
        $messages = $modele->messages($conversation['id'], $moi['id'], $apres === false ? 0 : $apres);
        if ($messages !== []) {
            $modele->marquerLu($conversation['id'], $moi['id']);
            $this->db->valider();
        }
        return Response::json(['messages' => array_map(self::versJson(...), $messages)]);
    }

    /** POST /api/messages/{id} (jeton CSRF en en-tête) */
    public function apiEnvoyer(string $id): Response
    {
        $moi = Auth::exigerRole('CLIENT', 'VENDEUR');
        $modele = new Messagerie($this->db);
        $conversation = $this->conversationDe($modele, $id, $moi['id']);
        try {
            $idMessage = $modele->envoyer($conversation['id'], $moi['id'], $this->request->champ('message'));
            $this->db->valider();
            return Response::json(['id' => $idMessage], 201);   // 201 Created
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            return Response::json(['erreur' => 'Message refusé', 'message' => $erreur->getMessage()], 422);
        }
    }

    /** @return array<string, mixed> conversation dont l'utilisateur est participant ; 404 sinon */
    private function conversationDe(Messagerie $modele, string $id, int $idUtilisateur): array
    {
        $idConversation = filter_var($id, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        $conversation = $idConversation === false ? null : $modele->conversation($idConversation, $idUtilisateur);
        if ($conversation === null) {
            throw new RouteIntrouvable('/messages/' . $id);
        }
        return $conversation;
    }

    /** @param array<string, mixed> $m @return array<string, mixed> */
    private static function versJson(array $m): array
    {
        return $m + ['date_texte' => date_fr($m['date'], true)];
    }
}
