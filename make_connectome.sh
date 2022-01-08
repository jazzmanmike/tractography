#!/bin/bash
set -e

# make_connectome.sh
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard

#template
if [ $(imtest ${template}) == 1 ];
then
    echo "${template} dataset for connectomics ok"
else
    template="${codedir}/templates/AAL90.nii.gz"
    echo "No parcellation template for connectomics has been supplied - using AAL90 cortical (78 nodes)"
fi

#parcels
maxParcel=`fslstats ${template} -R | awk '{print $2}'`
numParcels=`printf "%0.0f\n" $maxParcel`
echo "numParcels: ${numParcels}"

echo "Parcellation template is: ${template}" >> ${log}
echo "numParcels: ${numParcels}" >> ${log}
cp ${template} .

outname=`basename ${template} .nii.gz` #for parsing output to probtrackx below
echo "outname is: ${outname}"

#generate list of seeds
if [[ ! -d ${tempdir}/${outname}_seeds/ ]] ;
then
    echo "${outname}: making seeds & seeds_list"
    deparcellator.sh ${outname}
else
    echo "${outname} seeds already made"
fi

if [ "${parallel}" == 1 ] ;
then
    echo "Running probtrackx connectome in parallel"
    echo "Starting connectome --parallel" >> $log
    echo "" >> $log

    #1. Generate scripts

    mkdir -p ${tempdir}/probtrackx/${outname}/commands/

    if [ ! -f ${tempdir}/probtrackx/${outname}/commands/Seg`printf %04d $numParcels`.sh ] ;
    then
        echo "Generating tractography scripts"
        for region in `cat  ${tempdir}/${outname}_seeds/seeds_targets_list.txt`;
        do
            region_name=`basename ${region} .nii.gz`
            touch ${tempdir}/probtrackx/${outname}/commands/${region_name}.sh
            echo "#!/bin/bash" >> ${tempdir}/probtrackx/${outname}/commands/${region_name}.sh
            echo "probtrackx2 \
            --samples=${tempdir}/diffusion.bedpostX/merged \
            --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
            --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
            --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
            --seed=${region} \
            --dir=${tempdir}/probtrackx/${outname}/${region_name}/ \
            --targetmasks=${tempdir}/${outname}_seeds/seeds_targets_list.txt \
            --s2tastext \
            --pd \
            --loopcheck \
            --forcedir \
            --opd \
            --os2t \
            --nsamples=5000" >> ${tempdir}/probtrackx/${outname}/commands/${region_name}.sh
        done
    else
        echo "Tractography scripts have been made already."
    fi


    seedFinished=`(ls ${tempdir}/probtrackx/${outname}/Seg*/matrix_seeds_to_all_targets 2>/dev/null | wc -l)`


    #2. Submit to cluster

    if [ "${seedFinished}" != "$numParcels" ] && [ -f ${tempdir}/diffusion.bedpostX/mean_S0samples.nii.gz ]
    then
        echo "Submitting tractography scripts to cluster"
        chmod 777 ${tempdir}/probtrackx/${outname}/commands/*
        for cmdFiles in ${tempdir}/probtrackx/${outname}/commands/*.sh
        do
            num_bars=$(( $(echo "$cmdFiles" |   grep -o "/"  | wc -l) + 1))
            seg_id=`echo $cmdFiles | cut -d "/" -f $num_bars`
            seg_id2=`echo $seg_id | sed "s/...$//g"`
            if [ ! -f ${tempdir}/probtrackx/${outname}/${seg_id2}/matrix_seeds_to_all_targets ]
            then
                sbatch --time=10:00:00 ${cmdFiles}
                sleep 10
            fi
        done

        echo "Tractography jobs submitted to the cluster - *might* need to re-run script after they have finished (check with qstats or squeue) to merge tracts."
        echo "Check number of jobs finished (number of parcels=${numParcels})."
        echo "ls ${tempdir}/${outname}_connectome/Seg*/matrix_seeds_to_all_targets | wc -l"

        #Significant pause: ~1min per parcel for tracing (depends on volume)
        sleep 10h
    else
        echo "Tractography scripts have finished running on cluster already."
    fi


    seedFinished=`(ls ${tempdir}/probtrackx/${outname}/Seg*/matrix_seeds_to_all_targets 2>/dev/null | wc -l)`


    #3. Merge tracts
    echo "Number of jobs finished: ${seedFinished} Should equal number of parcels: ${numParcels}"
    echo "checking: ${tempdir}/probtrackx/connectome/connectivity_strlines.jpg"
    if [ ! -f ${tempdir}/probtrackx/connectome/connectivity_strlines.jpg ]
    then
        if [ "${seedFinished}" = "$numParcels" ]
        then
            echo "Combining tractography images"
            file_matlab=temp_${numParcels}_mergeTracts
            pwd
            echo "Matlab file is: ${file_matlab}.m"
            echo "Matlab file variable is: ${file_matlab}"

            echo "mergeTracts('${tempdir}/','${outname}');exit" > ${file_matlab}.m
            matlab -nodisplay -r "${file_matlab}"

            mkdir -p ${tempdir}/probtrackx/${outname}/connectome
            mv ${tempdir}/probtrackx/${outname}/connectivity* ${tempdir}/probtrackx/${outname}/connectome/

            echo "Connectome tractography complete without errors!"
        else
            echo "Tractography seeds still running: ${seedFinished} != ${numParcels}. Merge tracts not run. Re-run after they have finish in: ${tempdir}/probtrackx/${outname}."
        fi
    else
        echo "Connectome already computed: results in ${tempdir}/probtrackx/${outname}/connectome/"
    fi

else
    echo "Running probtrackx connectome in serial with --network option"
    echo "Starting connectome in serial with --network option" >> $log
    echo "" >> $log

    #only 500 seeds and no option '-opd'
    probtrackx2 \
    --network \
    --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --dir=${outname} \
    --seed=${outname}_seeds/seeds_targets_list.txt \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --nsamples=500

fi
