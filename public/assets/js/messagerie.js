// =============================================================================
// Messagerie : envoi sans rechargement et réception par "polling".
//
// Polling : toutes les 5 secondes, on demande au serveur « y a-t-il des messages
// plus récents que le dernier que j'ai ? » (/api/messages/{id}?apres=ID).
// C'est la technique la plus simple pour du quasi temps réel, sans WebSocket.
// On s'arrête quand l'onglet est caché : inutile d'interroger le serveur pour
// une page que personne ne regarde.
// =============================================================================
import { getJson } from './api.js';

const fil = document.getElementById('fil-messages');
const formulaire = document.getElementById('formulaire-message');
const etat = document.getElementById('etat-message');
const idConversation = fil.dataset.conversation;
const jetonCsrf = document.querySelector('meta[name="csrf-token"]')?.content ?? '';
const INTERVALLE = 5000;
let minuterie = null;

function dernierId() {
    const derniers = fil.querySelectorAll('li[data-id]');
    return derniers.length ? Number(derniers[derniers.length - 1].dataset.id) : 0;
}

function ajouter(message) {
    if (fil.querySelector(`li[data-id="${message.id}"]`)) return;   // déjà affiché
    const li = document.createElement('li');
    li.className = 'message' + (message.moi ? ' message--moi' : '');
    li.dataset.id = String(message.id);
    const entete = document.createElement('p');
    entete.className = 'message__entete';
    entete.textContent = `${message.moi ? 'Moi' : message.expediteur} · ${message.date_texte}`;
    const contenu = document.createElement('p');
    contenu.className = 'message__contenu';
    contenu.textContent = message.contenu;   // textContent : un message contenant du HTML reste du texte
    li.append(entete, contenu);
    fil.append(li);
}

function defilerEnBas() {
    fil.lastElementChild?.scrollIntoView({ block: 'end' });
}

async function recevoir() {
    try {
        const { messages } = await getJson(`/api/messages/${idConversation}?apres=${dernierId()}`);
        messages.forEach(ajouter);
        if (messages.length) defilerEnBas();
    } catch {
        // Erreur réseau passagère : on réessaiera au prochain tour
    }
}

function demarrer() {
    if (minuterie === null) minuterie = setInterval(recevoir, INTERVALLE);
}
function arreter() {
    clearInterval(minuterie);
    minuterie = null;
}

document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
        arreter();
    } else {
        recevoir();   // rattrapage immédiat au retour sur l'onglet
        demarrer();
    }
});

formulaire.addEventListener('submit', async (evenement) => {
    evenement.preventDefault();
    const champ = formulaire.elements.message;
    if (!champ.value.trim()) return;
    const bouton = formulaire.querySelector('button[type="submit"]');
    bouton.disabled = true;
    try {
        const reponse = await fetch(`/api/messages/${idConversation}`, {
            method: 'POST',
            headers: { 'X-CSRF-Token': jetonCsrf, Accept: 'application/json' },
            body: new URLSearchParams({ message: champ.value }),
        });
        const donnees = await reponse.json();
        if (!reponse.ok) {
            etat.textContent = donnees.message ?? 'Envoi impossible.';
            return;
        }
        champ.value = '';
        etat.textContent = 'Message envoyé.';
        await recevoir();   // affiche aussitôt son propre message
    } finally {
        bouton.disabled = false;
        champ.focus();
    }
});

defilerEnBas();
demarrer();
