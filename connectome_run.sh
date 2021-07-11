#!/bin/bash

#  connectome_run.sh
#
#  Single connectome run (set template manually)
#
#  Created by Michael Hart, University of British Columbia, May 2021
#

#################

#Set up

#################


tempdir=`pwd`
codedir=${HOME}/code/github/tractography

template=${codedir}/templates/500.sym_4mm.nii.gz #change this

FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard
parallel=1;
test -f connectome_run_log.txt && rm connectome_run_log.txt
touch connectome_run_log.txt
log=connectome_run_log.txt
echo $(date) >> ${log}


###########

#Single run

###########


outname=`basename ${template} .nii.gz`
echo "outname is: ${outname}"
echo "outname is: ${outname}" >> ${log}

if [[ -d ${tempdir}/probtrackx/${outname} ]] ;
then

    echo "${template} template connectome already run in probtrackx directory"
    echo "${template} template connectome already run in probtrackx directory" >> ${log}

else

    maxParcel=`fslstats ${template} -R | awk '{print $2}'`
    numParcels=`printf "%0.0f\n" $maxParcel`
    echo "numParcels: ${numParcels}"
    echo "numParcels: ${numParcels}" >> ${log}

    #mask template by gray matter: optional - not for DK
    #fslmaths ${template} -mul ${tempdir}/hardsegmentation/GM_mask_MNI ${template}

    #generate list of seeds
    #make new each time (for path continuity)
    if [[ -d ${tempdir}/${outname}_seeds/ ]] ; then rm -r ${tempdir}/${outname}_seeds/; fi
    echo "${template}: making seeds & seeds_list"
    echo "${template}: making seeds & seeds_list" >> ${log}
    deparcellator.sh ${template}

    if [ "${parallel}" == 1 ] ;
    then
        echo "Running probtrackx connectome in parallel"
        echo "Running probtrackx connectome in parallel" >> ${log}

        #1. Generate scripts

        mkdir -p ${tempdir}/probtrackx/${outname}/commands/

        if [ ! -f ${tempdir}/probtrackx/${outname}/commands/Seg`printf %04d $numParcels`.sh ] ;
        then
            echo "Generating tractography scripts"
            echo "Generating tractography scripts" >> ${log}
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
                --nsamples=500" >> ${tempdir}/probtrackx/${outname}/commands/${region_name}.sh
            done
        else
            echo "Tractography scripts have been made already."
            echo "Tractography scripts have been made already." >> ${log}
        fi

        seedFinished=`(ls ${tempdir}/probtrackx/${outname}/Seg*/matrix_seeds_to_all_targets 2>/dev/null | wc -l)`


        #2. Submit to cluster

        if [ "${seedFinished}" != "{$numParcels}" ] && [ -f ${tempdir}/diffusion.bedpostX/mean_S0samples.nii.gz ]
        then
            echo "Submitting tractography scripts to cluster"
            echo "Submitting tractography scripts to cluster" >> ${log}
            chmod 777 ${tempdir}/probtrackx/${outname}/commands/*
            for cmdFiles in ${tempdir}/probtrackx/${outname}/commands/*.sh
            do
                num_bars=$(( $(echo "$cmdFiles" |   grep -o "/"  | wc -l) + 1))
                seg_id=`echo $cmdFiles | cut -d "/" -f $num_bars`
                seg_id2=`echo $seg_id | sed "s/...$//g"`
                if [ ! -f ${tempdir}/probtrackx/${outname}/${seg_id2}/matrix_seeds_to_all_targets ]
                then
                    sbatch --time=1:00:00 ${cmdFiles}
                    sleep 10
                fi
            done

            echo "Tractography jobs submitted to the cluster - *might* need to re-run script after they have finished (check with qstats or squeue) to merge tracts."
            echo "Tractography jobs submitted to the cluster - *might* need to re-run script after they have finished (check with qstats or squeue) to merge tracts." >> ${log}
            echo "Check number of jobs finished (number of parcels=${numParcels})."
            echo "Check number of jobs finished (number of parcels=${numParcels})." >> ${log}
            echo "ls ${tempdir}/${outname}_connectome/Seg*/matrix_seeds_to_all_targets | wc -l"

            #Significant pause: ~1min per parcel for tracing (depends on volume) + queue
            echo "going to sleep to wait for parcels to finish: 6h"
            echo "going to sleep to wait for parcels to finish: 6h" >> ${log}
            sleep 6h

        else
            echo "Tractography scripts have finished running on cluster already"
            echo "Tractography scripts have finished running on cluster already" >> ${log}
        fi


        seedFinished=`(ls ${tempdir}/probtrackx/${outname}/Seg*/matrix_seeds_to_all_targets 2>/dev/null | wc -l)`

        
        #3. Check all tractography scripts have run (& re-submit if not)
        
        echo "Number of jobs finished: ${seedFinished} Should equal number of parcels: ${numParcels}"
        echo "Number of jobs finished: ${seedFinished} Should equal number of parcels: ${numParcels}" >> ${log}
        
        iteration=1
        
        while [ "${seedFinished}" != "${numParcels}" ] ;
        do
            
            echo "Number of jobs finished: ${seedFinished}"
            echo "Number of jobs finished: ${seedFinished}" >> ${log}
            
            echo "iteration = ${iteration}"
            echo "iteration = ${iteration}" >> ${log}
            
            echo "Re-submitting incomplete tractography scripts to cluster"
            echo "Re-submitting incomplete tractography scripts to cluster" >> ${log}
            
            echo "(partial) cleanup of intermediary files"
            echo "(partial) cleanup of intermediary files" >> ${log}
            
            rm -r slurm*
            
            for cmdFiles in ${tempdir}/probtrackx/${outname}/commands/*.sh
            do
               num_bars=$(( $(echo "$cmdFiles" |   grep -o "/"  | wc -l) + 1))
               seg_id=`echo $cmdFiles | cut -d "/" -f $num_bars`
               seg_id2=`echo $seg_id | sed "s/...$//g"`
               if [ ! -f ${tempdir}/probtrackx/${outname}/${seg_id2}/matrix_seeds_to_all_targets ] ;
               then
                   sbatch --time=1:00:00 ${cmdFiles}
                   echo "re-submitting ${seg_id2}"
                   echo "re-submitting ${seg_id2}" >> ${log}
                   sleep 10
               fi
            done

            echo "Tractography jobs re-submitted to the cluster"
            echo "Tractography jobs re-submitted to the cluster" >> ${log}
            echo "Check number of jobs finished (number of parcels=${numParcels})"
            echo "Check number of jobs finished (number of parcels=${numParcels})" >> ${log}
            echo "ls ${tempdir}/${outname}_connectome/Seg*/matrix_seeds_to_all_targets | wc -l"

            #Significant pause: ~1min per parcel for tracing (depends on volume) + queue
            echo "Going to sleep (again) to wait for parcels to finish: 6h"
            echo "Going to sleep (again) to wait for parcels to finish: 6h" >> ${log}
            sleep 6h
            
            iteration=`echo $iteration + 1 | bc`;
            seedFinished=`(ls ${tempdir}/probtrackx/${outname}/Seg*/matrix_seeds_to_all_targets 2>/dev/null | wc -l)`

        done
               
               
        #4. Merge tracts
        
        echo "checking: ${tempdir}/probtrackx/${outname}/connectome/connectivity_strlines.jpg"
        echo "checking: ${tempdir}/probtrackx/${outname}/connectome/connectivity_strlines.jpg" >> ${log}

        if [ ! -f ${tempdir}/probtrackx/connectome/connectivity_strlines.jpg ] ;
        then
            echo "Making mergeTracts.m file"
            echo "Making mergeTracts.m file" >> ${log}
            file_matlab=temp_${numParcels}_mergeTracts

            echo "mergeTracts('${tempdir}/','${outname}');exit" > ${file_matlab}.m

            matlab -nodisplay -r "${file_matlab}"
        
            mkdir -p ${tempdir}/probtrackx/${outname}/connectome
            mv ${tempdir}/probtrackx/${outname}/connectivity* ${tempdir}/probtrackx/${outname}/connectome/
        
            echo "Connectome tractography complete without errors!"
            echo "Connectome tractography complete without errors!" >> ${log}
            
            echo "cleanup of intermediary files"
            echo "cleanup of intermediary files" >> ${log}

            rm -r slurm* probtrackx/${outname}/Seg* probtrackx/${outname}/commands ${outname}_seeds/Seg*
                                
        else
        
            echo "Connectome already computed: results in ${tempdir}/probtrackx/${outname}/connectome/"
            echo "Connectome already computed: results in ${tempdir}/probtrackx/${outname}/connectome/" >> ${log}
        
        fi

    else #parallel loop at start
    
        echo "Running probtrackx connectome sequentially with --network option"
        #this shouldn't run either!
        #echo "Starting connectome sequentially with --network option" >> $log
        #echo "" >> $log

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

fi


echo $(date) >> ${log}
echo "All done with connectome_run"
echo "All done with connectome_run" >> ${log}
