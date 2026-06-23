# D12 — Manuel à jour (OCR des sections fournies)

> Transcription nettoyée des quatre pages du manuel papier (plus récent) fourni le
> 21/06/2026, source `uploads/D12 Manual (update).pdf`. Ce manuel fait foi sur les
> écarts avec le PDF d'origine. Les valeurs « usine » et plages sont reproduites
> telles que lisibles ; en cas de doute, se reporter au scan. Les différences les
> plus importantes avec l'ancien manuel sont signalées par **⚠**.

## Groupe P0 — Paramètres de base

| Code | Nom | Contenu | Plage | Usine |
|------|-----|---------|-------|-------|
| P0.00 | Spécification puissance | Affiche la puissance | 0.10~89.99 kW | selon appareil |
| P0.01 | Version logicielle | Affiche la version | 1.00~99.99 | 1.00 |
| P0.02 | Canal de commande de marche | 0 : panneau ; 1 : bornes ; 2 : communication | 0~2 | 0 |
| P0.03 | Sélection de la consigne de fréquence | voir détail ci-dessous | 0~8 | 0 |
| P0.04 | Fréquence de sortie maximale | référence pour accél./décél. | MAX{50.0,[P0.05]}~999.9 Hz | 50.0 Hz |
| P0.05 | Fréquence limite haute | la fréquence ne peut dépasser | MAX{0.1,[P0.06]}~[P0.04] | 50.0 Hz |
| P0.06 | Fréquence limite basse | la fréquence ne peut être inférieure | 0.0~limite haute | 0.0 Hz |
| P0.07 | Traitement à la limite basse | 0 : vitesse nulle ; 1 : tourne à la limite basse ; 2 : arrêt | 0~2 | 0 |
| P0.08 | Valeur initiale de la fréquence numérique | consigne numérique | 0.0~limite haute | 10.0 Hz |
| P0.09 | Contrôle de la fréquence numérique | code 4 digits, voir détail | 0000~2444 | 0000 |

### Détail P0.03 — Sélection de la consigne de fréquence (plage 0~8, usine 0)

0 : potentiomètre du panneau
1 : consigne numérique 1, réglage par les touches ▲/▼ du panneau
2 : consigne numérique 2, réglage par les bornes UP/DOWN
3 : **AVI, donnée analogique (0~10 V / 0~20 mA)** ⚠ — l'entrée AVI accepte désormais aussi le courant
4 : donnée combinée (mode choisi en P1.15)
5 : **Réservé** ⚠ — l'ancienne option « ACI » n'est plus disponible ici
6 : donnée par communication
7 : Réservé
8 : donnée MPPT

### Détail P0.09 — Contrôle de la fréquence numérique (4 digits)

