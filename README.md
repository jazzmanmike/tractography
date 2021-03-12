# tractography
 Code for processing diffusion imaging and doing tractography
 
 Pipeline
 1.  Baseline quality control
 2.  FSL_anat*
 3.  Freesurfer*
 4.  De-noising with topup & eddy - optional (see code)
 5.  FDT pipeline
 6.  BedPostX*
 7.  Registration
 8.  XTRACT / Tractography
 9.  Segmentation (probtrackx2)
10.  Connectomics (probtrackx2)*

Set up:
- Download the code from the github link above and add it to your path e.g. bash_profile. 
- Next there is some standard and freely available neuroimaging software that needs to be installed, plus Matlab if you want to run connectomics. 
- Finally, you need to set the path to codedir in tract_van.sh, and that's it.

Runs a variety of analyses of relevance to deep brain stimulation (DBS) surgery, including specific tracts of interest, segmentation of various
subcortical nuclei, and whole brain connectomics. 

For connectomics run it with the corresponding connectome_tractography toolbox on my Github.
