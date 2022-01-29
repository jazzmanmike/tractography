#!/bin/bash

#  make_segmentation.sh ${segmentation}
#
#  Default atlases include:
#  Desikan-Killiany (individual segmentation, from FreeSurfer): cluster based segmentation, thalamus only
#  Yeo7: hard segmentation, thalamus & pallidum
#  Kmeans: cortex mask only
#
#  Can also run with custom atlas individually
#
# Michael Hart, St George's University of London, January 2022 (c)


#######

#Set up

#######


#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard

segmentation=$1


if [[ ! -d segmentation ]] ;
then

    mkdir -pv segmentation

    #Move individual nucleus (seed) to be segmentated to standard space (i.e. same as target parcellation / atlas)
    applywarp --in=first_segmentation/first-R_Thal_corr.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=bpx.bedpostX/xfms/str2standard_warp --out=segmentation/thalamus_right_MNI.nii.gz
    fslmaths segmentation/thalamus_right_MNI.nii.gz -bin segmentation/thalamus_right_MNI.nii.gz

    applywarp --in=first_segmentation/first-L_Thal_corr.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=bpx.bedpostX/xfms/str2standard_warp --out=segmentation/thalamus_left_MNI.nii.gz
    fslmaths segmentation/thalamus_left_MNI.nii.gz -bin segmentation/thalamus_left_MNI.nii.gz

    applywarp --in=first_segmentation/first-R_Pall_corr.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=bpx.bedpostX/xfms/str2standard_warp --out=segmentation/pallidum_right_MNI.nii.gz
    fslmaths segmentation/pallidum_right_MNI.nii.gz -bin segmentation/pallidum_right_MNI.nii.gz

    applywarp --in=first_segmentation/first-L_Pall_corr.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=bpx.bedpostX/xfms/str2standard_warp --out=segmentation/pallidum_left_MNI.nii.gz
    fslmaths segmentation/pallidum_left_MNI.nii.gz -bin segmentation/pallidum_left_MNI.nii.gz

fi


################################

#1. Specified segmentation atlas

################################


if [ $(imtest ${segmentation}) == 1 ] ;
then
    echo "${segmentation} dataset for segmentation ok"
    echo "Doing stand alone ${segmentation} segmentation analysis"

    atlas=${segmentation}

    #Mask atlas by hemisphere (faster & avoids conflict with connectome)
    cd segmentation
    cp ${atlas} .
    outname=`basename ${atlas} .nii.gz` #for parsing outputs
    fslmaths ${atlas} -mas ${codedir}/templates/right_brain.nii.gz ${outname}_right
    fslmaths ${atlas} -mas ${codedir}/templates/left_brain.nii.gz ${outname}_left

    #Split atlas into individual ROI files
    echo "running deparcellator ${outname}"
    deparcellator.sh ${outname}_right
    deparcellator.sh ${outname}_left
    cd ../


    #Right thalamus: hard segmentation

    probtrackx2 --samples=bpx.bedpostX/merged \
    --mask=bpx.bedpostX/nodif_brain_mask \
    --xfm=bpx.bedpostX/xfms/standard2diff \
    --invxfm=bpx.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=segmentation/thalamus_right_MNI.nii.gz \
    --targetmasks=segmentation/${outname}_right_seeds/seeds_targets_list.txt \
    --dir=thalamus2cortex_right_${outname} \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000


    #Left thalamus: hard segmentation

    probtrackx2 --samples=bpx.bedpostX/merged \
    --mask=bpx.bedpostX/nodif_brain_mask \
    --xfm=bpx.bedpostX/xfms/standard2diff \
    --invxfm=bpx.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=segmentation/thalamus_left_MNI.nii.gz \
    --targetmasks=segmentation/${outname}_left_seeds/seeds_targets_list.txt \
    --dir=thalamus2cortex_left_${outname} \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000


    #Right pallidum: hard segmentation

    probtrackx2 --samples=bpx.bedpostX/merged \
    --mask=bpx.bedpostX/nodif_brain_mask \
    --xfm=bpx.bedpostX/xfms/standard2diff \
    --invxfm=bpx.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=segmentation/pallidum_right_MNI.nii.gz \
    --targetmasks=segmentation/${outname}_right_seeds/seeds_targets_list.txt \
    --dir=pallidum2cortex_right_${outname} \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000


    #Left pallidum: hard segmentation

    probtrackx2 --samples=bpx.bedpostX/merged \
    --mask=bpx.bedpostX/nodif_brain_mask \
    --xfm=bpx.bedpostX/xfms/standard2diff \
    --invxfm=bpx.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=segmentation/pallidum_left_MNI.nii.gz \
    --targetmasks=segmentation/${outname}_left_seeds/seeds_targets_list.txt \
    --dir=pallidum2cortex_left_${outname} \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000

    #right thalamus
    find_the_biggest thalamus2cortex_right_${outname}/seeds_to_* thalamus2cortex_right/biggest_segmentation
    #left thalamus
    find_the_biggest thalamus2cortex_left_${outname}/seeds_to_* thalamus2cortex_left/biggest_segmentation
    #right pallidum
    find_the_biggest pallidum2cortex_right_${outname}/seeds_to_* pallidum2cortex_right/biggest_segmentation
    #left pallidum
    find_the_biggest pallidum2cortex_left_${outname}/seeds_to_* pallidum2cortex_left/biggest_segmentation



