# Progressive Infrastructure Delivery using Kargo and Argo CD

This repository contains the code for my talk "Progressive Infrastructure Delivery using Kargo and Argo CD"

### Abstract

Since the day Kargo was released, I have been exploring the idea of using it not only to deliver and promote
applications but also to deliver infrastructure through its progressive delivery capabilities. Using Kubernetes-based
tools like Crossplane or Pulumi, we can define infrastructure as code and deliver it progressively to our management
clusters and then promote this infrastructure through different stages without the need for extra CD script magic.

Let me show you how Kargo helps platform engineering streamline and automate the progressive rollout of infrastructure
changes to all stages. This talk will cover the basics of Kargo and how to use it with Infrastructure as Code tools.

### Installation

##### Install Kind

```shell
kind create cluster \
  --wait 120s \
  --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: kargo-quickstart
nodes:
- extraPortMappings:
  - containerPort: 31443 # Argo CD dashboard
    hostPort: 31443
  - containerPort: 31444 # Kargo dashboard
    hostPort: 31444  
EOF
```

##### Install Kargo

```shell
helm upgrade -i cert-manager cert-manager \
  --repo https://charts.jetstack.io \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --wait

helm upgrade -i argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --namespace argocd \
  --create-namespace \
  --set 'configs.secret.argocdServerAdminPassword=$2a$10$5vm8wXaSdbuff0m9l21JdevzXBzJFPCi8sy6OOnpZMAG.fOXL7jvO' \
  --set dex.enabled=false \
  --set notifications.enabled=false \
  --set server.service.type=NodePort \
  --set server.service.nodePortHttp=31443 \
  --set server.extensions.enabled=true \
  --set "server.extensions.extensionList[0].name=rollout-extension" \
  --set "server.extensions.extensionList[0].env[0].name=EXTENSION_URL" \
  --set "server.extensions.extensionList[0].env[0].value=https://github.com/argoproj-labs/rollout-extension/releases/download/v0.3.4/extension.tar"
  --wait

helm upgrade -i argo-rollouts argo-rollouts \
  --repo https://argoproj.github.io/argo-helm \
  --create-namespace \
  --namespace argo-rollouts \
  --wait

helm upgrade -i kargo \
  oci://ghcr.io/akuity/kargo-charts/kargo \
  --namespace kargo \
  --create-namespace \
  --set api.service.type=NodePort \
  --set api.service.nodePort=31444 \
  --set api.adminAccount.passwordHash='$2a$10$Zrhhie4vLz5ygtVSaif6o.qN36jgs6vjtMBdM6yrU1FOeiAAMMxOm' \
  --set api.adminAccount.tokenSigningKey=iwishtowashmyirishwristwatch \
  --wait
```

#### Install Crossplane and Pulumi Operator

```shell

helm repo add komodorio https://helm-charts.komodor.io \
  && helm repo update komodorio \
  && helm upgrade -i komoplane komodorio/komoplane --namespace komoplane --create-namespace

helm upgrade -i crossplane \
--namespace crossplane-system \
--create-namespace crossplane-stable/crossplane \
--wait

kubectl create secret generic do-creds  --namespace crossplane-system   --from-literal=credentials='{"token": "dop_xxx"}'

kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-upjet-digitalocean
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-upjet-digitalocean:v0.2.1
EOF

kubectl apply -f - <<EOF
apiVersion: digitalocean.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    secretRef:
      key: credentials
      name: do-creds
      namespace: crossplane-system
    source: Secret
EOF

kubectl apply -f - <<EOF
apiVersion: project.digitalocean.crossplane.io/v1alpha1
kind: Project
metadata:
  name: do-project
spec:
  forProvider:
    name: cp-test
    description: A project to represent test resources
    environment: development
EOF

kubectl create secret generic pulumi-operator-secrets --from-literal=pulumi-access-token=pul-xx --from-literal=do-token=dop_xxx

helm upgrade -i  pulumi-kubernetes-operator oci://ghcr.io/pulumi/helm-charts/pulumi-kubernetes-operator \
  --set "extraEnv[0].name=PULUMI_ACCESS_TOKEN" \
  --set "extraEnv[0].valueFrom.secretKeyRef.key=pulumi-access-token" \
  --set "extraEnv[0].valueFrom.secretKeyRef.name=pulumi-operator-secrets" \
  --set "extraEnv[1].name=DIGITALOCEAN_TOKEN" \
  --set "extraEnv[1].valueFrom.secretKeyRef.key=do-token" \
  --set "extraEnv[1].valueFrom.secretKeyRef.name=pulumi-operator-secrets" \
  --wait
```


#### Usage

```shell
kubectl apply -f setup/kargo-demo.yaml # Create the Kargo demo setup
kubectl apply -f setup/infra-app-set.yaml # Create the Argo CD demo setup
```

Open the Kargo dashboard at https://localhost:31444 and the Argo CD dashboard at https://localhost:31443
