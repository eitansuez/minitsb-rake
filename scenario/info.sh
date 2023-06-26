#!/usr/bin/env bash

# Colors
end="\033[0m"
greenb="\033[1;32m"
lightblueb="\033[1;36m"

function print_info {
  echo -e "${greenb}${1}${end}"
}
function print_command {
  echo -e "${lightblueb}${1}${end}"
}

print_command "vcluster connect t1"
print_command "export T1_GW_IP=\$(kubectl get svc -n tier1 tier1-gateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')\n"

print_command "vcluster connect c1"
print_command "export C1_GW_IP=\$(kubectl get svc -n bookinfo tsb-gateway-bookinfo --output jsonpath='{.status.loadBalancer.ingress[0].ip}')\n"

print_command "vcluster connect c2"
print_command "export C2_GW_IP=\$(kubectl get svc -n bookinfo tsb-gateway-bookinfo --output jsonpath='{.status.loadBalancer.ingress[0].ip}')\n"

echo "sample call to the productpage through the C1 gateway:"
print_command "curl -I --resolve \"bookinfo.tetrate.com:80:\${C1_GW_IP}\" http://bookinfo.tetrate.com/productpage\n"

echo "sample call to the productpage through the T1 gateway:"
print_command "curl -I --resolve \"bookinfo.tetrate.com:80:\${T1_GW_IP}\" http://bookinfo.tetrate.com/productpage\n"

echo "generate a load against the application:"
print_command "while true; do
  curl -I --resolve \"bookinfo.tetrate.com:80:\${T1_GW_IP}\" http://bookinfo.tetrate.com/productpage
  sleep 0.5
done\n"
