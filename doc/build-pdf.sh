#!/usr/bin/env bash
# Génère doc/DUAL-MODE.pdf depuis DUAL-MODE.md avec les schémas SVG en VECTORIEL.
#
# Dépendances (macOS / Homebrew) :
#   brew install pandoc librsvg            # pandoc + rsvg-convert (SVG -> PDF vectoriel)
#   + une distribution LaTeX fournissant xelatex (ex. MacTeX / BasicTeX)
#   + la police "Arial Unicode MS" (présente par défaut sur macOS ; couvre les flèches → ↔ ⇒)
#
# Usage : bash doc/build-pdf.sh
set -euo pipefail
cd "$(dirname "$0")"            # -> dossier doc/
DOC="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Référence les SVG en chemin absolu + largeur page, et remplace les emojis
# (non couverts par les polices PDF) par du texte. perl -CSD gère l'UTF-8 et
# supprime les sélecteurs de variation (U+FE0F) qui traînent après les emojis.
perl -CSD -pe "s#\]\(([^)]+\.svg)\)#](${DOC}/\1){width=16cm}#g; s/\x{2699}\x{FE0F}?/(à calibrer)/g; s/\x{26A0}\x{FE0F}?/!/g; s/\x{FE0F}//g" \
    DUAL-MODE.md > "$TMP/doc.md"

pandoc "$TMP/doc.md" -o DUAL-MODE.pdf \
    --pdf-engine=xelatex \
    -V geometry:margin=2cm \
    -V mainfont="Arial Unicode MS" \
    -V colorlinks=true \
    --metadata title="D12 — Contrôle double-mode PAC / Arrosage"

echo "OK : $DOC/DUAL-MODE.pdf"