else
    echo "No specified segmentation template identified. Continuing with default DK (clustering), Yeo7, & kmeans segmentation."
    default=1
fi


######

#2. DK

######


#only run as a default call if no individual segmentation atlas specified
if [ "${default}" -eq 1 ] ;
then

    #check if exists first
    if [ $(imtest dkn_volume_MNI_seq) == 1 ] ;
    then
        echo "DKN_volume_MNI_seq template already made"
        atlas=dkn_volume_MNI_seq.nii.gz

    else
        echo "making DK_volume_MNI_seq"

        #Set up DK: work in 'diffusion' directory
        SUBJECTS_DIR=`pwd`
        mri_aparc2aseg --s FS --annot aparc
        mri_convert ./FS/mri/aparc+aseg.mgz dkn_volume.nii.gz
        fslreorient2std dkn_volume.nii.gz dkn_volume.nii.gz

        #Registration
        flirt -in dkn_volume.nii.gz -ref ${codedir}/templates/500.sym_4mm.nii.gz -o dkn_volume_MNI -dof 12 -interp nearestneighbour

        #Renumber sequentially
        file_matlab=temp_DK_renumDesikan
        echo "Matlab file is: ${file_matlab}.m"
        echo "Matlab file variable is: ${file_matlab}"
        echo "renumDesikan_sub('dkn_volume_MNI.nii.gz', 0);exit" > ${file_matlab}.m
        matlab -nodisplay -r "${file_matlab}"

        #end DK setup
        echo "dkn_volume_MNI_seq now made"
        atlas=dkn_volume_MNI_seq.nii.gz

    fi

    #Split atlas into individual ROI files
    cp ${atlas} ./segmentation

    cd segmentation

    outname=`basename ${atlas} .nii.gz` #for parsing outputs

    #Run deparcellator
    echo "running deparcellator.sh ${outname}"
    deparcellator.sh ${outname}

    #Add dentate to list
    echo "${codedir}/templates/dentate_left.nii.gz" >> ${outname}_seeds/seeds_targets_list.txt
    echo "${codedir}/templates/dentate_right.nii.gz" >> ${outname}_seeds/seeds_targets_list.txt

    cd ../


    #Do segmentation

    #Right thalamus
    probtrackx2 --samples=bpx.bedpostX/merged \
    --mask=bpx.bedpostX/nodif_brain_mask \
    --xfm=bpx.bedpostX/xfms/standard2diff \
    --invxfm=bpx.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=segmentation/thalamus_right_MNI.nii.gz \
    --targetmasks=segmentation/${outname}_seeds/seeds_targets_list.txt \
    --dir=thalamus2cortex_right_cluster \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000


    #Left thalamus
    probtrackx2 --samples=bpx.bedpostX/merged \
    --mask=bpx.bedpostX/nodif_brain_mask \
    --xfm=bpx.bedpostX/xfms/standard2diff \
    --invxfm=bpx.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=segmentation/thalamus_left_MNI.nii.gz \
    --targetmasks=segmentation/${outname}_seeds/seeds_targets_list.txt \
    --dir=thalamus2cortex_left_cluster \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000

fi


#######

#3. Yeo

#######


