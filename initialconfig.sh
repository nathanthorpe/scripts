#!/bin/bash
OS=`lsb_release -si`
if [ "${OS}" = "Debian" ]||[ "${OS}" = "Ubuntu" ]; then
	read -r -p "Would you like to configure the network [Y/n] " response
	case "${response}" in
		[nN][oO]|[nN])
			echo -e "[*] Skipping network configuration"
			;;
		*)
			echo -e "[*] Configuring network"
			IP=`hostname | nslookup | awk '/Address/{i++}i==2' | cut -d' ' -f 2`
			NAMESERVER=`cat /etc/resolv.conf | grep nameserver | cut -d' ' -f 2`
			DOMAIN=`cat /etc/resolv.conf | grep search | cut -d' ' -f 2`
			GATEWAY=`ip route | grep default | cut -d' ' -f 3`
			cat << EOF > /etc/network/interfaces
# Loopback interface
auto lo
iface lo inet loopback
# Primary network interface
auto eth0
iface eth0 inet static
	address $IP
	netmask 255.255.255.0
	gateway $GATEWAY
	dns-nameserver $NAMESERVER
	dns-search $DOMAIN
EOF
			echo "$ Done"
			REBOOT=True
			;;
	esac
	# read -p "Enter the ip address for your server: " staticip
	# read -p "Enter the netmask: " netmask
	# read -p "Enter the IP of gateway: " gateway
	# read -p "Enter the IP of DNS Server: " dns-nameserver dns-search
	# ifconfig eth0 up
	# ifconfig eth0 $staticip netmask $netmask
	# route add default gw $gateway
	echo -e "[*] Configuring ssh"
	echo -e "[*] Adding key"
	if [ -f /root/.ssh/authorized_keys ]; then
		mv /root/.ssh/authorized_keys /root/.ssh/$(date +%Y%m%d%H%M)_authorized_keys
		echo "I've backed up your authorized_keys like this $(date +%Y%m%d%H%M)_authorized_keys"
		echo
	else
		mkdir -p /root/.ssh/
		echo -e "[*] Created .ssh dir."
	fi
	curl -k https://github.com/nathanthorpe.leys >> /root/.ssh/authorized_keys
	echo -e "[*] Nathan's SSH Key added"
	echo -e "[*] Securing ssh"
	echo
	echo "[*] Disabling password auth"
	grep -rl 'UsePAM' /etc/ssh/sshd_config | xargs sed -i 's/*.UsePAM.*/UsePAM no/g';
	echo 3
	grep -rl 'ChallengeResponseAuthentication' /etc/ssh/sshd_config | xargs sed -i 's/*.ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/g';
	echo 2
	grep -rl 'PasswordAuthentication' /etc/ssh/sshd_config  | xargs sed -i 's/*.PasswordAuthentication.*/PasswordAuthentication no/g';
	echo 1
	service ssh restart;
	echo "[*] Done"
	echo -e "[*] Updating apt/packages"
	apt-get update
	apt-get -y upgrade
	echo -e "[*] Installing htop/nano/wget"
	apt-get -y install htop nano wget
	echo -e "[*] Configuring NTP"
	apt-get -y install ntp
	rm /etc/ntp.conf
	echo "server 10.0.0.2" >> /etc/ntp.conf
	service ntp restart
	echo -e "[*] Configuring SNMP"
	read -p "Enter SNMP RO community: " community
	apt-get -y install snmpd
	rm /etc/snmp/snmpd.conf
	cat << EOF > /etc/snmp/snmpd.conf
rocommunity $community 10.0.0.10
syscontact Nathan Thorpe <nathan@techstormpc.com>
syslocation Redmond, WA
extend .1.3.6.1.4.1.2021.7890.1 distro /usr/bin/distro
EOF
	curl https://raw.githubusercontent.com/murrant/librenms/9aa4203cc3423eb29c7b8aff16bef661c32cf977/scripts/distro >> /usr/bin/distro
	chmod +x /usr/bin/distro
	service snmpd restart
	read -r -p "Do you want to install Hyper-V tools [Y/n] " response
	case "${response}" in
		[nN][oO]|[nN])
			echo -e "[*] Not installing Hyper-V tools"
			;;
		*)
			echo -e "[*] Installing Hyper-V Tools"
			echo "hv_vmbus" >> /etc/initramfs-tools/modules
			echo "hv_storvsc" >> /etc/initramfs-tools/modules
			echo "hv_blkvsc" >> /etc/initramfs-tools/modules
			echo "hv_netvsc" >> /etc/initramfs-tools/modules
			if [ "${OS}" = "Debian" ]; then
				apt-get -y install hyperv-daemons
			else
				apt-get -y install --install-recommends linux-tools-virtual-lts-xenial linux-cloud-tools-virtual-lts-xenial
			fi
			update-initramfs -u
			REBOOT=True
			;;
	esac
else
	echo "I can't run this on non-debian based OSes!"
fi
if [ REBOOT ]; then
	echo -e "[*] Rebooting"
	dhclient -r eth0
	reboot
else
	echo "Done"
fi
