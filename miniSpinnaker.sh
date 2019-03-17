#!/usr/bin/env bash

minikube start --cpus 4 --cpus 4 --memory 8192

minikube dashboard &

helm init

kubectl rollout status deployment/tiller-deploy --namespace=kube-system -w

helm install --name mino-spinnaker stable/minio

kubectl rollout status deployment/mino-spinnaker-minio --namespace=default -w

# have to embed the certificates into the contex so they are sent into the spinnaker containers
kubectl config set-credentials minikube --client-certificate=$HOME/.minikube/client.crt --client-key=$HOME/.minikube/client.key --embed-certs=true
kubectl config set-cluster minikube --certificate-authority=$HOME/.minikube/ca.crt --embed-certs=true

hal config provider kubernetes enable

CONTEXT=$(kubectl config current-context)

hal config provider kubernetes account add minikube \
    --provider-version v2 \
    --context $CONTEXT

hal config features edit --artifacts true

hal config deploy edit --type distributed --account-name minikube

echo wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY | hal config storage s3 edit --endpoint http://mino-spinnaker-minio.default.svc.cluster.local:9000 \
    --access-key-id AKIAIOSFODNN7EXAMPLE \
    --secret-access-key

hal config storage edit --type s3

hal config canary enable
hal config canary prometheus enable
hal config canary prometheus account add cluster-prom --base-url http://prometheus-k8s.monitoring.svc:9090
hal config canary edit --default-metrics-store prometheus

hal config canary aws enable
echo wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY | hal config canary aws account add aws-mino --endpoint http://mino-spinnaker-minio.default.svc.cluster.local:9000  --access-key-id AKIAIOSFODNN7EXAMPLE --bucket canary  --secret-access-key
hal config canary aws edit --s3-enabled true

hal deploy apply;

git clone --depth 1 git@github.com:coreos/prometheus-operator.git
kubectl apply -f prometheus-operator/contrib/kube-prometheus/manifests

kubectl rollout status deployment/spin-front50 --namespace=spinnaker -w
kubectl rollout status deployment/spin-echo --namespace=spinnaker -w
kubectl rollout status deployment/spin-gate --namespace=spinnaker -w
kubectl rollout status deployment/spin-orca --namespace=spinnaker -w
kubectl rollout status deployment/spin-clouddrive --namespace=spinnaker -w
kubectl rollout status deployment/spin-deck --namespace=spinnaker -w
kubectl rollout status deployment/spin-redis --namespace=spinnaker -w

hal deploy connect &

open http://localhost:9000

kubectl apply -f https://raw.githubusercontent.com/HarryEMartland/minispinnaker/master/job.setup.yaml