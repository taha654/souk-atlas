<?php
declare(strict_types=1);

namespace App\Services;

/**
 * Appel du moteur C++ (cpp/engine, exécutable souk-moteur).
 *
 * Protocole : PHP écrit UNE requête JSON sur l'entrée standard du processus,
 * le moteur répond UNE ligne JSON sur sa sortie standard, et son code de
 * sortie dit si tout s'est bien passé (0) ou non (2 : requête invalide,
 * 3 : erreur interne).
 *
 * Pourquoi proc_open plutôt que shell_exec ou exec :
 *  - la commande est passée sous forme de TABLEAU : aucun shell n'est lancé,
 *    donc aucune injection de commande possible ;
 *  - on dispose de trois "tuyaux" (stdin, stdout, stderr) : pas besoin de
 *    passer les données dans la ligne de commande ou un fichier temporaire ;
 *  - on peut surveiller le temps et tuer le processus s'il dépasse le délai.
 */
final class CppEngine
{
    public function __construct(
        private readonly string $executable,
        private readonly float $delaiSecondes = 3.0,
    ) {
    }

    /**
     * @param array<string, mixed> $requete  doit contenir "action"
     * @return array<string, mixed>          réponse du moteur ("ok" vaut true)
     * @throws ErreurMoteur
     */
    public function executer(array $requete): array
    {
        if (!is_file($this->executable) || !is_executable($this->executable)) {
            throw new ErreurMoteur('Moteur C++ introuvable : ' . $this->executable);
        }
        $entree = json_encode($requete, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);

        $processus = proc_open([$this->executable], [
            0 => ['pipe', 'r'],   // stdin  : le moteur lit, PHP écrit
            1 => ['pipe', 'w'],   // stdout : le moteur écrit, PHP lit
            2 => ['pipe', 'w'],   // stderr : messages de diagnostic éventuels
        ], $tuyaux);
        if (!is_resource($processus)) {
            throw new ErreurMoteur('Lancement du moteur C++ impossible');
        }

        // Le moteur lit TOUTE son entrée avant de répondre : on écrit, puis on
        // ferme stdin pour lui signaler la fin des données
        fwrite($tuyaux[0], $entree);
        fclose($tuyaux[0]);

        [$sortie, $erreurs, $termine] = $this->lireAvecDelai($tuyaux[1], $tuyaux[2]);
        fclose($tuyaux[1]);
        fclose($tuyaux[2]);
        if (!$termine) {
            proc_terminate($processus, 9);   // SIGKILL : il ne répond plus, on l'arrête net
            proc_close($processus);
            throw new ErreurMoteur(sprintf('Moteur C++ trop lent (plus de %.1f s)', $this->delaiSecondes));
        }
        $code = proc_close($processus);

        $reponse = json_decode($sortie, true);
        if (!is_array($reponse)) {
            throw new ErreurMoteur("Réponse illisible du moteur C++ (code $code) : " . mb_substr($sortie . $erreurs, 0, 200));
        }
        if ($code !== 0 || ($reponse['ok'] ?? false) !== true) {
            throw new ErreurMoteur("Le moteur C++ a refusé la requête (code $code) : " . ($reponse['erreur'] ?? '?'));
        }
        return $reponse;
    }

    /**
     * Lit stdout et stderr jusqu'à leur fermeture (fin du processus) ou jusqu'au délai.
     * stream_select attend qu'un des tuyaux ait des données, sans bloquer au-delà
     * du temps restant (une lecture simple pourrait attendre indéfiniment).
     *
     * @param resource $stdout
     * @param resource $stderr
     * @return array{0: string, 1: string, 2: bool}  sortie, erreurs, terminé à temps ?
     */
    private function lireAvecDelai($stdout, $stderr): array
    {
        $textes = [(int) $stdout => '', (int) $stderr => ''];
        $ouverts = [$stdout, $stderr];
        stream_set_blocking($stdout, false);
        stream_set_blocking($stderr, false);
        $limite = microtime(true) + $this->delaiSecondes;

        while ($ouverts !== []) {
            $restant = $limite - microtime(true);
            if ($restant <= 0) {
                return [$textes[(int) $stdout], $textes[(int) $stderr], false];
            }
            $lecture = $ouverts;
            $ecriture = $exception = null;
            $secondes = (int) $restant;
            if (stream_select($lecture, $ecriture, $exception, $secondes, (int) (($restant - $secondes) * 1e6)) === false) {
                break;
            }
            foreach ($lecture as $tuyau) {
                $morceau = fread($tuyau, 65536);
                if ($morceau === '' || $morceau === false) {
                    if (feof($tuyau)) {
                        $ouverts = array_values(array_filter($ouverts, static fn ($t) => $t !== $tuyau));
                    }
                    continue;
                }
                $textes[(int) $tuyau] .= $morceau;
            }
        }
        return [$textes[(int) $stdout], $textes[(int) $stderr], true];
    }
}
