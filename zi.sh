#!/bin/bash

echo -e "Updating server"
sudo apt-get update -y
systemctl stop udpmod.service 1> /dev/null 2> /dev/null
echo -e "Downloading UDP Service"
wget https://github.com/apernet/hysteria/releases/download/app/v2.6.5/hysteria-linux-amd64 -O /root/udp/his/udpmod 1> /dev/null 2> /dev/null
chmod +x /root/udp/his/udpmod
mkdir /root/udp/his 1> /dev/null 2> /dev/null
wget https://raw.githubusercontent.com/abcwifi/abcwifi.github.io/refs/heads/master/uzain-zi/config.json -O /root/udp/his/config.json 1> /dev/null 2> /dev/null

read -p " enter your domain: " domain

mkdir -p /root/udp/his
echo "Generating cert files:"

openssl genrsa -out /root/udp/his/udpmod.ca.key 2048
openssl req -new -x509 -days 3650 -key /root/udp/his/udpmod.ca.key -subj "/C=CN/ST=GD/L=SZ/O=Udpmod, Inc./CN=Udpmod Root CA" -out /root/udp/his/udpmod.ca.crt
openssl req -newkey rsa:2048 -nodes -keyout /root/udp/his/udpmod.server.key -subj "/C=CN/ST=GD/L=SZ/O=Udpmod, Inc./CN=${domain}" -out /root/udp/his/udpmod.server.csr
openssl x509 -req -extfile <(printf "subjectAltName=DNS:${domain},DNS:${domain}") -days 3650 -in /root/udp/his/udpmod.server.csr -CA /root/udp/his/udpmod.ca.crt -CAkey /root/udp/his/udpmod.ca.key -CAcreateserial -out /root/udp/his/udpmod.server.crt


sysctl -w net.core.rmem_max=16777216 1> /dev/null 2> /dev/null
sysctl -w net.core.wmem_max=16777216 1> /dev/null 2> /dev/null
cat <<EOF > /etc/systemd/system/udpmod.service
[Unit]
Description=Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/udp/his
ExecStart=/root/udp/his/udpmod -config /root/udp/his/config.json server
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

echo -e "Passwords"
read -p "Enter passwords separated by commas, example: pass1,pass2 (Press enter for Default 'zi'): " input_config

if [ -n "$input_config" ]; then
    IFS=',' read -r -a config <<< "$input_config"
    if [ ${#config[@]} -eq 1 ]; then
        config+=(${config[0]})
    fi
else
    config=("zi")
fi

new_config_str="\"config\": [$(printf "\"%s\"," "${config[@]}" | sed 's/,$//')]"

sed -i -E "s/\"config\": ?\[[[:space:]]*\"zi\"[[:space:]]*\]/${new_config_str}/g" /root/udp/his/config.json


systemctl enable udpmod.service
systemctl start udpmod.service
iptables -t nat -A PREROUTING -i $(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1) -p udp --dport 11000:65000 -j DNAT --to-destination :4667
sudo apt install ufw -y
ufw allow 11000:65000/udp
ufw allow 4667/udp
rm zi.* 1> /dev/null 2> /dev/null
echo -e "Installed"
