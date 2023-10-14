#!/bin/bash

# Create a shared folder called "shared" in this directory
mkdir shared

# Create a Vagrantfile
touch Vagrantfile

# Edit the Vagrantfile
cat <<EOF > Vagrantfile
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-20.04"
  config.vm.synced_folder "shared", "/home/vagrant/shared"

  config.vm.define "master" do |master|
    master.vm.network "private_network", ip: "192.168.77.6"
    master.vm.hostname = "master"
    master.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.cpus = "1"
    end
    master.vm.provision "shell", inline: <<-SHELL
      sudo apt-get update
      sudo apt-get upgrade -y

      # Create a user called altschool with a password and give it sudo privileges
      sudo useradd -m -p \$(openssl passwd -1 altschool) altschool
      sudo usermod -aG sudo altschool

      # Generate an SSH key for the altschool user
      sudo -u altschool ssh-keygen -t rsa -N "" -f /home/altschool/.ssh/id_rsa -C "altschool" -q

      # Copy the public key to the shared folder
      sudo cp /home/altschool/.ssh/id_rsa.pub /home/vagrant/shared/id_rsa.pub || true

      # Install the LAMP stack
      DEBIAN_FRONTEND=noninteractive sudo apt-get install -y apache2 mysql-server php libapache2-mod-php php-mysql

      # Enable the LAMP stack
      sudo systemctl enable apache2 || true
      sudo systemctl enable mysql || true

      # Start the LAMP stack
      sudo systemctl start apache2 || true
      sudo systemctl start mysql || true

      # Secure MySQL installation automatically
      sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password altschool'
      sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password altschool'

      # Create a test PHP page to render the LAMP stack
      sudo echo "<?php phpinfo(); ?>" > /var/www/html/index.php

      # Create a /mnt/altschool directory
      sudo mkdir /mnt/altschool

      # Create a test.txt file in /mnt/altschool
      sudo touch /mnt/altschool/test.txt

      # Create test content in test.txt
      sudo echo "This is a test content" > /mnt/altschool/test.txt

      # Copy the content of /mnt/altschool to the shared folder
      sudo cp -r /mnt/altschool/* /home/vagrant/shared || true

      # Create a cronjob to run ps -aux at every boot
      sudo echo "@reboot root ps -aux > /home/vagrant/shared/ps.txt" > /etc/cron.d/ps

      # Create a page to render the load balancer
      sudo touch /var/www/html/load.html

      sudo echo -e "<!DOCTYPE html>
      <html>
      <head>
      <title>project site</title>
      </head>
      <body>
      <h1>welcome to my project site for altschool cloud engineering projects</h1>
      </body>
      </html>" >> /var/www/html/load.html
    SHELL
  end

  config.vm.define "slave" do |slave|
    slave.vm.network "private_network", ip: "192.168.77.7"
    slave.vm.hostname = "slave"
    slave.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.cpus = "1"
    end
    slave.vm.provision "shell", inline: <<-SHELL
      sudo apt-get update
      sudo apt-get upgrade -y

      # Copy the public key from the shared folder to ~/vagrant/.ssh/authorized_keys
      sudo cp /home/vagrant/shared/id_rsa.pub /home/vagrant/.ssh/authorized_keys || true

      # Remove the public key from the shared folder
      sudo rm /home/vagrant/shared/id_rsa.pub || true

      # Make /mnt/altschool/slave directory
      sudo mkdir -p /mnt/altschool/slave

      # Copy the content of the shared folder to /mnt/altschool/slave
      sudo cp -r /home/vagrant/shared/* /mnt/altschool/slave || true

      # Remove the content of the shared folder
      sudo rm -rf /home/vagrant/shared/* || true

      # Install the LAMP stack
      DEBIAN_FRONTEND=noninteractive sudo apt-get install -y apache2 mysql-server php libapache2-mod-php php-mysql

      # Enable the LAMP stack
      sudo systemctl enable apache2 || true
      sudo systemctl enable mysql || true

      # Start the LAMP stack
      sudo systemctl start apache2 || true
      sudo systemctl start mysql || true

      # Secure MySQL installation automatically
      sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password altschool'
      sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password altschool'

      # Create a test PHP page to render the LAMP stack
      sudo echo "<?php phpinfo(); ?>" > /var/www/html/index.php

      # Create a page to render the load balancer
      sudo touch /var/www/html/load.html

      sudo echo -e "<!DOCTYPE html>
      <html>
      <head>
      <title>project site</title>
      </head>
      <body>
      <h1>welcome to my project site for altschool cloud engineering projects</h1>
      </body>
      </html>" >> /var/www/html/load.html
    SHELL
  end

  config.vm.define "load_balancer" do |load_balancer|
    load_balancer.vm.network "private_network", ip: "192.168.77.8"
    load_balancer.vm.hostname = "load_balancer"
    load_balancer.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.cpus = "1"
    end
    load_balancer.vm.provision "shell", inline: <<-SHELL
      sudo apt-get update
      sudo apt-get upgrade -y

      # Create a load balancer with Nginx
      DEBIAN_FRONTEND=noninteractive sudo apt-get install -y nginx
      sudo systemctl enable nginx || true
      sudo systemctl start nginx || true

      # Remove the default Nginx configuration
      sudo rm /etc/nginx/sites-enabled/default

      # Create a new Nginx configuration
      sudo echo "upstream backend {
        server 192.168.77.6;
        server 192.168.77.7;
      }

      server {
        listen 80;
        location / {
          proxy_pass http://backend;
        }
      }" > /etc/nginx/sites-enabled/default

      # Create a page to render the load balancer
      sudo touch /var/www/html/load.html

      sudo echo -e "<!DOCTYPE html>
      <html>
      <head>
      <title>project site</title>
      </head>
      <body>
      <h1>welcome to my project site for altschool cloud engineering projects</h1>
      </body>
      </html>" >> /var/www/html/load.html

      # Symlink the Nginx configuration
      sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

      # Restart Nginx
      sudo systemctl restart nginx || true
    SHELL
  end
end
EOF

# Start Vagrant
vagrant up
