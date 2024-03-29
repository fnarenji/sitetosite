#!/bin/sh

set -o xtrace

if ! [[ -d /app/pki/ ]]; then
    echo "Missing PKI folder."
    exit 1
fi

PK="$(ls /app/pki/private/*.der)"
cp $PK /etc/ipsec.d/private/
cp -Rv /app/pki/certs/* /etc/ipsec.d/certs/
cp -Rv /app/pki/cacerts/* /etc/ipsec.d/cacerts/
echo ": RSA $(basename $PK)" > /etc/ipsec.secrets

cp -v /app/ipsec_client.conf /etc/ipsec.d/
cp -v /app/ipsec_cipher.conf /etc/ipsec.d/
cp -v /app/charon-logging.conf /etc/strongswan.d/charon-logging.conf

CERT="$(cd /app/pki/certs/ && ls *.der | grep -v cloud)"
SUBNET=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | grep -v "10.0")

echo "SUBNET IS $SUBNET"

cat > /etc/ipsec.conf << EOC
include ipsec.d/ipsec_client.conf

conn net
	leftsubnet=$SUBNET/16
    leftcert=$CERT
EOC

INTERNET_IP=$(hostname -i | sed 's/ /\n/g' | grep 10.0)
echo "MY INTERNET IP IS $INTERNET_IP (out of $(hostname -i))"
LAN_IP=$(hostname -i | sed 's/ /\n/g' | grep -v 10.0)
echo "MY LAN IP IS $LAN_IP"

echo "net.ipv4.ip_forward = 1" |  tee -a /etc/sysctl.conf
echo "net.ipv4.conf.all.accept_redirects = 0" |  tee -a /etc/sysctl.conf
echo "net.ipv4.conf.all.send_redirects = 0" |  tee -a /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter = 0" |  tee -a /etc/sysctl.conf
echo "net.ipv4.conf.default.accept_source_route = 0" |  tee -a /etc/sysctl.conf
echo "net.ipv4.conf.default.send_redirects = 0" |  tee -a /etc/sysctl.conf
echo "net.ipv4.icmp_ignore_bogus_error_responses = 1" |  tee -a /etc/sysctl.conf

# for ISAKMP (handling of security associations)
# iptables -A INPUT -p udp --dport 500 --j ACCEPT
# for NAT-T (handling of IPsec between natted devices)
# iptables -A INPUT -p udp --dport 4500 --j ACCEPT
# for ESP payload (the encrypted data packets)
# iptables -A INPUT -p esp -j ACCEPT
# for the routing of packets on the server
# iptables -t nat -A POSTROUTING -j SNAT --to-source $INTERNET_IP -o eth+
# iptables -t nat -A POSTROUTING -s $LAN_IP/24 -o eth0 -m policy \
#     --dir out --pol ipsec -j ACCEPT

for vpn in /proc/sys/net/ipv4/conf/*; do
    echo 0 > $vpn/accept_redirects
    echo 0 > $vpn/send_redirects
done

sysctl -p

./ipt.sh
rm /var/run/starter.charon.pid
rm /var/run/charon.pid
rm l.log
ipsec start --nofork

# ipsec start &
# sleep 1

# echo "OK"

# ipsec up net
# ./ipt.sh
