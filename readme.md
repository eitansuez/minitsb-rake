# Readme

1. Provision the VM.  See instructions in the terraform subdirectory's [readme file](terraform/readme.md).

1. Ssh onto the VM

    ```shell
    gcloud compute ssh ubuntu@tsb-vm
    ```

1. On the VM, copy `config.yaml.template` to a file name `config.yaml` and edit it as follows:

    a. Under `tsb_repo`, enter your credentials.

    b. Under `clusters`, specify your topology.

1. Before proceeding, check on the status of `cloud-init` to make sure the VM setup is complete:

    ```shell
    cloud-init status
    ```

1. Reload .bashrc

    ```shell
    source .bashrc
    ```

1. Install TSB:

    ```shell
    ./install-tsb.rb
    ```
