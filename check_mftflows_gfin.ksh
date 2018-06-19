#!/bin/ksh
# Auteur N.GIF
# Date APR 2018

source $HOME/.fonction

DATEI=$(date -I)
export NOM_SCRIPT=check_mftflows_gfin.sh
export LOGFILE=MFT_GFIN_${DATEI}.err
export JOURNAL=journal
FIN=0

DEBUT

MADRE_LOG=$LST/server_madre.log_${DATEI}
MFT_ROOT=/home/madre/appli/mft
MFT_FLOWS=$MFT_ROOT/flows
FLOW_FILE=$MFT_FLOWS/flows.${DATEI}.csv
MFT_OUT=$MFT_ROOT/out

LOG "HOSTNAME      -> $(hostname)"

# Determine what is the environment
case $(echo $(hostname)|cut -c '3-4') in
  re) LOG "ENVIRONMENT   -> RECETTE"
      ENV='R';;
  in) LOG "ENVIRONMENT   -> INTEGRATION"
      ENV='I';;
  pr) LOG "ENVIRONMENT   -> PRODUCTION"
      ENV='P';;
  *)  LOG "ENVIRONMENT   -> NOT FOUND"
      ENV='[RIP]'
esac

LOG

# Check if flow file exists
if [ ! -r "${FLOW_FILE}" ]
  then
  LOG "ERROR - Flow file not found : ${FLOW_FILE}"
  FIN=101
  f_SORTIE
fi

LOG "INFO  - Reading ${FLOW_FILE} ..."
LOG

for I in $(seq 1 4)
do
  FLOW_NAME=${ENV}300E060A0${I}

  LOG "INFO  - Analyzing flow name ${FLOW_NAME} ..."

  LIST=$(cat ${FLOW_FILE}|grep ${FLOW_NAME}|cut -d\; -f1|uniq)

  if [ -z "${LIST}" ]
  then
    # Check if MADRE sent the files
    if [ -r "${MADRE_LOG}" ]
    then
      if grep -q "${DATEI}.*COPIED TO ${MFT_OUT}/${FLOW_NAME}" ${MADRE_LOG}
      then
        LOG "ERROR - Flow name $FLOW_NAME not found in ${FLOW_FILE}."
        LOG "TODO  - @SUPTEC_MFT: Please check why MFT did not sent files in ${MFT_OUT}/${FLOW_NAME}."
      else
        LOG "ERROR - Flow name $FLOW_NAME not found in ${FLOW_FILE}."
        LOG "TODO  - @SCOPE50_MADRE: Please check why MADRE did not copied files in ${MFT_OUT}/${FLOW_NAME}."
      fi
    else
      LOG "ERROR - Flow name $FLOW_NAME not found in ${FLOW_FILE}."
      LOG "TODO  - @SCOPE50_MADRE: Please check if MADRE copied files in ${MFT_OUT}/${FLOW_NAME}."
    fi
    LOG
    FIN=101
    continue
  fi

  for FLOW_ID in $LIST
  do
    FLOW=$(cat ${FLOW_FILE}|grep ${FLOW_NAME}|grep ${FLOW_ID})

    # Check if SENT
    if echo -e ${FLOW}|grep -qv SENT
    then
      LOG "ERROR - Flow ID ${FLOW_ID} : Not SENT."
      LOG "TODO  - @SUPTEC_MFT: Please check why MFT did not sent files in ${MFT_OUT}/${FLOW_NAME}."
      FIN=101
      continue
    # Check if NACKED
    elif echo -e ${FLOW}|grep -q NEG-ACK-RECEIVED
    then
      LOG "ERROR - Flow ID ${FLOW_ID} : SENT and NEG-ACK-RECEIVED."
      LOG "TODO  - @SCOPE50_MADRE: Please check why the flow has been nacked."
      FIN=101
      continue
    # Check if NOT ACKED
    elif echo -e $FLOW|grep -qv POS-ACK-RECEIVED
    then
      LOG "ERROR - Flow ID ${FLOW_ID} : SENT but no POS-ACK-RECEIVED."
      LOG "TODO  - @SUPTEC_MFT: Please check why sent files did not get acked."
      FIN=101
      continue
    elif echo -e ${FLOW}|grep -q POS-ACK-RECEIVED
    then
      LOG "INFO  - Flow ID ${FLOW_ID} : POS-ACK-RECEIVED."
    fi
  done
  LOG
done

[ $FIN == 0 ] && LOG "INFO  - Completed : Everything is fine."

f_SORTIE
