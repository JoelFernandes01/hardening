#!/bin/bash
# Variáveis de ambiente
USER="$1"
$USER
SSH="2223"

echo "Esse script foi desenvolvido para ambientes linux usando distribuições Debian ou Ubuntu"
echo "Atualizando pacotes do servidor e instalando o UFW (Uncomplicated Firewall)"
sudo apt update && sudo apt upgrade -y
echo "Instalando o UFW (Uncomplicated Firewall)"
sudo apt install ufw -y
echo "Instalando o Rsyslog no Ubuntu Server"
sudo apt install rsyslog lnav -y

echo "Habilitando o serviço do Rsyslog no Ubuntu Server"
sudo systemctl daemon-reload && sudo systemctl enable --now rsyslog

echo "Criando um novo usuário e incluindo ele no grupo sudo"
sudo adduser $USER --gecos "Nome Completo,TelefoneCelular" --disabled-password
echo "Adicionando $USER ao grupo sudo"
sudo usermod -aG sudo $USER

echo "Desativando login do usuário root via SSH"
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

echo "Melhorias de segurança no arquivo sshd_config"
sudo sed -i 's/X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
sudo sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sudo sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding no/' /etc/ssh/sshd_config
sudo sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
sudo sed -i "s/#Port 22$/Port $SSH/" /etc/ssh/sshd_config
#sudo sed -i "s/^Port 22$/Port $SSH/" /etc/ssh/sshd_config

echo "Ativando o Uncomplicated Firewall"
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "Configurando o Nível de Log de Baixo (LOW) para Médio (MEDIUM)"
sudo ufw logging medium

echo "Configurando regras no UFW"
ufw allow in on lo comment 'Liberando comunicação na interface loopbak'
ufw allow out on lo comment 'Liberando comunicação na interface loopbak'
sudo ufw allow $SSH/tcp comment 'Liberando a porta de acesso SSH'
sudo ufw allow out 53/udp comment 'Liberando a saida para consulta do DNS'
sudo ufw allow out 123/udp comment 'Liberando a saida para sincronismo do NTP'

echo "Liberando (ALLOW) a Saída (OUTGOING) do Protocolo ICMP do UFW no Ubuntu Server"
sed -i '38a\
# ok icmp code for OUTPUT\
-A ufw-before-output -p icmp --icmp-type destination-unreachable -j ACCEPT\
-A ufw-before-output -p icmp --icmp-type time-exceeded -j ACCEPT\
-A ufw-before-output -p icmp --icmp-type parameter-problem -j ACCEPT\
-A ufw-before-output -p icmp --icmp-type echo-request -j ACCEPT\n' /etc/ufw/before.rules
sudo ufw reload

echo "Melhorando a Segurança e Logs Detalhados do TCPWrappers no Ubuntu Server"
# Habilitando detalhes de log´s no TCPWrappers
sed -i '17a\
ALL: ALL: spawn /bin/echo "$(date) | Serviço Remoto %d | Host Remoto %c | Porta Remota %r | Processo Local %p" >> /var/log/hosts-deny.log' /etc/hosts.deny
# Habilitando apenas "sua rede" detalhes de log´s no TCPWrappers
sed -i '10a\
sshd: 192.168.1.0/24: spawn /bin/echo "$(date) | Serviço Remoto %d | Host Remoto %c | Porta Remota %r | Processo Local %p" >> /var/log/hosts-allow.log' /etc/hosts.allow

echo "Instalar o Fail2Ban para proteção a acesso SSH"
sudo apt install fail2ban -y

echo "Configurando o Fail2ban para proteção de acesso SSH"
sudo tee /etc/fail2ban/jail.local >> /dev/null <<EOL
[sshd]
enabled = true
port = $SSH
logpath = %(sshd_log)s
maxretry = 3
bantime = 3600
EOL
sudo systemctl restart fail2ban

echo "Definindo permissões"
sudo chmod 644 /etc/passwd
sudo chmod 600 /etc/shadow

echo "Ativando atualizações automáticas de segurança"
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure -plow unattended-upgrades -y

echo "Reiniciando os serviços UFW e SSH"
systemctl restart ssh && systemctl restart ufw




