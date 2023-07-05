# Readme

This repository is derived from Bart Van Bos' excellent [tsb-single-vm](https://github.com/tetratecx/tsb-single-vm).

The idea is to leverage [rake](https://ruby.github.io/rake/) for provisioning TSB.

For learning Rake, I recommend Jim Weirich's two presentations:

1. [Basic Rake](https://youtu.be/AFPWDzHWjEY)
1. [Power Rake](https://youtu.be/KaEqZtulOus)

## Basic recipe

1. Provision the VM.  See instructions in the terraform subdirectory's [readme file](terraform/readme.md).

1. Ssh onto the VM

    ```shell
    gcloud compute ssh ubuntu@tsb-vm
    ```

1. Before proceeding, check on the status of `cloud-init` to make sure the VM setup is complete:

     ```shell
     cloud-init status
     ```

1. On the VM, copy `config.yaml.template` to a file name `config.yaml` and edit it as follows:

    a. Under `tsb_repo`, enter your credentials.

    b. Select a scenario from the 'scenarios/' subdirectory.  Alternatively [build your own scenario](#scenario-convention).

1. Install tools kubectl, k9s, k3d, istioctl, tctl, vcluster, and step cli:

    ```shell
    ./install-tools.sh
    ```

1. Install TSB:

    ```shell
    rake
    ```

## Scenario convention

Under the `scenarios` directory, create a new directory named after your new scenario.

The contents of your scenario directory must include three files:

1. `topology.yaml`: a list of `clusters`.  For each cluster, at the very least supply a name.  Fields `region` and `zone` are optional, and are useful for specifying locality.  Designate the management plane cluster with `is_mp: true`.  Workload clusters are onboarded by default.  Can optionally specify not to onboard a workload cluster with `onboard_cluster: false`.  See existing scenarios for an example of a topology.

1. `deploy.sh`: a script that applies Kubernetes and TSB resources to build a scenario (deploy an application, configure ingress, etc..).  This script is often accompanied with Kubernetes and TSB yaml files that are applied by the script.  See existing scenarios for an example.

1. `info.sh`: a script that outputs any information you wish the user to have including sample commands to exercise or generate a load against a deployed application.
