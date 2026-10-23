<?php
/** @var array<string, mixed> $achat */
/** @var array<string, mixed> $client */
?>
<main class="facture">
    <p class="ecran-seulement">
        <a href="/achat/<?= e(rawurlencode($achat['reference'])) ?>">← Retour à l'achat</a>
        · Pour obtenir un PDF : menu du navigateur, <strong>Imprimer</strong>, puis « Enregistrer au format PDF ».
    </p>

    <header class="facture__entete">
        <div>
            <p class="facture__logo">Souk Atlas</p>
            <p>Place de marché en ligne<br>Document de démonstration, sans valeur fiscale</p>
        </div>
        <div class="facture__references">
            <h1>Facture</h1>
            <p>Achat <strong><?= e($achat['reference']) ?></strong><br>
                Date : <?= e(date_fr($achat['date'])) ?></p>
        </div>
    </header>

    <section class="facture__client">
        <h2>Client</h2>
        <p><?= e($client['NOM']) ?><br><?= e($client['EMAIL']) ?><br>
            Livraison : <?= e($achat['adresse']) ?>, <?= e($achat['ville']) ?></p>
    </section>

    <?php /* Une section par commande : chaque boutique est un vendeur distinct */ ?>
    <?php foreach ($achat['commandes'] as $c): ?>
        <section class="facture__commande">
            <h2>Commande <?= e($c['numero']) ?> — vendeur : <?= e($c['boutique']) ?> (<?= e($c['ville_boutique']) ?>)</h2>
            <table>
                <thead>
                    <tr><th scope="col">Désignation</th><th scope="col">Qté</th>
                        <th scope="col">Prix unitaire HT</th><th scope="col">Total HT</th></tr>
                </thead>
                <tbody>
                    <?php foreach ($c['lignes'] as $l): ?>
                        <tr>
                            <td><?= e($l['nom']) ?></td>
                            <td class="nombre"><?= e($l['quantite']) ?></td>
                            <td class="nombre"><?= e(format_prix($l['prix_unitaire_ht'])) ?></td>
                            <td class="nombre"><?= e(format_prix($l['total_ligne_ht'])) ?></td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
                <tfoot>
                    <tr><th scope="row" colspan="3">Total HT</th><td class="nombre"><?= e(format_prix($c['total_ht'])) ?></td></tr>
                    <tr><th scope="row" colspan="3">TVA 20 %</th><td class="nombre"><?= e(format_prix($c['tva'])) ?></td></tr>
                    <tr><th scope="row" colspan="3">Total TTC</th><td class="nombre"><strong><?= e(format_prix($c['total_ttc'])) ?></strong></td></tr>
                </tfoot>
            </table>
        </section>
    <?php endforeach; ?>

    <section class="facture__total">
        <p>Total HT : <?= e(format_prix($achat['total_ht'])) ?> · TVA : <?= e(format_prix($achat['tva'])) ?></p>
        <p class="facture__ttc">Total TTC : <?= e(format_prix($achat['total_ttc'])) ?></p>
        <p>Paiement : <?= $achat['mode_paiement'] === 'CARTE'
            ? 'carte bancaire **** ' . e($achat['carte_4_derniers']) . ' (simulé)'
            : 'à la livraison' ?></p>
    </section>
</main>
