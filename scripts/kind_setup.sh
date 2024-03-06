#!/bin/bash

# Function to create kind cluster and setup helm charts
KIND_CREATE_CLUSTER() {
    kind create cluster --config=./kind/kind-cluster.yaml && \
    helm dep up charts/strimzi-kafka-operator && \
    helm dep up charts/traefik && \
    helm dep up charts/cert-manager && \
    export PROJECT_DOMAIN="local.lgc" && \
    helm upgrade --install --create-namespace --namespace cert-manager cert-manager charts/cert-manager --atomic && \
    helm upgrade --install --create-namespace --namespace traefik traefik charts/traefik --atomic && \
    helm upgrade --install --create-namespace --namespace strimzi-kafka-operator strimzi-kafka-operator charts/strimzi-kafka-operator --atomic && \
    kubectl create secret tls root-ca-secret \
      --cert="$(mkcert -CAROOT)/rootCA.pem" \
      --key="$(mkcert -CAROOT)/rootCA-key.pem" \
      --namespace=cert-manager && \
    helm upgrade --install glue ./charts/dev-glue --atomic --set "global.projectDomain=${PROJECT_DOMAIN}" && \
    helm upgrade --install --create-namespace --atomic --namespace keycloak keycloak ./charts/keycloak --set "global.projectDomain=${PROJECT_DOMAIN}"
}

# Function to retrieve secrets for Kafka
KIND_GET_SECRETS() {
    kubectl get secrets kafka-super-user -o jsonpath='{.data.user\.password}' | base64 -d > secrets/kafka/userpass.txt && \
    cat "$(mkcert -CAROOT)/rootCA.pem" > secrets/kafka/ca.crt && \
    kubectl get secrets kafka-super-user -o jsonpath='{.data.ca\.crt}' | base64 -d >> secrets/kafka/ca.crt && \
    kubectl get secrets kafka-super-user -o jsonpath='{.data.user\.p12}' | base64 -d > secrets/kafka/user.p12
}

# Check command line arguments to determine which function to call
if [ "$1" = "create-cluster" ]; then
    KIND_CREATE_CLUSTER
elif [ "$1" = "get-secrets" ]; then
    KIND_GET_SECRETS
else
    echo "Usage: $0 {create-cluster|get-secrets}"
    exit 1
fi