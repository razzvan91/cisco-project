#!/bin/sh

#Non automated steps
#1. Set an Environment variable to check if the script is run from inside LUXOFT or not
#export INSIDE_LUXOFT='Inside Luxoft. We proceed with the Checkpoint Login'
#
#2. Install the checkpoint firewall authentication in /usr/local/bin/
#sudo install cpfw-login_amd64.bin /usr/local/bin/
#
#3. We need to manually extract the last certificate 
#echo -n | openssl s_client -showcerts -connect dl.k8s.io:443 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > kube.chain.pem
#	We edit it so that only the last one is present in the file and rename the file to luxoft_root_ca.crt


sudo apt-get install curl -y

#Check if we are external or not
if [ -z "$INSIDE_LUXOFT" ]; then
	echo "Script ran from external"
else
	echo $INSIDE_LUXOFT
	
	cpfw-login_amd64 --user $1

	CERTIFICATE=/usr/local/share/ca-certificates/luxoft/luxoft_root_ca.crt
		if [ -f CERTIFICATE]; then
			echo "The certificate is present"
		else
			sudo mkdir /usr/local/share/ca-certificates/luxoft/
			sudo cp ~/luxoft_root_ca.crt /usr/local/share/ca-certificates/luxoft/luxoft_root_ca.crt
			sudo update-ca-certificates
			echo "Updated certificates"
		fi
fi

#Check if virtualisation is supported
VIRTUALIZATION_SUPPORTED=$(grep -Ec --color 'vmx|svm' /proc/cpuinfo)
if [ $VIRTUALIZATION_SUPPORTED < 0 ]; then
	echo "No virtualisation supported."
	exit 1
fi
echo "Virtualisation is supported on this machine. Continuing"

#Check if vbox is installed
vboxmanage --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Installing Virtual Box"
    sudo add-apt-repository "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib"

    wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
    wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
    sudo apt-get update
    sudo apt-get install virtualbox-6.0
fi


#Check if kubectl is installed
if [ -z "$(kubectl)" ]; then
    curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.17.0/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
    kubectl version
    # Add below line in ~/.bashrc for persistence
    echo "source <(kubectl completion bash)" >> ~/.bashrc # add autocomplete permanently to your bash shell.
	echo "Finished installing kubectl"
fi

minikube > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Installing minikube"
	curl -Lo minikube https://storage.googleapis.com/minikube/releases/v1.5.2/minikube-linux-amd64 && chmod +x minikube
	sudo mkdir -p /usr/local/bin/
	sudo install minikube /usr/local/bin/
	
	if [ -z "$INSIDE_LUXOFT" ]; then
        echo "We are external"
    else
        echo "We are internal"
		mkdir -p ~/.minikube/files/etc/ssl/certs
        sudo cp /usr/local/share/ca-certificates/luxoft/luxoft_root_ca.crt ~/.minikube/files/etc/ssl/certs
    fi
fi
	minikube start
