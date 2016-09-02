#!/bin/bash
#
# wrf_demo Grid and Cloud execution script
# This script contains two functions containing each the WRF demo
# execution steps for Grid or for Cloud. The proper function will be
# automatically selected.
#
# wrf_demo_grid  - Tester Grid Job
#                  This script will execute the WRF demo on a Grid WN
#
# wrf_demo_cloud   - Tester Cloud Job
#                    This function will execute the WRF demo on a Cloud node
#
# wrf_demo_cluster - Tester Cluster Job
#                    This function will execute the WRF demo on a Cluster node
# riccardo.bruno@ct.infn.it
#

wrf_demo_cloud()
{
  WORKING_DIR=$1
  INPUT_TAR=$2
  SCRIPT_TS=$(date +%Y%m%d%H%M%S)
  JSAGAWD=$(pwd)
  #cp all_wrf_inputs.tar.gz /root
  cp ${WORKING_DIR} ${WORKING_DIR}

  #
  # Determining the portal informations
  #
  PORTAL_INFO=$(ls -1rt | grep test_patterns.txt)
  if [ -f "${PORTAL_INFO}" ]; then
    . $PORTAL_INFO
    TS=$(echo $PORTAL_INFO | awk -F"_" '{ print $1 }')
    echo "Portal timestamp: $TS"
    echo "Simulation type: $SIMTYPE"
    echo "Username: $USERNAME"
    echo "Portal: $PORTAL"
    echo "e-mail: $EMAIL"
  else
    TS=$SCRIPT_TS
    echo "WARNING: Did not find the portal information file"
  fi
  echo "Script timestamp: $SCRIPT_TS"

  #
  # Executing WRF demo
  #
  #cd /root
  cd ${WORKING_DIR}
  WD=$PWD
  export LD_LIBRARY_PATH=/usr/local/lib/:/opt/gcc-4.8.2/lib64/
  export NETCDF=netcdf-fortran-4.2
  export WRFIO_NCD_LARGE_FILE_SUPPORT=1

  # Input files
  # WPSx files are related to a different WPS execution each
  # having a different configuration file
  tar xvfz ${INPUT_TAR}
  JWD=$PWD
  NAMELIST_WPS1=$PWD/namelist.wps_1
  NAMELIST_WPS2=$PWD/namelist.wps_2
  NAMELIST_WPS3=$PWD/namelist.wps_3
  NAMELIST_WPS4=$PWD/namelist.wps_4
  NAMELIST_INPUT=$PWD/namelist.input

  #WPS
  cd WPS
  GEOGPATHLN=$(cat $NAMELIST_WPS1 | grep -n "geog_data_path" | awk -F":" '{ print $1 }')
  NUMLINES=$(cat $NAMELIST_WPS1 | wc -l)
  cat $NAMELIST_WPS1 | head -n $((GEOGPATHLN-1)) > ./namelist.wps
  echo "geog_data_path = '$WD/geog'" >> ./namelist.wps
  cat $NAMELIST_WPS1 | tail -n $((NUMLINES-GEOGPATHLN)) >> ./namelist.wps
  echo "Stage 1 - Executing GEOGRID"
  ./geogrid.exe
  echo "Stage 2a - First execution of ungrib PL20130311.grb"
  rm ./namelist.wps
  ln -s $NAMELIST_WPS2 ./namelist.wps
  mv $JWD/Vtable ./Vtable
  mv $JWD/PL20130311.grb .
  ./link_grib.csh PL20130311.grb
  ./ungrib.exe
  echo "Stage 2b - Second execution of ungrib SFC20130311.grb"
  rm ./namelist.wps
  ln -s $NAMELIST_WPS3 ./namelist.wps
  mv $JWD/SFC20130311.grb .
  ./link_grib.csh SFC20130311.grb
  ./ungrib.exe
  echo "Stage 3 - METGRID"
  rm ./namelist.wps
  ln -s $NAMELIST_WPS4 ./namelist.wps
  mv $JWD/METGRID.TBL metgrid/
  ./metgrid.exe
  cd -
  # real and WRF
  echo "Stage 4 - Running WRF"
  cd WRFV3/run
  mv namelist.input namelist.input_default
  ln -sf $NAMELIST_INPUT namelist.input
  ln -sf $JWD/WPS/met_em* .
  echo "Executing real.exe"
  ./real.exe
  echo "Executing wrf.exe"
  ./wrf.exe

  #
  # Any image processing goes here below ...
  #

  # plot_wrf_maps - generates a series of images form wrfout file
  python plot_wrf_maps.py -f $(ls wrfout*)
  echo "<html><body><table>" > /var/www/html/wrf_output.html ; ls -1 d01_* | xargs -i cp {} /var/www/html/ ; ls -1 d01_* | xargs -i echo "<tr><td><img src=\"{}\"\></td></tr>" >> /var/www/html/wrf_output.html; echo "</table></body></html>" >> /var/www/html/wrf_output.html

  # genavm - generates wrf data maps and the related animations
  python genavm.py $(ls wrfout*)

  # produce the README.txt file
  #cat > ${WORKING_DIR}/README.txt <<EOF
  cat > ${JSAGAWD}/README.txt <<EOF
#
# WRF demo execution
#
# riccardo.bruno@ct.infn.it
#
The Weather Research and Forecasting (WRF) Model is a next-generation mesoscale numerical weather prediction system designed to serve both atmospheric research and operational forecasting needs

http://www.wrf-model.org/index.php

This is just a demo execution that considers only a small african region (LAT:319611,LONG:37.980000),
in the period that comes from 16th Mar 2013 till the 17th Mar 2013.
This demo will produce several output data that consists:

WRF output raw data:
  wrfout* and wrfrst* wrfbdy* namelist.output
WRF data extraction:
  Series of GIF images generated by the plot_wrf_maps.py
  (http://www.atmos.washington.edu/~lmadaus/pyscripts.html)
WRF output NetCDF 4D Variables images:
  Series of GIF images representing almost all the available
  NetCFD' 4D variables present in the WRF output file.

The Job output will report only the raw data; the other two kind of WRF data will be
available through a dedicated portal space.
EOF

  # Collecting output
  echo "Collecting output"
  tar cvfz $JSAGAWD/wrf_output.tar.gz wrfout_* wrfrst_* wrfbdy_* namelist.output README.txt

  # Show 'WRFV3/run' directory content
  ls -lrt .

  cd -
  echo "Ending at: "$(date)
}

wrf_demo_grid()
{
  VO=eumed
  WRFPKG=WRFSWPKG_x86_64.tar.gz

  echo "Starting at: "$(date)
  echo "Host: "$(hostname -f)

  # produce the README.txt file
  cat > README.txt <<EOF
#
# WRF demo execution
#
# riccardo.bruno@ct.infn.it
#
The Weather Research and Forecasting (WRF) Model is a next-generation mesoscale numerical weather prediction system designed to serve both atmospheric research and operational forecasting needs

http://www.wrf-model.org/index.php

This is just a demo execution that considers only a small african region (LAT=31.96, LONG=37.98),
in the period that comes from 16th Mar 2013 till the 17th Mar 2013.
This demo will produce several output data that consists:

  WRF output raw data:
	  wrfout* and wrfrst* wrfbdy* namelist.output
  WRF data extraction:
	  Series of GIF images generated by the plot_wrf_maps.py
	  (http://www.atmos.washington.edu/~lmadaus/pyscripts.html)
  WRF output NetCDF 4D Variables images:
	  Series of GIF images representing almost all the available
	  NetCFD' 4D variables present in the WRF output file.

The Job output will report only the raw data; the other two kind of WRF data will be
available through a dedicated portal space.
EOF

  echo "$PWD Directory listing:"
  ls -lrt

  VO_NAME=$(voms-proxy-info -vo)
  VO_VARNAME=$(echo $VO_NAME | sed s/"\."/"_"/g | sed s/"-"/"_"/g | awk '{ print toupper($1) }')
  VO_SWPATH_NAME="VO_"$VO_VARNAME"_SW_DIR"
  VOSWDIR=$(echo $VO_SWPATH_NAME | awk '{ cmd=sprintf("echo $%s",$1); system(cmd); }')
  echo "$VOSWDIR Directory listing:"
  ls -lrt

  echo "Environment:"
  env

  CHECK=0
  # pre-requisites
  if  [ ! -d $VOSWDIR/geog ]; then
    CHECK=$((CHECK+1))
    echo "ERROR: did not find GEOG directory in $VOSWDIR"
  fi
  if [ ! -f $VOSWDIR/$WRFPKG ]; then
    CHECK=$((CHECK+1))
    echo "ERROR: did not find WRFPKG file in $VOSWDIR"
  fi

  if [ $CHECK -ne 0 ]; then
    echo "ERROR: Pre-requisites check failed"
    exit 10
  fi

  #
  #  extracty the WRF tarball file
  #
  echo "Extracting WRFPKG archive: $VOSWDIR/$WRFPKG"
  tar xvfz $VOSWDIR/$WRFPKG -C $PWD
  RES=$?

  if [ $RES -ne 0 ]; then
    echo "ERROR: Extracting tarball file: $VOSWDIR/$WRFPKG"
    exit 20
  fi

  #
  # Setup WRF environment
  #
  echo "Setting up the environment"
  # VO NAME
  # VOSWDIR will be overwritten below; save it
  VOSWDIR_ORIG=$VOSWDIR
  export VOSWDIR=$PWD
  # Add the gcc-4.8.0 path lib and include direcorties in the paths
  PKGNAME=gcc-4.8.0
  export CPPFLAGS="$CPPFLAGS -I$VOSWDIR/$PKGNAME/include"
  export CPATH="$CPATH:$VOSWDIR/$PKGNAME/include"
  export LDFLAGS="$LDFLAGS -L$VOSWDIR/$PKGNAME/lib64 -L$VOSWDIR/$PKGNAME/lib"
  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$VOSWDIR/$PKGNAME/lib64:$VOSWDIR/$PKGNAME/lib"
  export PATH="$VOSWDIR/$PKGNAME/bin:$PATH"
  PKGNAME=zlib-1.2.8
  export CPPFLAGS="$CPPFLAGS -I$VOSWDIR/$PKGNAME/include"
  export CPATH="$CPATH:$VOSWDIR/$PKGNAME/include"
  export LDFLAGS="$LDFLAGS -L$VOSWDIR/$PKGNAME/lib"
  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$VOSWDIR/$PKGNAME/lib"
  export PATH="$VOSWDIR/$PKGNAME/bin:$PATH"
  PKGNAME=hdf5-1.8.11
  export CPPFLAGS="$CPPFLAGS -I$VOSWDIR/$PKGNAME/include"
  export CPATH="$CPATH:$VOSWDIR/$PKGNAME/include"
  export LDFLAGS="$LDFLAGS -L$VOSWDIR/$PKGNAME/lib"
  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$VOSWDIR/$PKGNAME/lib"
  export PATH="$VOSWDIR/$PKGNAME/bin:$PATH"
  PKGNAME=netcdf-4.3.0
  export CPPFLAGS="$CPPFLAGS -I$VOSWDIR/$PKGNAME/include"
  export CPATH="$CPATH:$VOSWDIR/$PKGNAME/include"
  export LDFLAGS="$LDFLAGS -L$VOSWDIR/$PKGNAME/lib"
  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$VOSWDIR/$PKGNAME/lib"
  export PATH="$VOSWDIR/$PKGNAME/bin:$PATH"
  PKGNAME=netcdf-fortran-4.2
  export CPPFLAGS="$CPPFLAGS -I$VOSWDIR/$PKGNAME/include"
  export CPATH="$CPATH:$VOSWDIR/$PKGNAME/include"
  export LDFLAGS="$LDFLAGS -L$VOSWDIR/$PKGNAME/lib"
  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$VOSWDIR/$PKGNAME/lib"
  export PATH="$VOSWDIR/$PKGNAME/bin:$PATH"
  PKGNAME=jasper-1.900.1
  export CPPFLAGS="$CPPFLAGS -I$VOSWDIR/$PKGNAME/include"
  export CPATH="$CPATH:$VOSWDIR/$PKGNAME/include"
  export LDFLAGS="$LDFLAGS -L$VOSWDIR/$PKGNAME/lib"
  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$VOSWDIR/$PKGNAME/lib"
  export PATH="$VOSWDIR/$PKGNAME/bin:$PATH"
  PKGNAME=grib_api-1.10.0
  export CPPFLAGS="$CPPFLAGS -I$VOSWDIR/$PKGNAME/include"
  export CPATH="$CPATH:$VOSWDIR/$PKGNAME/include"
  export LDFLAGS="$LDFLAGS -L$VOSWDIR/$PKGNAME/lib"
  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$VOSWDIR/$PKGNAME/lib"
  export PATH="$VOSWDIR/$PKGNAME/bin:$PATH"
  # WRF Environment
  export NETCDF=$VOSWDIR/netcdf-fortran-4.2
  export WRFIO_NCD_LARGE_FILE_SUPPORT=1
  # Save back the VOSWDIR
  VOSWDIR=$VOSWDIR_ORIG

  #
  # Testing the environment
  #
  echo "Which GCC:" $(which gcc)
  echo "nc-config:"
  nc-config --all

  echo "$PWD Directory listing:"
  ls -lrt

  #
  # Executing WRF demo
  #

  #Extracting input files
  tar xvfz all_wrf_inputs.tar.gz

  JWD=$PWD
  NAMELIST_WPS1=$PWD/namelist.wps_1
  NAMELIST_WPS2=$PWD/namelist.wps_2
  NAMELIST_WPS3=$PWD/namelist.wps_3
  NAMELIST_WPS4=$PWD/namelist.wps_4
  NAMELIST_INPUT=$PWD/namelist.input

  #WPS
  cd WPS
  GEOGPATHLN=$(cat $NAMELIST_WPS1 | grep -n "geog_data_path" | awk -F":" '{ print $1 }')
  NUMLINES=$(cat $NAMELIST_WPS1 | wc -l)
  cat $NAMELIST_WPS1 | head -n $((GEOGPATHLN-1)) > ./namelist.wps
  echo "geog_data_path = '$VOSWDIR/geog'" >> ./namelist.wps
  cat $NAMELIST_WPS1 | tail -n $((NUMLINES-GEOGPATHLN)) >> ./namelist.wps
  echo "Stage 1 - Executing GEOGRID"
  ./geogrid.exe
  echo "Stage 2a - First execution of ungrib PL20130311.grb"
  rm ./namelist.wps
  ln -s $NAMELIST_WPS2 ./namelist.wps
  mv $JWD/Vtable ./Vtable
  mv $JWD/PL20130311.grb .
  ./link_grib.csh PL20130311.grb
  ./ungrib.exe
  echo "Stage 2b - Second execution of ungrib SFC20130311.grb"
  rm ./namelist.wps
  ln -s $NAMELIST_WPS3 ./namelist.wps
  mv $JWD/SFC20130311.grb .
  ./link_grib.csh SFC20130311.grb
  ./ungrib.exe
  echo "Stage 3 - METGRID"
  rm ./namelist.wps
  ln -s $NAMELIST_WPS4 ./namelist.wps
  mv $JWD/METGRID.TBL metgrid/
  ./metgrid.exe
  cd -
  # real and WRF
  echo "Stage 4 - Running WRF"
  cd WRFV3/run
  mv namelist.input namelist.input_default
  ln -sf $NAMELIST_INPUT namelist.input
  ln -sf $JWD/WPS/met_em* .
  echo "Executing real.exe"
  ./real.exe
  echo "Executing wrf.exe"
  ./wrf.exe

  # Collecting output
  echo "Collecting output"
  tar cvfz $JWD/wrf_output.tar.gz namelist.output wrfrst_*

  # Show 'WRFV3/run' directory content
  ls -lrt .

  cd -
  echo "Ending at: "$(date)
}

wrf_demo_cluster()
{
  INPUT_TAR=$2
  SCRIPT_TS=$(date +%Y%m%d%H%M%S)
  WORKING_DIR=$1
  JSAGAWD=$(pwd)
  cp -r $WORKING_DIR/WPS/ $JSAGAWD
  cp -r $WORKING_DIR/WRFV3/ $JSAGAWD
  
  #
  # Determining the portal informations
  #
  PORTAL_INFO=$(ls -1rt | grep test_patterns.txt)
  if [ -f "${PORTAL_INFO}" ]; then
    . $PORTAL_INFO
    TS=$(echo $PORTAL_INFO | awk -F"_" '{ print $1 }')
    echo "Portal timestamp: $TS"
    echo "Simulation type: $SIMTYPE"
    echo "Username: $USERNAME"
    echo "Portal: $PORTAL"
    echo "e-mail: $EMAIL"
  else
    TS=$SCRIPT_TS
    echo "WARNING: Did not find the portal information file"
  fi
  echo "Script timestamp: $SCRIPT_TS"

  #
  # Executing WRF demo
  #
  WD=$PWD
  export LD_LIBRARY_PATH=/usr/local/lib/:/opt/gcc-4.8.2/lib64/
  export NETCDF=netcdf-fortran-4.2
  export WRFIO_NCD_LARGE_FILE_SUPPORT=1

  # Input files
  # WPSx files are related to a different WPS execution each
  # having a different configuration file
  tar xvfz ${INPUT_TAR}
  JWD=$PWD
  NAMELIST_WPS1=$PWD/namelist.wps_1
  NAMELIST_WPS2=$PWD/namelist.wps_2
  NAMELIST_WPS3=$PWD/namelist.wps_3
  NAMELIST_WPS4=$PWD/namelist.wps_4
  NAMELIST_INPUT=$PWD/namelist.input

  #WPS
  cd WPS
  GEOGPATHLN=$(cat $NAMELIST_WPS1 | grep -n "geog_data_path" | awk -F":" '{ print $1 }')
  NUMLINES=$(cat $NAMELIST_WPS1 | wc -l)
  cat $NAMELIST_WPS1 | head -n $((GEOGPATHLN-1)) > ./namelist.wps
  echo "geog_data_path = '$WORKING_DIR/geog'" >> ./namelist.wps
  cat $NAMELIST_WPS1 | tail -n $((NUMLINES-GEOGPATHLN)) >> ./namelist.wps
  echo "Stage 1 - Executing GEOGRID"
  ./geogrid.exe
  echo "Stage 2a - First execution of ungrib PL20130311.grb"
  rm ./namelist.wps
  ln -s $NAMELIST_WPS2 ./namelist.wps
  mv $JWD/Vtable ./Vtable
  mv $JWD/PL20130311.grb .
  ./link_grib.csh PL20130311.grb
  ./ungrib.exe
  echo "Stage 2b - Second execution of ungrib SFC20130311.grb"
  rm ./namelist.wps
  ln -s $NAMELIST_WPS3 ./namelist.wps
  mv $JWD/SFC20130311.grb .
  ./link_grib.csh SFC20130311.grb
  ./ungrib.exe
  echo "Stage 3 - METGRID"
  rm ./namelist.wps
  ln -s $NAMELIST_WPS4 ./namelist.wps
  mv $JWD/METGRID.TBL metgrid/
  ./metgrid.exe
  cd -
  # real and WRF
  echo "Stage 4 - Running WRF"
  cd WRFV3/run
  mv namelist.input namelist.input_default
  ln -sf $NAMELIST_INPUT namelist.input
  ln -sf $JWD/WPS/met_em* .
  echo "Executing real.exe"
  ./real.exe
  echo "Executing wrf.exe"
  ./wrf.exe

  #
  # Any image processing goes here below ...
  #

  # User based images generation
  JOBEXEID=$(openssl rand -hex 10)
  WEBDIR=/var/www/html/${JOBEXEID}
  mkdir $WEBDIR
  cat genavm.py_tmpl | sed s/WEBBASEPATH/${WEBDIR}/g > $JSAGAWD/WRFV3/run/genavm.py

  # plot_wrf_maps - generates a series of images form wrfout file
  python plot_wrf_maps.py -f $(ls wrfout*)
  echo "<html><body><table>" > ${WEBDIR}/wrf_output.html ; ls -1 d01_* | xargs -i cp {} ${WEBDIR}/ ; ls -1 d01_* | xargs -i echo "<tr><td><img src=\"{}\"\></td></tr>" >> ${WEBDIR}/wrf_output.html; echo "</table></body></html>" >> $WEBDIR/wrf_output.html

  # genavm - generates wrf data maps and the related animations
  python genavm.py $(ls wrfout*)

  # Get dinamically the IP
  IPHOST=$(ifconfig | grep "inet addr" | head -n 2 | tail -n 1 | awk -F":" '{ print $2 }' | awk '{ print $1 }')

  # produce the README.txt file
  cat > ${JSAGAWD}/README.txt <<EOF
#
# WRF demo execution
#
# riccardo.bruno@ct.infn.it
#
The Weather Research and Forecasting (WRF) Model is a next-generation mesoscale numerical weather prediction system designed to serve both atmospheric research and operational forecasting needs

http://www.wrf-model.org/index.php

This is just a demo execution that considers only a small african region (LAT:319611,LONG:37.980000),
in the period that comes from 16th Mar 2013 till the 17th Mar 2013.
This demo will produce several output data that consists:

WRF output raw data:
  wrfout* and wrfrst* wrfbdy* namelist.output
WRF data extraction:
  Series of GIF images generated by the plot_wrf_maps.py
  (http://www.atmos.washington.edu/~lmadaus/pyscripts.html)
WRF output NetCDF 4D Variables images:
  Series of GIF images representing almost all the available
  NetCFD' 4D variables present in the WRF output file.

The Job output will report only the raw data; the other two kind of WRF data will be
available through a dedicated portal space.

The produced images are available by the URL: http://${IPHOST}/${JOBEXEID}
EOF

  # Collecting output
  echo "Collecting output"
  tar cvfz $JSAGAWD/wrf_output.tar.gz wrfout_* wrfrst_* wrfbdy_* namelist.output README.txt

  # Show 'WRFV3/run' directory content
  ls -lrt .

  cd -
  echo "Ending at: "$(date)
}


#
# Main - Only cloud node has the WRFV3 dir in /root directory
#

if [ -d /export/apps/WRF/WRFV3 ]; then
  wrf_demo_cluster "/export/apps/WRF" $1
elif [ -d /root/WRFV3 ]; then
  wrf_demo_cloud "/root" $1
else
  wrf_demo_grid
fi