#only run as a default call if no individual segmentation atlas specified
if [ "$default" == 1 ] ;
then

    atlas="${codedir}/templates/Yeo7.nii.gz"

    #Mask atlas by hemisphere (faster & avoids conflict with connectome)
    cd segmentation
    cp ${atlas}
    outname=`basename ${atlas} .nii.gz` #for parsing outputs
    fslmaths ${atlas} -mas ${codedir}/templates/right_brain.nii.gz ${outname}_right
    fslmaths ${atlas} -mas ${codedir}/templates/left_brain.nii.gz ${outname}_left

    #Split atlas into individual ROI files
    echo "running deparcellator ${outname}"
    deparcellator.sh ${outname}_right
    deparcellator.sh ${outname}_left
    cd ../


    #Right thalamus: hard segmentation

    probtrackx2 --samples=bpx.bedpostX/merged \
    --mask=bpx.bedpostX/nodif_brain_mask \
    --xfm=bpx.bedpostX/xfms/standard2diff \
    --invxfm=bpx.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=segmentation/thalamus_right_MNI.nii.gz \
    --targetmasks=segmentation/${outname}_right_seeds/seeds_targets_list.txt \
    --dir=thalamus2cortex_right \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000


    #Left thalamus: hard segmentation

    probtrackx2 --samples=bpx.bedpostX/merged \
    --mask=bpx.bedpostX/nodif_brain_mask \
    --xfm=bpx.bedpostX/xfms/standard2diff \
    --invxfm=bpx.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=segmentation/thalamus_left_MNI.nii.gz \
    --targetmasks=segmentation/${outname}_left_seeds/seeds_targets_list.txt \
    --dir=thalamus2cortex_left \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000


    #Right pallidum: hard segmentation

    probtrackx2 --samples=bpx.bedpostX/merged \
    --mask=bpx.bedpostX/nodif_brain_mask \
    --xfm=bpx.bedpostX/xfms/standard2diff \
    --invxfm=bpx.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=segmentation/pallidum_right_MNI.nii.gz \
    --targetmasks=segmentation/${outname}_right_seeds/seeds_targets_list.txt \
    --dir=pallidum2cortex_right \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000


    #Left pallidum: hard segmentation

    probtrackx2 --samples=bpx.bedpostX/merged \
    --mask=bpx.bedpostX/nodif_brain_mask \
    --xfm=bpx.bedpostX/xfms/standard2diff \
    --invxfm=bpx.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=segmentation/pallidum_left_MNI.nii.gz \
    --targetmasks=segmentation/${outname}_left_seeds/seeds_targets_list.txt \
    --dir=pallidum2cortex_left \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000

fi


##########

#4. kmeans

##########


#Alternative segmentation method (hypothesis free): requires subsequent Matlab run for kmeans segmentation

#only run as a default call if no individual segmentation atlas specified
if [ "$default" == 1 ] ;
then

    #Make grey matter mask in MNI space
    #Use ANTS preferentially
    fslmaths ${basedir}/ants_corthick/CorticalThicknessNormalizedToTemplate.nii.gz -bin ${basedir}/segmentation/GM_mask_MNI.nii.gz

    #Right thalamus: kmeans

    probtrackx2 --omatrix2 \
    --samples=bpx.bedpostX/merged \
    --mask=bpx.bedpostX/nodif_brain_mask \
    --xfm=bpx.bedpostX/xfms/standard2diff \
    --invxfm=bpx.bedpostX/xfms/diff2standard \
    --seed=segmentation/thalamus_right_MNI.nii.gz \
    --target2=segmentation/GM_mask_MNI.nii.gz \
    --dir=thalamus2cortex_right_omatrix2 \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --nsamples=5000


    #Left thalamus: kmeans

    probtrackx2 --omatrix2 \
    --samples=bpx.bedpostX/merged \
    --mask=bpx.bedpostX/nodif_brain_mask \
    --xfm=bpx.bedpostX/xfms/standard2diff \
    --invxfm=bpx.bedpostX/xfms/diff2standard \
    --seed=segmentation/thalamus_left_MNI.nii.gz \
    --target2=segmentation/GM_mask_MNI.nii.gz \
    --dir=thalamus2cortex_left_omatrix2 \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --nsamples=5000


    #Right pallidum: kmeans

    probtrackx2 --omatrix2 \
    --samples=bpx.bedpostX/merged \
    --mask=bpx.bedpostX/nodif_brain_mask \
    --xfm=bpx.bedpostX/xfms/standard2diff \
    --invxfm=bpx.bedpostX/xfms/diff2standard \
    --seed=segmentation/pallidum_right_MNI.nii.gz \
    --target2=segmentation/GM_mask_MNI.nii.gz \
    --dir=pallidum2cortex_right_omatrix2 \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --nsamples=5000


    #Left pallidum: kmeans

    probtrackx2 --omatrix2 \
    --samples=bpx.bedpostX/merged \
    --mask=bpx.bedpostX/nodif_brain_mask \
    --xfm=bpx.bedpostX/xfms/standard2diff \
    --invxfm=bpx.bedpostX/xfms/diff2standard \
    --seed=segmentation/pallidum_left_MNI.nii.gz \
    --target2=segmentation/GM_mask_MNI.nii.gz \
    --dir=pallidum2cortex_left_omatrix2 \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --nsamples=5000

