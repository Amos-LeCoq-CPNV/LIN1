#!/bin/bash

# Variables globales
NEXTCLOUD_VERSION="30.0.0" # Remplacez par la version souhaitée
DB_NAME="nextcloud"
DB_USER="nextclouduser"
DB_PASSWORD="password" # Remplacez par un mot de passe sécurisé
IP_ADDRESS="10.10.10.22"
GATEWAY="10.10.10.11"
NFS_SERVER_IP="10.10.10.33"
NFS_SHARE="/nextcloud"
NFS_MOUNT_POINT="/mnt/data"

# Fonction pour chaque étape de configuration
configure_static_ip() {
    # Demande du nom de l'interface réseau
    read -p "Entrez le nom de l'interface réseau (par exemple ens37, eth0, etc.) : " INTERFACE
    echo "Configuration de l'adresse IP statique pour l'interface $INTERFACE..."

    sudo bash -c "cat > /etc/network/interfaces.d/$INTERFACE.cfg" <<EOF
# Interface $INTERFACE
auto $INTERFACE
iface $INTERFACE inet static
	address $IP_ADDRESS/8
	gateway $GATEWAY
EOF

    sudo systemctl restart networking
    echo "Configuration IP statique terminée pour l'interface $INTERFACE."
}

install_updates() {
    echo "Mise à jour du système..."
    sudo apt update && sudo apt upgrade -y
    echo "Mise à jour terminée."
}

install_apache() {
    echo "Installation du serveur Apache..."
    sudo apt install -y apache2
    echo "Apache installé."
}

install_php() {
    echo "Installation de PHP et extensions nécessaires..."
    sudo apt install -y php libapache2-mod-php php-mysql php-common php-gd php-xml php-mbstring php-zip php-curl php-ldap
    echo "PHP et extensions installés."
}

install_mariadb() {
    echo "Installation de MariaDB..."
    sudo apt install -y mariadb-server mariadb-client
    echo "MariaDB installé."
    
    echo "Configuration de la base de données Nextcloud..."
    sudo mysql -u root -e "CREATE DATABASE $DB_NAME;"
    sudo mysql -u root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
    sudo mysql -u root -e "FLUSH PRIVILEGES;"
    echo "Base de données configurée."
}

install_nextcloud() {
    echo "Téléchargement de Nextcloud..."
    wget https://download.nextcloud.com/server/releases/nextcloud-${NEXTCLOUD_VERSION}.zip -O /tmp/nextcloud.zip
    
    echo "Installation de unzip pour extraire Nextcloud..."
    sudo apt install -y unzip
    
    echo "Extraction de Nextcloud..."
    sudo unzip /tmp/nextcloud.zip -d /var/www/html/
    sudo chown -R www-data:www-data /var/www/html/nextcloud
    echo "Nextcloud installé."
}

configure_external_storage() {
    echo "Configuration du support de stockage externe..."
    echo "Installez l'application 'External storage support' depuis l'interface web de Nextcloud."
    echo "Puis configurez l'accès au stockage via l'application en utilisant les paramètres NFS."
}

restart_services() {
    echo "Redémarrage des services Apache et MariaDB..."
    sudo systemctl restart apache2
    sudo systemctl restart mariadb
    echo "Services redémarrés."
}

# Menu d'options
echo "Sélectionnez les composants à installer/configurer :"
echo "1. Mise à jour du système"
echo "2. Configuration IP statique"
echo "3. Installation d'Apache"
echo "4. Installation de PHP"
echo "5. Installation de MariaDB et configuration de la base de données Nextcloud"
echo "6. Installation de Nextcloud"
echo "7. Configuration du support de stockage externe (via interface Nextcloud)"
echo "8. Redémarrage des services Apache et MariaDB"
echo "9. Installer tous les composants"
echo "Entrez votre choix (numéro ou liste de numéros séparés par des espaces) :"
read -r choices

# Exécution en fonction des choix de l'utilisateur
for choice in $choices; do
    case $choice in
        1) install_updates ;;
        2) configure_static_ip ;;
        3) install_apache ;;
        4) install_php ;;
        5) install_mariadb ;;
        6) install_nextcloud ;;
        7) configure_external_storage ;;
        8) restart_services ;;
        9) 
            install_updates
            configure_static_ip
            install_apache
            install_php
            install_mariadb
            install_nextcloud
            configure_external_storage
            restart_services
            ;;
        *) echo "Choix invalide : $choice" ;;
    esac
done

echo "Installation et configuration terminées."