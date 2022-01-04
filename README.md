# **Auto Scaling Test를 위한 사전 환경 셋팅**

<br>

## **Guide 진행 절차**
> **Auto Scaling동작을 확인하기 위한 Sample Application 배포 및 부하테스트 설정에 대한 가이드 입니다. **

<br>

1. Sample Application은 다음 nodejs이미지를 이용하여 테스트 진행합니다. 
   - quay.io/voravitl/frontend-js:v1

2. Auto Scale을 위한 HPA설정은 다음과 같습니다. 

```bash
...
   spec:
     scaleTargetRef:
       apiVersion: apps/v1
       kind: Deployment
       name: frontend-v1
     minReplicas: 1
     maxReplicas: 3
     metrics:
       - type: Resource
         resource:
           name: cpu
           target:
             averageUtilization: 80
             type: Utilization
     behavior:
       scaleDown:
         stabilizationWindowSeconds: 60
         policies:
         - type: Percent
           value: 100
           periodSeconds: 15
```

3. 다음 shell를 통해 배포 합니다. 

```bash
#!/bin/sh

PRJ_NAME=hpa-nodejs-app

echo -e "\033[32m[S]=============================================================================\033[0m"
echo -e "\033[46m@@@[S]_[AUTO SCALING TEST SETTING]\033[0m"

echo -e "\033[44m[Create Project - ${PRJ_NAME}]\033[0m"
oc new-project ${PRJ_NAME}
oc project ${PRJ_NAME}

oc create -f - -n ${PRJ_NAME}<< EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-v1
  namespace: ${PRJ_NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
      version: v1
  template:
    metadata:
      labels:
        app: frontend
        version: v1
        maistra.io/expose-route: "true"
    spec:
      containers:
      - name: frontend
        image: quay.io/voravitl/frontend-js:v1
        imagePullPolicy: Always
        env:
          - name: BACKEND_URL
            value: http://localhost:8080/version
        resources:
          requests:
            cpu: "0.1"
            memory: 60Mi
          limits:
            cpu: "0.2"
            memory: 100Mi
        ports:
        - containerPort: 8080
      securityContext:
        allowPrivilegeEscalation: false
        runAsNonRoot: true
        drop: ALL
        readOnlyRootFilesystem: true
      terminationGracePeriodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: ${PRJ_NAME}
spec:
  ports:
  - port: 8080
    name: http
    targetPort: 8080
  selector:
    app: frontend
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: frontend
  namespace: ${PRJ_NAME}
spec:
  port:
    targetPort: http
  to:
    kind: Service
    name: frontend
    weight: 100
---
apiVersion: autoscaling/v2beta2
kind: HorizontalPodAutoscaler
metadata:
  name: frontend-cpu
  namespace: ${PRJ_NAME}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend-v1
  minReplicas: 1
  maxReplicas: 3
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          averageUtilization: 80
          type: Utilization
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
EOF

echo -e "\033[36m@@@[E]_[AUTO SCALING TEST SETTING]\033[0m"
echo -e "\033[32m=============================================================================[E]\033[0m"
```

4. 다음 shell를 통해 부하테스트를 수행합니다. (Pod를 통한 부하 주입)

```bash
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
```

   <br>

부하 유입에 따른 auto scaling up/down을 확인 합니다. 
