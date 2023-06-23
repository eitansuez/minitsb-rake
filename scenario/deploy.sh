#!/usr/bin/env bash

function wait_clusters_onboarded {
  for cluster in t1 c1 c2; do
    echo "Wait for cluster ${cluster} to be onboarded"
    while ! tctl experimental status cluster ${cluster} | grep "Cluster onboarded" &>/dev/null ; do
      sleep 5
      echo -n "."
    done
    echo "DONE"
  done
}

tctl apply -f clusters.yaml
wait_clusters_onboarded

tctl apply -f tenant.yaml

vcluster connect t1
kubectl apply -f t1-manifest.yaml

for cluster in c1 c2; do
  vcluster connect ${cluster}
  kubectl apply -f workload-manifest.yaml
  kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml
  kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/master/samples/sleep/sleep.yaml
done

tctl apply -f workspaces.yaml
tctl apply -f groups.yaml
tctl apply -f gateways.yaml

vcluster disconnect
