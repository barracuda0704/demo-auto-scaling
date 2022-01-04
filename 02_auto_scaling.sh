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
