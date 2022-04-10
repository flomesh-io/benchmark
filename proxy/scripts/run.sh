#!/bin/bash

PROXY_SERVER_IP="proxy"
REAL_SERVER_IP="server01"

DATA_DIR="result"

declare -A proxy_port_map
proxy_port_map["nginx"]="18080"
proxy_port_map["haproxy"]="28080"
proxy_port_map["pipy"]="38080"
proxy_port_map["envoy"]="48080"

#echo "${!proxy_port_map[@]}"
#echo "${proxy_port_map[@]}"

function usage() {
    echo "Usage: $0 [-l <floor level QPS> |-u <upper limit QPS> |-s <QPS steps>|-t <proxy type>|-d <duration>|-c <connections>|-q <QPS>]" 1>&2
    echo "       -l <floor level QPS>   Set floor level QPS"
    echo "       -u <upper limit QPS>   Set uppper limit QPS"
    echo "       -s <QPS steps>         QPS steps between each test case"
    echo "       -c <connecitons>       Number of connections"
    echo "       -t <proxy type>        Could be nginx, haproxy, pipy, envoy and all"
    echo "       -d <duration>          Test duration"
    echo "       -q <QPS>               Set QPS"
    echo "       -m <mode>              test proxy with getting different payload size"
    echo ""
    exit 1
}

while getopts "l:u:s:t:d:c:q:m:h" options;
do
  case "${options}" in
    d)
      DURATION=${OPTARG}
      ;;
    l)
      START=${OPTARG}
      ;;
    u)
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
    m)
      MODE=${OPTARG}
      ;;
    *)
      usage
      ;;
  esac
done

if [ ! -d $DATA_DIR ]
then
    mkdir $DATA_DIR
fi

cd $DATA_DIR

if [ -n "$CONNECTIONS" ] && [ x"$MODE" != "x" ]
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
    echo "$COMMAND -labels "rs-${CASE}" -qps ${rate##0} -json rs-${CASE}-${DURATION}.json ${REAL_SERVER_IP}:${REAL_SERVER_PORT:-5678}"

    $COMMAND -labels "rs-${CASE}" -qps ${rate##0} -json rs-${CASE}-${DURATION}.json ${REAL_SERVER_IP}:${REAL_SERVER_PORT:-5678}

    for proxy in "${!proxy_port_map[@]}"
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
      echo "$COMMAND -labels "${proxy}-${CASE}" -qps $rate -json ${proxy}-${CASE}-${DURATION}.json $ADDR"

      $COMMAND -labels "${proxy}-${CASE}" -qps $rate -json ${proxy}-${CASE}-${DURATION}.json $ADDR
      sleep 10
    done
  done
fi

if [ -n "$QPS" ] && [ x"$MODE" != "x" ]
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
      echo "$COMMAND -labels ${PROXY_TYPE}-${CASE} -c ${conn##0} -json ${PROXY_TYPE}-${CASE}-${DURATION}.json $ADDR"

      $COMMAND -labels "${PROXY_TYPE}-${CASE}" -c ${conn##0} -json ${PROXY_TYPE}-${CASE}-${DURATION}.json $ADDR
      sleep 10
  done
fi

if [ "$MODE" = "payload" ]
then
    COMMAND="fortio load -r 0.0001 -t ${DURATION:-1m} -c 32 -httpbufferkb 1025 -qps 0 "
    for payload_size in 1 100 1000
    do
        ADDR=${PROXY_SERVER_IP}:"${proxy_port_map[$PROXY_TYPE]}"
        echo "start testing with payload size: ${payload_size}k..."
        echo "$COMMAND -json ${PROXY_TYPE}-${payload_size}k-${DURATION:-1m}.json $ADDR"
        $COMMAND -labels "${PROXY_TYPE}-${payload_size}k" -json ${PROXY_TYPE}-${payload_size}k-${DURATION:-1m}.json $ADDR/$payload_size
    done
fi
