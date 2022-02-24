#!/bin/bash

#  parcellation_run.sh
#
#  Separate FreeSurfer call
#
#  Created by Michael Hart on 12/04/2021.

basedir=`pwd`

for subject in *_FS ; do

  echo ${subject}

  cd ${subject}

  echo `pwd`

  parcellation2individuals_sym.sh

  cd ${basedir}

done
