#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

# === Paramètres utilisateur ===
RAW_FASTQ="/home/lnsp/Bureau/test2/sample7.fastq"             # Chemin vers tes lectures ONT
REF_GENOME="/home/lnsp/Bureau/test2/Reference_mpox.fasta"     # Référence génomique
OUTDIR="ONT_pipeline_output"
THREADS=8                                                                # Nombre de threads

# === Fonctions de log ===
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# === Vérification des outils ===
for cmd in NanoPlot filtlong minimap2 samtools medaka_consensus nextclade porechop; do
    if ! command -v $cmd &> /dev/null; then
        log "ERREUR: La commande '$cmd' est introuvable dans le PATH."
        exit 1
    fi
done

# === Vérification des fichiers ===
if [[ ! -f "$RAW_FASTQ" ]]; then
    log "ERREUR: Fichier FASTQ introuvable : $RAW_FASTQ"
    exit 1
fi

if [[ ! -f "$REF_GENOME" ]]; then
    log "ERREUR: Fichier de référence introuvable : $REF_GENOME"
    exit 1
fi

log "Début du pipeline ONT"

# === Création des dossiers ===
mkdir -p ${OUTDIR}/{quality,trimmed,filtered,alignment,consensus,nextclade_ready,nextclade_results}

# === Étape 1 : Contrôle qualité avec NanoPlot ===
log "Étape 1 : Exécution de NanoPlot"
NanoPlot --fastq ${RAW_FASTQ} --outdir ${OUTDIR}/quality --threads ${THREADS} || {
    log "ERREUR lors de NanoPlot"
    exit 1
}

# === Étape 1.5 : Suppression automatique des adaptateurs avec Porechop ===
log "Étape 1.5 : Suppression automatique des adaptateurs avec Porechop"

porechop \
    -i ${RAW_FASTQ} \
    -o ${OUTDIR}/trimmed/trimmed.fastq \
    --verbosity 2 \
    --threads ${THREADS} || {
    log "ERREUR lors de Porechop"
    exit 1
}

# === Étape 2 : Filtrage avec filtlong ===
log "Étape 2 : Filtrage des lectures avec filtlong"
filtlong --min_length 1500 --min_mean_q 10 --keep_percent 80 ${OUTDIR}/trimmed/trimmed.fastq > ${OUTDIR}/filtered/filtered_reads.fastq || {
    log "ERREUR lors de filtlong"
    exit 1
}

# === Étape 3 : Alignement avec minimap2 + samtools ===
log "Étape 3 : Alignement avec minimap2"
minimap2 -ax map-ont -t ${THREADS} ${REF_GENOME} ${OUTDIR}/filtered/filtered_reads.fastq | \
samtools sort -@ ${THREADS} -o ${OUTDIR}/alignment/aligned_reads.bam || {
    log "ERREUR lors de l'alignement minimap2 + samtools"
    exit 1
}

samtools index ${OUTDIR}/alignment/aligned_reads.bam

# === Étape 4 : Génération du consensus avec Medaka ===
log "Étape 4 : Génération du consensus avec Medaka"
medaka_consensus -i ${OUTDIR}/filtered/filtered_reads.fastq \
                 -d ${REF_GENOME} \
                 -o ${OUTDIR}/consensus \
                 -t ${THREADS} || {
    log "ERREUR lors de Medaka"
    exit 1
}

# === Étape 5 : Contrôle qualité du consensus ===
CONSENSUS_FASTA="${OUTDIR}/consensus/consensus.fasta"
QC_REPORT="${OUTDIR}/consensus/consensus_QC.txt"

if [[ ! -f "$CONSENSUS_FASTA" ]]; then
    log "ERREUR: Fichier consensus.fasta introuvable après Medaka."
    exit 1
fi

log "Vérification de la qualité du consensus"
TOTAL_BASES=$(grep -v "^>" "$CONSENSUS_FASTA" | tr -d '\n' | wc -c)
N_COUNT=$(grep -v "^>" "$CONSENSUS_FASTA" | tr -d '\n' | grep -o "N" | wc -l)
N_PERCENT=$(awk "BEGIN {printf \"%.2f\", ($N_COUNT/$TOTAL_BASES)*100}")

echo "=== Rapport Qualité Consensus ===" > "$QC_REPORT"
echo "Fichier : $CONSENSUS_FASTA" >> "$QC_REPORT"
echo "Longueur totale : $TOTAL_BASES bases" >> "$QC_REPORT"
echo "Nombre de bases N : $N_COUNT" >> "$QC_REPORT"
echo "Pourcentage de N : $N_PERCENT%" >> "$QC_REPORT"

# Décision qualité + export vers Nextclade
if (( $(echo "$N_PERCENT > 5.0" | bc -l) )); then
    log "ATTENTION: $N_PERCENT% de N — qualité faible. Analyse Nextclade annulée."
else
    log "Consensus valide : $N_PERCENT% de N. Export vers Nextclade prêt."
    cp "$CONSENSUS_FASTA" "${OUTDIR}/nextclade_ready/"

    # === Étape 6 : Envoi automatique vers Nextclade CLI ===
    log "Lancement de Nextclade sur le consensus validé."
    nextclade run \
        --input-fasta "$CONSENSUS_FASTA" \
        --output-tsv "${OUTDIR}/nextclade_results/results.tsv" \
        --output-json "${OUTDIR}/nextclade_results/results.json" \
        --output-dir "${OUTDIR}/nextclade_results" || {
            log "ERREUR : L'analyse Nextclade a échoué."
            exit 1
        }

    log "✅ Analyse Nextclade terminée. Résultats dans : ${OUTDIR}/nextclade_results"
fi

log "✅ Pipeline complet terminé !"
echo -e "\a"  # petite notification sonore

