#!/bin/bash
set -e

# make_freesurfer.sh
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#input: T1_biascorr (not brain extracted); FLAIR
#output: FS, QA, additional (500mm sequential symmetrical) parcellation (for MSN)

#need to set path
export SUBJECTS_DIR=`pwd`

echo "SUBJECTS_DIR set up as ${SUBJECTS_DIR}"
#echo "SUBJECTS_DIR set up as ${SUBJECTS_DIR}" >> ${log}

#run Freesurfer
#in parallel with 8 cores
recon-all -i $1 -s FS -all -FLAIR $2 -FLAIRpial -parallel -openmp 8

#run QA tools
qatools.py --subjects_dir=`pwd` --subjects=FS --output_dir=QA --screenshots --outlier

#additional parcellation for connectomics
#template: ${HOME}/Dropbox/Github/fslaverageSubP
#500.sym.aparc_seq
parcellation2individuals_sym.sh
