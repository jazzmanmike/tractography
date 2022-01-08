#!/bin/bash
set -e

# make_freesurfer.sh
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#sort path to QA Tools

export QA_TOOLS=${HOME}/Dropbox/Github/code/QAtools_v1.2
export SUBJECTS_DIR=`pwd`

echo "QA Tools set up as ${QA_TOOLS}"
echo "QA Tools set up as ${QA_TOOLS}" >> ${log}
echo "SUBJECTS_DIR set up as ${SUBJECTS_DIR}"
echo "SUBJECTS_DIR set up as ${SUBJECTS_DIR}" >> ${log}

#run Freesurfer
#in parallel with 6 cores
recon-all -i ${structural} -s ${tempdir}/FS -all -parallel -openmp 6

#run QA tools
#NB: images don't always run with Linux/SLURM
${QA_TOOLS}/recon_checker -s ${tempdir}/FS

#additional parcellation for connectomics
#need to check template [ ] 
parcellation2individuals.sh