Digit des unités : mémorisation à la coupure (0 : mémorise ; 1 : ne mémorise pas)
Digit des dizaines : maintien d'état à l'arrêt (0 : maintient ; 1 : ne maintient pas)
Digit des centaines : réglage UP/DOWN en négatif (0 : invalide ; 1 : valide)
Digit des milliers : **superposition de fréquence PID et PLC** ⚠
  - 0 : invalide
  - 1 : **P0.03 + PID** (c'est ce digit qui fait piloter la fréquence par le PID)
  - 2 : P0.03 + PLC

## Groupe P2 — Filtres des entrées logiques (extrait fourni)

| Code | Nom | Plage | Usine |
|------|-----|-------|-------|
| P2.30 | Coefficient de filtre X1 | 0~9999 | — |
| P2.31 | Coefficient de filtre X2 | 0~9999 | — |
| P2.32 | Coefficient de filtre X3 | 0~9999 | — |
| P2.33 | Coefficient de filtre X4 | 0~9999 | — |
| P2.34 | Coefficient de filtre X5 | 0~9999 | — |

Ces paramètres règlent la sensibilité des bornes d'entrée. Augmenter la valeur
renforce l'immunité au bruit, mais une valeur trop élevée réduit la sensibilité.
Unité : 1 = 2 ms de temps de scrutation.

## Groupe P3 — Paramètres PID

| Code | Nom | Plage | Usine |
|------|-----|-------|-------|
| P3.00 | Réglage de la fonction PID (code 4 digits) | 0000~2122 | 1010 |
| P3.01 | Valeur de consigne | 0.0~100.0 % | 0.00 % |
| P3.02 | Gain du canal de retour | 0.01~10.00 | 1.00 |
| P3.03 | Gain proportionnel P | 0.01~5.00 | 2.00 |
| P3.04 | Temps d'intégration Ti | 0.1~50.0 s | 1.0 s |
| P3.05 | Temps de dérivation Td | 0.1~10.0 s | 0.0 s |
| P3.06 | Période d'échantillonnage T | 0.1~10.0 s | 0.0 s |
| P3.07 | Limite de déviation | 0.0~20.0 % | 0.0 % |
| P3.08 | Fréquence de préréglage en boucle fermée | 0.0~limite haute | 0.0 Hz |
| P3.09 | Temps de maintien de la fréquence de préréglage | 0.0~999.9 s | 0.0 s |
| P3.10 | Seuil de réveil (coefficient) | 0.0~150.0 % | 100.0 % |
| P3.11 | Seuil d'éveil | 0.0~150.0 % | 90.0 % |
| P3.12 | Temps de temporisation de veille | 0.0~999.9 s | 100.0 s |
| P3.13 | Temps de temporisation d'éveil | 0.0~999.9 s | 1.0 s |
| P3.14 | Différence retour/consigne à l'entrée en veille | 0.0~10.0 % | 0.5 % |
| P3.15 | Temps de temporisation détection d'éclatement | 0.0~130.0 s | 0.0 s |
| P3.16 | Seuil haut de pression (défaut « EPA0 ») | 0.0~200.0 % | 150.0 % |
| P3.17 | Seuil bas de pression (défaut « EPA0 ») | 0.0~200.0 % | 50.0 % |
| P3.18 | Plage du capteur (MPa/Kg) | 0.00~99.99 | 10.00 MPa |

### Détail P3.00 — Réglage de la fonction PID (4 digits, usine 1010)

Digit des unités : caractéristique de régulation PID
  - 0 : invalide
  - 1 : **action positive** — si le retour est supérieur à la consigne, la fréquence de sortie doit diminuer (cas du maintien de pression)
  - 2 : action négative — comportement inverse

Digit des dizaines : canal de la consigne PID
  - 0 : potentiomètre clavier
  - 1 : consigne numérique (fixée par P3.01)
  - 2 : **consigne en pression (MPa, Kg)** — fixée par P3.01 et P3.18 (unité cohérente avec P3.18)

Digit des centaines : canal de retour PID
  - 0 : **AVI (0~10 V / 0~20 mA)** ⚠
  - 1 : **Réservé** ⚠ — l'ancien retour « ACI » n'est plus disponible ici

Digit des milliers : option de veille (sleep)
  - 0 : invalide
  - 1 : veille normale (nécessite P3.10~P3.13)
  - 2 : veille avec perturbation (paramètre P3.14)

### Protections de pression P3.16 / P3.17 (défaut « EPA0 »)

Lorsque la pression de retour est supérieure ou égale au seuil haut P3.16, le défaut
d'éclatement de tube « EPA0 » est signalé après la temporisation P3.15 ; il se
réarme automatiquement lorsque la pression repasse sous ce seuil. De même, lorsque
la pression de retour est inférieure ou égale au seuil bas P3.17, le défaut « EPA0 »
est signalé après P3.15 (utile en détection de manque d'eau / marche à sec), avec
réarmement automatique au retour au-dessus du seuil. Les seuils sont exprimés en
pourcentage de la plage capteur P3.18.

## Groupe P4 — Paramètres avancés (extrait fourni)

| Code | Nom | Plage | Usine |
|------|-----|-------|-------|
| P4.00 | Tension nominale moteur | 0~500 V (ou 0~250 V) | 380 V / 220 V selon appareil |
| P4.01 | Courant nominal moteur | 0.1~999 A | selon appareil |
| P4.02 | Vitesse nominale moteur | 0~60000 tr/min | selon appareil |
| P4.03 | Fréquence nominale moteur | 1.0~999.9 Hz | 50.0 Hz |
| P4.04 | Résistance statorique moteur | 0.001~20.000 Ω | selon appareil |
| P4.05 | Courant à vide moteur | 0.1~[P4.01] | selon appareil |
| P4.06 | Fonction AVR | 0 : invalide ; 1 : valide en permanence ; 2 : invalide en décélération | 0~2 | 0 |
| P4.07 | Commande du ventilateur | 0 : automatique ; 1 : marche permanente après mise sous tension | 0~1 | 0 |
| P4.08 | Nombre de réarmements automatiques | 0 : réarmement manuel seul ; 10 : illimité | 0~… | 0 |
| P4.09 | Intervalle de réarmement automatique | 0.5~25.0 s | 3.0 s |
| P4.10 | Tension de démarrage du freinage par dissipation | … | 385 V / 720 V |

---

*Référence interne. En cas d'écart, le scan d'origine prévaut sur cette transcription.*
