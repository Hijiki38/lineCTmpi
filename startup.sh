#!/usr/bin/env bash
echo bbb
cat ~/.bashrc
ls -l
echo "SOD,$PAR_SOD" > /app/parameter.csv
echo "SDD,$PAR_SDD" >> /app/parameter.csv 
echo "PTCH,$PAR_PTCH" >> /app/parameter.csv 
echo "TTMS,$PAR_TTMS" >> /app/parameter.csv 
echo "STEP,$PAR_STEP" >> /app/parameter.csv 
echo "HIST,$PAR_HIST" >> /app/parameter.csv 
echo "ISTP,$PAR_ISTP" >> /app/parameter.csv 
echo "PNTM,$PAR_PNTM" >> /app/parameter.csv 
echo "BEAM,$PAR_BEAM" >> /app/parameter.csv 
cp -f "$INPFILE.inp" ./linect.inp
echo "$FFILE" | ./egs5mpirun




"echo PATH=/opt/openMPI/bin:\$PATH >> ~/.bashrc &&
echo LD_LIBRARY_PATH=/opt/openMPI/lib:\$LD_LIBRARY_PATH >> ~/.bashrc &&
echo MANPATH=/opt/openMPI/share/man:\$MANPATH >> ~/.bashrc &&
echo export PATH LD_LIBRARY_PATH MANPATH >> ~/.bashrc &&
. ~/.bashrc &&
echo \"SOD,$PAR_SOD\" > /app/parameter.csv &&
echo \"SDD,$PAR_SDD\" >> /app/parameter.csv && 
echo \"PTCH,$PAR_PTCH\" >> /app/parameter.csv &&
echo \"TTMS,$PAR_TTMS\" >> /app/parameter.csv &&
echo \"STEP,$PAR_STEP\" >> /app/parameter.csv &&
echo \"HIST,$PAR_HIST\" >> /app/parameter.csv &&
echo \"ISTP,$PAR_ISTP\" >> /app/parameter.csv &&
echo \"PNTM,$PAR_PNTM\" >> /app/parameter.csv &&
echo \"BEAM,$PAR_BEAM\" >> /app/parameter.csv &&
cp -f \"$INPFILE.inp\" ./linect.inp &&
echo \"$FFILE\" | ./egs5mpirun"

