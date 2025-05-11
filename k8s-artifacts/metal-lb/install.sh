
oc create namespace metallb-system
oc apply -f metallb-native.yaml
# Add SCC permissions:
oc adm policy add-scc-to-user privileged -n metallb-system -z speaker
oc adm policy add-scc-to-user privileged -n metallb-system -z controller
sleep 160
# Create an IPAddressPool
oc apply -f ipaddresspool.yaml
oc apply -f l2advertisement.yaml