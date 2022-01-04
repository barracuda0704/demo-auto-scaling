#!/bin/sh

ABSOLUTE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PRJ_NAME=hpa-nodejs-app

echo -e "\033[32m[S]=============================================================================\033[0m"
echo -e "\033[46m@@@[S]_[LOAD TESTING]\033[0m"

echo -e "\033[44m[oc command move Project - ${PRJ_NAME}]\033[0m"
oc project ${PRJ_NAME}

FRONTEND_URL="http://$(oc get route frontend -n ${PRJ_NAME} -o jsonpath='{.spec.host}')"

# 40 threads, Duration 3 minutes, Ramp up 30 sec, Ramp down 30 sec
oc run load-test -n ${PRJ_NAME} -i \
--image=loadimpact/k6 --rm=true --restart=Never \
--  run -  < ${ABSOLUTE_PATH}/test-k6.js \
-e URL=$FRONTEND_URL -e THREADS=40 -e DURATION=3m -e RAMPUP=30s -e RAMPDOWN=30s

echo -e "\033[36m@@@[E]_[LOAD TESTING]\033[0m"
echo -e "\033[32m=============================================================================[E]\033[0m"
