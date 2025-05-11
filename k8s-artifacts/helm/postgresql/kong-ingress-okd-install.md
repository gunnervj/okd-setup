# Kong Ingress Gateway Installation on OKD (via Helm)

**Date:** 2025-05-11

This guide outlines the steps to install Kong Ingress Gateway on OKD, configure it with MetalLB and HAProxy passthrough, and expose it with custom domains.

---

## ✅ Prerequisites

- OKD cluster up and running
- MetalLB installed and serving IP (e.g., `192.168.122.100`)
- HAProxy running on host (e.g., `blocksafe.home`) for TCP passthrough
- Helm installed
- Namespace: `kong-ingress`

---

## 🚀 Step 1: Create Namespace

```bash
kubectl create namespace kong-ingress
```

---

## 🛠️ Step 2: Install Kong Helm Chart

```bash
helm repo add kong https://charts.konghq.com
helm repo update

helm install kong kong/kong \
  --namespace kong-ingress \
  --set ingressController.installCRDs=false \
  --set controller.ingressClass=kong \
  --set proxy.type=LoadBalancer \
  --set proxy.externalIPs={ "192.168.122.100" } \
  --set proxy.http.enabled=false \
  --set proxy.tls.enabled=true
```

> Replace `192.168.122.100` with your MetalLB IP.

---

## 🔧 Step 3: HAProxy Configuration (TCP passthrough)

On your host machine (`blocksafe.home`), edit `/etc/haproxy/haproxy.cfg`:

```haproxy
frontend https-in
    bind *:443
    mode tcp
    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }

    use_backend kong-gateway if { req_ssl_sni -i grafana.blocksafe.home }
    use_backend kong-gateway if { req_ssl_sni -i kuma.blocksafe.home }
    use_backend kong-gateway if { req_ssl_sni -i auth.blocksafe.home }

    default_backend openshift-console

backend kong-gateway
    mode tcp
    server kong 192.168.122.100:443 check
```

Then reload HAProxy:

```bash
sudo systemctl reload haproxy
```

---

## 🌐 Step 4: Add Local DNS Entries (Mac or local machine)

Edit `/etc/hosts` and add:

```text
192.168.1.58 grafana.blocksafe.home
192.168.1.58 auth.blocksafe.home
192.168.1.58 kuma.blocksafe.home
```

Replace `192.168.1.58` with the IP of your **host machine** running HAProxy.

---

## ✅ Step 5: Verify

- Run: `kubectl get svc -n kong-ingress`
- Visit: `https://grafana.blocksafe.home`, `https://auth.blocksafe.home`, etc.

---

## 🔐 Next Steps

- Add TLS certs in Kong (or terminate at HAProxy)
- Expose internal apps via Kong Ingress
- Secure with OIDC (Keycloak)

