set -e

function section() {
    echo "$(tput setaf 6)$@$(tput sgr0)" 1>&2
}

function kpt() {
    ./bin/kpt "$@"
}

PROJECT_ID="$(gcloud config get-value project)"

function setup() {
    gcloud artifacts repositories create --location=us --project=${PROJECT_ID} --repository-format=docker my-blueprints || true
    gcloud artifacts repositories create --location=us --project=${PROJECT_ID} --repository-format=docker my-instances || true
}

function blueprint_clone() {
    rm -r gke

    section "New clone of gke at v0.3.0"
    kpt pkg get https://github.com/GoogleCloudPlatform/blueprints.git/catalog/gke@v0.3.0

    section "Push my-blueprints/gke at v1"
    kpt pkg push gke --origin oci://us-docker.pkg.dev/${PROJECT_ID}/my-blueprints/gke:v1
}

function blueprint_update() {
    rm -r gke

    section "Pull my-blueprints/gke at v1"
    kpt pkg pull oci://us-docker.pkg.dev/${PROJECT_ID}/my-blueprints/gke:v1

    section "Jump to the upstream's main version"
    kpt pkg update gke@main

    section "Push my-blueprints/gke at v2"
    kpt pkg push gke --increment
}

function instance_clone() {
    rm -r sales-cluster

    section "New instance named sales-cluster based on my copy of gke"
    kpt pkg get oci://us-docker.pkg.dev/${PROJECT_ID}/my-blueprints/gke:v1 sales-cluster

    section "Assign origin and push draft copy"
    kpt pkg push sales-cluster@draft --origin oci://us-docker.pkg.dev/${PROJECT_ID}/my-instances/sales-cluster

    section "Push updates to sales-cluster still as draft"
    kpt pkg push sales-cluster

    section "Push updates to sales-cluser at v1 explicitly"
    kpt pkg push sales-cluster@v1

    section "Make a secondary nodepool based on the upstream primary"
    kpt pkg get oci://us-docker.pkg.dev/${PROJECT_ID}/my-blueprints/gke//nodepools/primary:v1 sales-cluster/nodepools/secondary

    section "Push updates to sales-cluser at v2"
    kpt pkg push sales-cluster --increment
}

function instance_update() {
    rm -r sales-cluster

    section "Pulling a copy of sales-cluster at v2"
    kpt pkg pull oci://us-docker.pkg.dev/${PROJECT_ID}/my-instances/sales-cluster:v2

    section "Switching upstream to v2 (note: upstream and origin version are unrelated!)"
    kpt pkg update sales-cluster@v2

    section "Pushing sales-cluster at v3"
    kpt pkg push sales-cluster --increment
}

function compare() {
    rm -r compare
    mkdir -p compare/gke
    mkdir -p compare/sales-cluster

    kpt pkg pull oci://us-docker.pkg.dev/${PROJECT_ID}/my-blueprints/gke:v1 compare/gke/v1
    kpt pkg pull oci://us-docker.pkg.dev/${PROJECT_ID}/my-blueprints/gke:v2 compare/gke/v2
    kpt pkg pull oci://us-docker.pkg.dev/${PROJECT_ID}/my-instances/sales-cluster:v1 compare/sales-cluster/v1
    kpt pkg pull oci://us-docker.pkg.dev/${PROJECT_ID}/my-instances/sales-cluster:v2 compare/sales-cluster/v2
    kpt pkg pull oci://us-docker.pkg.dev/${PROJECT_ID}/my-instances/sales-cluster:v3 compare/sales-cluster/v3

    diff --color=always -r -u10 compare/sales-cluster/v2/ compare/sales-cluster/v3/ | grep --color=always -v '^Only in'

    diff -r -u10 compare/gke/v1/ compare/gke/v2/ | grep -v '^Only in' >compare/gke/v1-v2.diff
    diff -r -u10 compare/sales-cluster/v1/ compare/sales-cluster/v2/ | grep -v '^Only in' >compare/sales-cluster/v1-v2.diff
    diff -r -u10 compare/sales-cluster/v2/ compare/sales-cluster/v3/ | grep -v '^Only in' >compare/sales-cluster/v2-v3.diff
}

function all() {
    setup
    blueprint_clone
    blueprint_update
    instance_clone
    instance_update
    compare
}

"${1-all}"
