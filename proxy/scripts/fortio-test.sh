#!/bin/bash

PROXY_SERVER_IP="172.31.16.178"
REAL_SERVER_IP="172.31.23.212"

DATA_DIR="fortio-data"

declare -A proxy_port_map
proxy_port_map["nginx"]="18080"
proxy_port_map["haproxy"]="28080"
proxy_port_map["pipy"]="38080"
proxy_port_map["envoy"]="48080"

echo "${!proxy_port_map[@]}"
echo "${proxy_port_map[@]}"

while getopts "l:h:s:t:d:c:q:" options;
do
  case "${options}" in
    d)
      DURATION=${OPTARG}
      ;;
    l)
      START=${OPTARG}
      ;;
    h)
      END=${OPTARG}
      ;;
    s)
      STEP=${OPTARG}
      ;;
    t)
      PROXY_TYPE=${OPTARG}
      ;;
    c)
      CONNECTIONS=${OPTARG}
      ;;
    q)
      QPS=${OPTARG}
      ;;
    *)
      echo "no args"
      ;;
  esac
done

if [ ! -d $DATA_DIR ]
then
    mkdir $DATA_DIR
fi

cd $DATA_DIR

if [ -n "$CONNECTIONS" ]
then
  COMMAND="fortio load -r 0.0001 -t $DURATION -c $CONNECTIONS "

  if [ ! -d throughput ]
  then
    mkdir throughput
  fi

  cd throughput

  for rate in `seq -w $START $STEP $END`
  do
    CASE=${CONNECTIONS}-${rate}
    echo "Start testing rs...$CASE"
    $COMMAND -labels "rs-${CASE}" -qps ${rate##0} -json rs-${CASE}-${DURATION}.json ${REAL_SERVER_IP}:${REAL_SERVER_PORT:-5678}

    for proxy  in "${!proxy_port_map[@]}"
    do
      if [ "$proxy" != "$PROXY_TYPE" ] && [ "$PROXY_TYPE" != "all" ]
      then
        continue
      fi

      ADDR=${PROXY_SERVER_IP}:"${proxy_port_map[$proxy]}"
      ssh ${PROXY_SERVER_IP} sudo systemctl stop "${!proxy_port_map[@]}"
      sleep 5
      ssh ${PROXY_SERVER_IP} sudo systemctl start $proxy
      sleep 10
      echo "Start testing $proxy...$CASE"

      $COMMAND -labels "${proxy}-${CASE}" -qps $rate -json ${proxy}-${CASE}-${DURATION}.json $ADDR
      sleep 10
    done
  done
fi

if [ -n "$QPS" ]
then
  if [ "x$PROXY_TYPE" = "x" ]
  then
    echo "Need proxy type: nginx, haproxy, pipy, envoy or rs"
    exit 1
  fi

  COMMAND="fortio load -r 0.0001 -t $DURATION -qps $QPS "

  if [ "$PROXY_TYPE" != "rs" ]
  then
    ADDR="${PROXY_SERVER_IP}:${proxy_port_map[$PROXY_TYPE]}"
  else
    ADDR="${REAL_SERVER_IP}:${REAL_SERVER_PORT:-5678}"
  fi

  if [ ! -d connection ]
  then
    mkdir connection
  fi

  cd connection

  ssh ${PROXY_SERVER_IP} sudo systemctl stop "${!proxy_port_map[@]}"
  ssh ${PROXY_SERVER_IP} sudo systemctl start $PROXY_TYPE
  sleep 10

  for conn in `seq -w $START $STEP $END`
  do
      CASE=${conn}-${QPS}
      echo "start testing $ADDR...${CASE}"
      $COMMAND -labels "${PROXY_TYPE}-${CASE}" -c ${conn##0} -json ${PROXY_TYPE}-${CASE}-${DURATION}.json $ADDR
      sleep 10
  done
fi

