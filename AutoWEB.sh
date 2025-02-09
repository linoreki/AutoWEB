#!/bin/bash

set -e  # Detener ejecución en caso de error
LOGFILE="/var/log/install_wp_moodle.log"
echo "Inicio de instalación - $(date)" | tee -a $LOGFILE

# Solicitar configuración al usuario
echo "Introduce el nombre de la base de datos de WordPress: "
read WP_DB

echo "Introduce el usuario de la base de datos de WordPress: "
read WP_USER

echo "Introduce la contraseña del usuario de WordPress: "
read WP_PASS

echo "Introduce el nombre de la base de datos de Moodle: "
read MOODLE_DB

echo "Introduce el usuario de la base de datos de Moodle: "
read MOODLE_USER

echo "Introduce la contraseña del usuario de Moodle: "
read MOODLE_PASS

# Actualización del sistema y requisitos
sudo apt update -y | tee -a $LOGFILE
sudo apt install -y software-properties-common | tee -a $LOGFILE

# Agregar repositorio PHP
sudo add-apt-repository ppa:ondrej/php -y | tee -a $LOGFILE
sudo apt update -y | tee -a $LOGFILE

# Instalar paquetes requeridos
sudo apt install -y php8.1 libapache2-mod-php8.1 \
    php8.1-cli php8.1-curl php8.1-xml \
    php8.1-mbstring php8.1-zip php8.1-mysql \
    php8.1-gd php8.1-intl php8.1-soap \
    mysql-server apache2 git unzip | tee -a $LOGFILE

# Habilitar y arrancar servicios
sudo systemctl enable --now apache2 mysql | tee -a $LOGFILE

# Configurar MySQL para WordPress y Moodle
sudo mysql <<EOF
CREATE DATABASE $WP_DB;
CREATE USER '$WP_USER'@'localhost' IDENTIFIED BY '$WP_PASS';
GRANT ALL PRIVILEGES ON $WP_DB.* TO '$WP_USER'@'localhost';

CREATE DATABASE $MOODLE_DB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$MOODLE_USER'@'localhost' IDENTIFIED BY '$MOODLE_PASS';
GRANT ALL PRIVILEGES ON $MOODLE_DB.* TO '$MOODLE_USER'@'localhost';

FLUSH PRIVILEGES;
EOF

echo "Base de datos configurada correctamente." | tee -a $LOGFILE

# Descargar e instalar WordPress
wget https://wordpress.org/latest.tar.gz -O /tmp/latest.tar.gz | tee -a $LOGFILE
tar -xvzf /tmp/latest.tar.gz -C /var/www/html/ | tee -a $LOGFILE
sudo chown -R www-data:www-data /var/www/html/wordpress | tee -a $LOGFILE
sudo chmod -R 755 /var/www/html/wordpress | tee -a $LOGFILE

echo "WordPress instalado." | tee -a $LOGFILE

# Configurar Apache
cat <<EOF | sudo tee /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    ServerAdmin admin@example.com
    DocumentRoot /var/www/html
    Alias /wordpress /var/www/html/wordpress
    <Directory /var/www/html/wordpress>
        AllowOverride All
        Require all granted
    </Directory>
    Alias /moodle /var/www/moodle
    <Directory /var/www/moodle>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

echo "Configuración de Apache aplicada." | tee -a $LOGFILE

# Activar módulos y reiniciar Apache
sudo a2ensite wordpress | tee -a $LOGFILE
sudo a2enmod rewrite | tee -a $LOGFILE
sudo systemctl restart apache2 | tee -a $LOGFILE

echo "Apache configurado correctamente." | tee -a $LOGFILE

# Descargar e instalar Moodle
git clone --branch MOODLE_401_STABLE git://git.moodle.org/moodle.git /var/www/moodle | tee -a $LOGFILE
sudo chown -R www-data:www-data /var/www/moodle
sudo chmod -R 755 /var/www/moodle

# Mover moodledata fuera de /var/www
sudo mkdir -p /var/moodledata
sudo chown -R www-data:www-data /var/moodledata
sudo chmod -R 755 /var/moodledata

echo "Moodle instalado." | tee -a $LOGFILE

# Configurar PHP
sudo sed -i 's/^max_input_vars.*/max_input_vars = 5000/' /etc/php/8.1/apache2/php.ini | tee -a $LOGFILE
sudo sed -i 's/^;max_input_vars.*/max_input_vars = 5000/' /etc/php/8.1/apache2/php.ini | tee -a $LOGFILE
sudo echo "opcache.enable=1" >> /etc/php/8.1/apache2/php.ini
sudo echo "opcache.enable_cli=1" >> /etc/php/8.1/apache2/php.ini

sudo systemctl restart apache2 php8.1-fpm 2>/dev/null | tee -a $LOGFILE

echo "PHP configurado." | tee -a $LOGFILE

# Recargar Apache
sudo systemctl reload apache2 | tee -a $LOGFILE

echo "Instalación completada con éxito." | tee -a $LOGFILE

echo "Configuración Final:" | tee -a $LOGFILE
echo "WordPress: http://$(hostname -I | awk '{print $1}')/wordpress" | tee -a $LOGFILE
echo "Moodle: http://$(hostname -I | awk '{print $1}')/moodle" | tee -a $LOGFILE
echo $WP_DB $WP_USER $WP_PASS
echo $MOODLE_DB $MOODLE_USER $MOODLE_PASS
