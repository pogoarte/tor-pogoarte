#!/bin/bash
##
clear
echo ""
echo "- This is an simple basic script for install, configure and running a Tor Bridge."
echo ""
echo "- Tested on Debian 11 Bullseye and Ubuntu Server LTS 22.04.3."
echo ""
echo "- Install apt-transport-https, curl, go, gpg, nyx, vnstat, last tor version (add repository torpoject), compile last obfs4proxy version from git and generate config for Tor Bridge."
echo ""
echo "- If your Tor Bridge is behind a FIREWALL or NAT, make sure to open or forward TCP port: ORPort and obfs4proxy."
echo ""
echo ""
echo -n "Press <any_key> to continue or <ctrl+c> for terminate."
read randomkey

if [[ $EUID -ne 0 ]]; then
   echo "!!! This script must be run as root !!!" 
   exit 1
fi

## INSTALL  ##
clear
apt update
apt install -y apt-transport-https curl gpg nyx vnstat
echo "deb     [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $(lsb_release -cs) main" > /etc/apt/sources.list.d/tor.list
echo "deb-src [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $(lsb_release -cs) main" >> /etc/apt/sources.list.d/tor.list
wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null
apt update
apt install -y tor deb.torproject.org-keyring
systemctl stop tor.service
systemctl disable tor.service
mv /etc/tor/torrc /etc/torrc_sample
touch /etc/tor/torrc
sed -i 's/NoNewPrivileges=yes/NoNewPrivileges=no/g' /lib/systemd/system/tor@default.service
sed -i 's/NoNewPrivileges=yes/NoNewPrivileges=no/g' /lib/systemd/system/tor@.service
curl -L https://go.dev/dl/go1.21.6.linux-$(dpkg --print-architecture).tar.gz | tar zxf -
curl -L https://gitlab.com/yawning/obfs4/-/archive/master/obfs4-master.tar.gz | tar zxf -
cd obfs4-master
../go/bin/go build -o obfs4proxy/obfs4proxy ./obfs4proxy
mv obfs4proxy/obfs4proxy /usr/bin
setcap cap_net_bind_service=+ep /usr/bin/obfs4proxy
echo ""
echo -n "Press <any_key> to continue, now create Tor Bridge config."
read randomkey

## CONFIG ##
clear
echo ""
printf 'Please enter your public DNS or IP and press enter (ex: mybridge.dyndns.org or 128.128.128.128):'
read dns_ip
echo ""
printf 'Please enter ORport port. If is behind a FIREWALL or NAT, make sure to open or forward TCP port (ex: 9001):'
read orport_port
echo ""
printf 'Please enter ORport port internet protocol type, if is only IPV4 write "IPv4Only", if is only IPV6 write "IPv6Only", if BOTH leave blank and press enter (ex: IPv4Only):'
read orport_port_type
echo ""
printf 'Please enter obfs4proxy port. If is behind a FIREWALL or NAT, make sure to open or forward TCP port (ex: 9002):'
read obfs4_port
echo ""
printf 'Please enter your Contact Info (ex: john.doe@google.com):'
read contact_info
echo ""
printf 'Please enter your Nickname (ex: JohnDoe):'
read nickname
echo ""
printf 'Please enter BandwidthRate value in KBytes (ex: 1024):'
read band_rate
echo ""
printf 'Please enter BandwidthBurst value in KBytes (ex: 1536):'
read band_brust
echo ""
printf 'Please enter MaxAdvertisedBandwidth value in KBytes (ex: 1280):'
read max_band
echo ""
printf 'Please enter PublishServerDescriptor value. 0 is private and 1 is public (ex: 1):'
read pub_pvt
echo ""
printf 'Please enter BridgeDistribution value and press enter (ex: any):'
read distrb
echo ""
printf 'Used for nyx, write your password for generate HashControlPassword and copy it (ex: my_nyx_control_password):'
read password
tor --hash-password ${password}
echo ""
printf 'Used for nyx, please write your HashControlPassword just generated (ex: 16:55432A...):'
read hash_control_passwd
echo ""
config_file_path="/etc/tor/torrc"
config=$(printf "\
User debian-tor
DataDirectory /var/lib/tor
GeoIPFile /usr/share/tor/geoip
GeoIPv6File /usr/share/tor/geoip6
PidFile /run/tor/tor.pid
Log notice file /var/log/tor/notices.log
SocksPort 0
BridgeRelay 1
RunAsDaemon 1
AvoidDiskWrites 1
ControlPort 9051
#CookieAuthentication 1
#CookieAuthFile /var/lib/tor/control_auth_cookie
#ControlSocket /var/lib/tor/control_socket
HashedControlPassword ${hash_control_passwd}
Address ${dns_ip}
ORPort ${orport_port} ${orport_port_type}
ServerTransportPlugin obfs4 exec /usr/bin/obfs4proxy
ServerTransportListenAddr obfs4 0.0.0.0:${obfs4_port}
ExtORPort auto
ContactInfo ${contact_info}
Nickname ${nickname}
BandwidthRate ${band_rate} KBytes
BandwidthBurst ${band_brust} KBytes
MaxAdvertisedBandwidth ${max_band} KBytes
PublishServerDescriptor ${pub_pvt}
BridgeDistribution ${distrb}
")
echo "${config}" > "${config_file_path}"
echo ""
echo -n "Press <any_key> to continue, now start and ceck tor status."
read randomkey

## START ##
clear
echo ""
systemctl daemon-reload
systemctl enable --now tor.service
systemctl start tor.service
systemctl status tor.service
echo ""
echo -n "Press <any_key> to continue, now see some useful info."
read randomkey

## INFO ##
clear
echo ""
echo "## PATH ##"
echo "/usr/bin                                                                          (bin)"
echo "/etc/tor                                                                          (config)"
echo "/var/lib/tor                                                                      (data)"
echo "/var/log/tor                                                                      (log)"
echo "/usr/share/tor                                                                    (geoip)"
echo ""
echo "## COMMANDS ##"
echo "cat /var/lib/tor/pt_state/obfs4_bridgeline.txt                                    (get bridge line)"
echo "cat /var/lib/tor/fingerprint                                                      (get bridge identify key fingerprint)"
echo "cat /var/log/tor/notices.log                                                      (get bridge hashed identify key fingerprint)"
echo "cat /var/lib/tor/stats/bridge-stats                                               (look bridge stats info)"
echo "nyx                                                                               (tor monitor info)"
echo "vnstat                                                                            (network traffic monitor)"
echo ""
echo "## LINKS ##"
echo "https://metrics.torproject.org/rs.html#details/HASHED_IDENTIFY_KEY_FINGERPRINT    (bridge details info)"
echo "https://bridges.torproject.org/status?id=HASHED_IDENTIFY_KEY_FINGERPRINT          (bridge status info)"
echo "https://bridges.torproject.org/scan                                               (bridge reachability test)"
echo ""
echo -n "Press <any_key> to terminate."
read randomkey

exit 0
