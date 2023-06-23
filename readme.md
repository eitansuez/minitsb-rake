# Readme

1. Provision the VM (see the terraform subdirectory's readme file)

    ```shell
    cd terraform
    terraform apply
    ```

1. Ssh onto the VM

    ```shell
    gcloud compute ssh ubuntu@tsb-vm
    ```

1. Make a copy of `config.yaml.template` to a file name `config.yaml`.

    a. Under `tsb_repo`, enter your credentials.
    a. Under `clusters`, specify your topology.

1. Install tools

    ```shell
    ./install-tools.sh
    ```

1. Reload .bashrc

    ```shell
    source .bashrc
    ```

1. Install TSB:

    ```shell
    ./install-tsb.rb
    ```