fi



################################

## 5. Post tractography analysis

################################


#Cluster

echo "Running clustering"

#right thalamus
#68 parcels (no subcortical)
#61, 57, 55 [-7 -11 -13] SMA-PMC/M1/S1 right
cluster --in=thalamus2cortex_right_cluster/seeds_to_Seg0061.nii.gz --thresh=100 --othresh=thalamus2cortex_right_cluster/cluster_61
cluster --in=thalamus2cortex_right_cluster/seeds_to_Seg0057.nii.gz --thresh=100 --othresh=thalamus2cortex_right_cluster/cluster_57
cluster --in=thalamus2cortex_right_cluster/seeds_to_Seg0055.nii.gz --thresh=100 --othresh=thalamus2cortex_right_cluster/cluster_55
cluster --in=thalamus2cortex_right_cluster/seeds_to_dentate_left.nii.gz --thresh=100 --othresh=thalamus2cortex_right_cluster/cluster_dentate_left

#left thalamus
#68 parcels (no subcortical)
#27, 23, 21 [-7 -11 -13] SMA-PMC/M1/S1 left
cluster --in=thalamus2cortex_left_cluster/seeds_to_Seg0027.nii.gz --thresh=100 --othresh=thalamus2cortex_left_cluster/cluster_27
cluster --in=thalamus2cortex_left_cluster/seeds_to_Seg0023.nii.gz --thresh=100 --othresh=thalamus2cortex_left_cluster/cluster_23
cluster --in=thalamus2cortex_left_cluster/seeds_to_Seg0021.nii.gz --thresh=100 --othresh=thalamus2cortex_left_cluster/cluster_21
cluster --in=thalamus2cortex_left_cluster/seeds_to_dentate_right.nii.gz --thresh=100 --othresh=thalamus2cortex_left_cluster/cluster_dentate_right


#Hard segmentation

echo "Running hard segmentation"

#right thalamus
find_the_biggest thalamus2cortex_right/seeds_to_* thalamus2cortex_right/biggest_segmentation
#left thalamus
find_the_biggest thalamus2cortex_left/seeds_to_* thalamus2cortex_left/biggest_segmentation
#right pallidum
find_the_biggest pallidum2cortex_right/seeds_to_* pallidum2cortex_right/biggest_segmentation
#left pallidum
find_the_biggest pallidum2cortex_left/seeds_to_* pallidum2cortex_left/biggest_segmentation


#kmeans

echo "Running kmeans"

#right thalamus
cd thalamus2cortex_right_omatrix2
file_matlab=temp_Segmentation
echo "segmentation_clustering;exit" > ${file_matlab}.m
matlab -nodisplay -r "${file_matlab}"
fslcpgeom fdt_paths clusters
cd ..

#left thalamus
cd thalamus2cortex_left_omatrix2
file_matlab=temp_Segmentation
echo "segmentation_clustering;exit" > ${file_matlab}.m
matlab -nodisplay -r "${file_matlab}"
fslcpgeom fdt_paths clusters
cd ..

#right pallidum
cd pallidum2cortex_right_omatrix2
file_matlab=temp_Segmentation
echo "segmentation_clustering;exit" > ${file_matlab}.m
matlab -nodisplay -r "${file_matlab}"
fslcpgeom fdt_paths clusters
cd ..

#left pallidum
cd pallidum2cortex_left_omatrix2
file_matlab=temp_Segmentation
echo "segmentation_clustering;exit" > ${file_matlab}.m
matlab -nodisplay -r "${file_matlab}"
fslcpgeom fdt_paths clusters
cd ..
