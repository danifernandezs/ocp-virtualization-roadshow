#!/usr/bin/env bash

set -o errexit  # exit when a command fails
set -o nounset  # exit when use undeclared variables
set -o pipefail # return the exit code of the last command that threw a non-zero

# Please, provide the ROSA cluster name

echo "Please enter the name of the ROSA cluster:"
read -r rosa_cluster_name

# Cleaning original cluster deployment pods

oc get pods --no-headers=true --all-namespaces --field-selector=status.phase!=Running |sed -r 's/(\S+)\s+(\S+).*/oc --namespace \1 delete pod \2/e'

# Create an additional ROSA machinePool with metal EC2 instances

rosa create machinepools -c "$rosa_cluster_name" \
  --disk-size 300GiB \
  --instance-type c5d.metal \
  --name virtualization \
  --replicas 3 \
  --use-spot-instances yes \
  --spot-max-price 1.45

# Create an additional ROSA machinePool where to deploy ODF

rosa create machinepools -c "$rosa_cluster_name" \
  --disk-size 300GiB \
  --instance-type m5.4xlarge \
  --name odf \
  --replicas 3 \
  --taints=node.ocs.openshift.io/storage="true":NoSchedule

# Deploy GitOps operator

oc apply -f yaml/gitops-operator/namespace.yaml
sleep 2
oc apply -f yaml/gitops-operator/subscription.yaml
oc apply -f yaml/gitops-operator/operatorGroup.yaml
oc apply -f yaml/gitops-operator/sa-cluster-admin.yaml
sleep 60
oc apply -f yaml/gitops-operator/argocd-instance.yaml

# ArgoCD Application Seed

oc apply -f yaml/bootstrap-application.yaml
