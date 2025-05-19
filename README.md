# LNSP-ONT Pipeline

Ce pipeline automatise l'analyse de données de séquençage Nanopore (ONT) pour le génome complet de Mpox, incluant le contrôle qualité, le trimming, le filtrage, l'alignement, la génération de consensus, et l'annotation avec Nextclade.

## Structure du pipeline

1. **NanoPlot** – Contrôle qualité des reads bruts 
2. **Porechop** – Suppression des adaptateurs
3. **Filtlong** – Filtrage des reads par qualité/longueur
4. **Minimap2 + Samtools** – Alignement au génome de référence 
5. **Medaka** – Génération du consensus 
6. **Nextclade** – Annotation et analyse de la séquence consensus

## Dépendances

Installe les outils suivants dans ton environnement (`conda`, `apt`, ou `docker`) :

- NanoPlot
- Porechop
- Filtlong
- Minimap2
- Samtools
- Medaka
- Nextclade CLI

## Création d'un environnement pipeline-ONT pour éviter tout type de conflis 

conda create -n pipeline-ONT

conda activate pipeline-ONT

conda env create -f pipeline-ONT.yml

## Utilisation
Exécuter le script dans votre dossier d'analyses cotenant le script. Vous pouvez rendre ce script exécutable


```bash
bash Pipeline_LNSP-ONT.sh
```


> Modifie les variables `RAW_FASTQ`, `REF_GENOME`, `OUTDIR`, et `THREADS` au début du script selon ton environnement.

## Résultats

Le script génère automatiquement :
- des rapports qualités,
- un fichier consensus,
- un rapport Nextclade si la qualité est suffisante.

## Auteur

Dachel EYENET/Laboratoire National de Santé Publique (LNSP)

---

## Licence

MIT – libre d'utilisation avec citation.
