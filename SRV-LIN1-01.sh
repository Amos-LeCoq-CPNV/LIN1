#!/bin/bash

# Demande des noms d'interfaces réseau
read -rp "Entrez le nom de l'interface pour l'accès internet (ex : ens33) : " interface_internet
read -rp "Entrez le nom de l'interface pour le réseau local (ex : ens37) : " interface_local

# Fonction pour configurer les interfaces réseau
config_interfaces() {
    echo "Configuration des interfaces réseau..."
    
    # Ajout des configurations au fichier /etc/network/interfaces
    {
        echo "allow-hotplug $interface_internet"
        echo "iface $interface_internet inet dhcp"
        echo "auto $interface_local"
        echo "iface $interface_local inet static"
        echo "    address 10.10.10.11/24"
    } >> /etc/network/interfaces

    # Vérification de l'écriture dans le fichier
    if [[ $? -ne 0 ]]; then
        echo "Erreur lors de l'écriture dans /etc/network/interfaces" 1>&2
        exit 1
    fi
}

# Fonction pour activer le routage IP
enable_ip_forwarding() {
    echo "Activation du routage IP..."
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf
}

# Fonction pour installer et configurer dnsmasq
install_dnsmasq() {
    echo "Installation de dnsmasq..."
    apt update && apt install -y dnsmasq

    echo "Configuration de dnsmasq..."
    cat <<EOL > /etc/dnsmasq.conf
address=/srv-lin1-01.lin1.local/10.10.10.11
address=/srv-lin1-02.lin1.local/10.10.10.22
address=/nas-lin1-01.lin1.local/10.10.10.33

ptr-record=11.10.10.10.in-addr.arpa.,srv-lin1-01.lin1.local
ptr-record=22.10.10.10.in-addr.arpa.,srv-lin1-02.lin1.local
ptr-record=33.10.10.10.in-addr.arpa.,nas-lin1-01.lin1.local

# DHCP configuration
dhcp-range=10.10.10.110,10.10.10.119,12h
dhcp-option=3,10.10.10.11
dhcp-option=6,10.10.10.11
dhcp-option=15,lin1.local
interface=$interface_local
EOL

    systemctl restart dnsmasq.service
}

# Fonction pour configurer le NAT avec iptables
configure_nat() {
    echo "Configuration du NAT avec iptables..."
    apt install -y iptables iptables-persistent
    iptables -t nat -A POSTROUTING -o $interface_internet -j MASQUERADE
    /sbin/iptables-save > /etc/iptables/rules.v4
}

# Fonction pour configurer le client DHCP
configure_dhcp_client() {
    echo "Configuration du client DHCP..."
    cat <<EOL > /etc/dhcp/dhclient.conf
option rfc3442-classless-static-routes code 121 = array of unsigned integer 8;
send host-name = gethostname();

request subnet-mask, broadcast-address, time-offset, routers,
dhcp6.name-servers, dhcp6.domain-search, dhcp6.fqdn, dhcp6.sntp-servers,
netbios-name-servers, netbios-scope, interface-mtu,
rfc3442-classless-static-routes, ntp-servers;
EOL
}

# Fonction pour configurer le serveur DNS
configure_dns_server() {
    echo "Configuration du serveur DNS..."
    cat <<EOL > /etc/resolv.conf
domain lin1.local
search lin1.local
nameserver 10.10.10.11
nameserver 10.229.60.22
EOL
}

# Fonction pour installer et configurer LDAP
install_ldap() {
    echo "Installation de LDAP..."
    DEBIAN_FRONTEND=noninteractive apt install -y slapd ldap-utils
}

# Fonction pour installer LDAP Account Manager
install_ldap_account_manager() {
    echo "Installation de LDAP Account Manager..."
    apt install -y ldap-account-manager ldap-account-manager-lamdaemon
}

# Fonction pour ajouter un utilisateur LDAP
add_ldap_user() {
    echo "Ajout d'un utilisateur LDAP..."
    cat <<EOL > /tmp/users.ldif
dn: uid=jdoe,ou=People,dc=lin1,dc=local
objectClass: top
objectClass: account
objectClass: posixAccount
objectClass: shadowAccount
cn: John Doe
uid: jdoe
uidNumber: 10000
gidNumber: 10000
homeDirectory: /home/jdoe
loginShell: /bin/bash
gecos: John Doe
userPassword: {crypt}x
shadowLastChange: 0
shadowMax: 0
shadowWarning: 0
EOL

    ldapadd -x -D cn=admin,dc=lin1,dc=local -W -f /tmp/users.ldif
    rm /tmp/users.ldif
}

# Menu de sélection
echo "Choisissez une option d'installation :"
echo "1) Installation complète"
echo "2) Configuration des interfaces réseau"
echo "3) Activation du routage IP"
echo "4) Installation et configuration de dnsmasq"
echo "5) Configuration du NAT avec iptables"
echo "6) Configuration du client DHCP"
echo "7) Configuration du serveur DNS"
echo "8) Installation de LDAP"
echo "9) Installation de LDAP Account Manager"
echo "10) Ajout d'un utilisateur LDAP"
read -rp "Votre choix : " choice

# Exécuter l'option choisie
case $choice in
    1)
        config_interfaces
        enable_ip_forwarding
        install_dnsmasq
        configure_nat
        configure_dhcp_client
        configure_dns_server
        install_ldap
        install_ldap_account_manager
        add_ldap_user
        ;;
    2) config_interfaces ;;
    3) enable_ip_forwarding ;;
    4) install_dnsmasq ;;
    5) configure_nat ;;
    6) configure_dhcp_client ;;
    7) configure_dns_server ;;
    8) install_ldap ;;
    9) install_ldap_account_manager ;;
    10) add_ldap_user ;;
    *)
        echo "Option invalide."
        ;;
esac

echo "Configuration terminée !"
