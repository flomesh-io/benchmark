#!/bin/bash

thread=$1
connection=$2
rate=$3
duration=$4

PROXY_IP=""
REAL_SERVER_IP=""

SCHEME="http"
REAL_SERVER_PORT=5678

PROXY_ADDR="${SCHEME}://${PROXY_IP}"
REAL_SERVER_ADDR="http://${REAL_SERVER_IP}:${REAL_SERVER_PORT}"

# wrk -t2 -c256 -d5m -R512 --latency http://server:38080 | tee pipy-2-256-512-5m.report

PLAN="${thread}-${connection}-${rate}-${duration}"
if [ ! -d "latency-${PLAN}" ]
then
	mkdir "latency-${PLAN}"
fi

SUFFIX="${thread}-${connection}-${rate}-${duration}.report"
NGINX_SERVER="${PROXY_ADDR}:18080"
HAPROXY_IP="${PROXY_ADDR}:28080"
PIPY_SERVER="${PROXY_ADDR}:38080"
ENVOY_SERVER="${PROXY_ADDR}:48080"

echo "testing rs..."
wrk -t ${thread} -c ${connection} -R ${rate} -d ${duration} --latency ${REAL_SERVER_ADDR} | tee "latency-${PLAN}/rs-${PLAN}.report"
sleep 10

ssh ${PROXY_IP} sudo systemctl stop nginx
ssh ${PROXY_IP} sudo systemctl stop haproxy
ssh ${PROXY_IP} sudo systemctl stop pipy
ssh ${PROXY_IP} sudo systemctl stop envoy


echo "testing nginx..."
ssh ${PROXY_IP} sudo systemctl start nginx
wrk -t ${thread} -c ${connection} -R ${rate} -d ${duration} --latency ${NGINX_SERVER} | tee "latency-${PLAN}/nginx-${PLAN}.report"
sleep 60

ssh ${PROXY_IP} sudo systemctl stop nginx
ssh ${PROXY_IP} sudo systemctl start haproxy

echo "testing haproxy..."
wrk -t ${thread} -c ${connection} -R ${rate} -d ${duration} --latency ${HAPROXY_IP} | tee "latency-${PLAN}/haproxy-${PLAN}.report"
sleep 60

ssh ${PROXY_IP} sudo systemctl stop haproxy

echo "start pipy"
ssh ${PROXY_IP} sudo systemctl start pipy
sleep 10
echo "testing pipy..."
wrk -t ${thread} -c ${connection} -R ${rate} -d ${duration} --latency ${PIPY_SERVER} | tee "latency-${PLAN}/pipy-${PLAN}.report"
sleep 60

ssh ${PROXY_IP} sudo systemctl stop pipy

echo "start envoy"
ssh ${PROXY_IP} sudo systemctl start envoy
sleep 10
echo "testing envoy..."
wrk -t ${thread} -c ${connection} -R ${rate} -d ${duration} --latency ${ENVOY_SERVER} | tee "latency-${PLAN}/envoy-${PLAN}.report"
sleep 10

ssh ${PROXY_IP} sudo systemctl stop envoy
ssh ${PROXY_IP} sudo systemctl start nginx

echo "Done"

./latency-report.py --list latency-${PLAN}/*.report || exit 1

echo "Result export to: latency-${PLAN}/latency-${PLAN}.html"
