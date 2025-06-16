#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}Este script puede realizar las siguientes acciones:${NC}"
echo "1. Agregar usuario sysdop y configurar contraseña."
echo "2. Agregar sysdop al grupo root, wheel y sysdop."
echo "3. Actualizar el sistema."
echo "4. Instalar paquetes adicionales."
echo "5. Configurar archivos del sistema."
echo "6. Bloquear la modificación del archivo resolv.conf."
echo "7. Eliminar paquetes específicos."
echo "8. Eliminar repositorios y configurar repos según instrucciones."
echo "9. Desbloquear la modificación del archivo resolv.conf."
echo "10. Instalar cPanel y activar network-scripts."

actions="1 2 3 4 5 6 7 8"
read -p "Ingrese los números de las acciones que desea realizar, separadas por espacios (por defecto, todas excepto 9 y 10): " input_actions
if [ ! -z "$input_actions" ]; then
    actions=$input_actions
fi

echo -e "${YELLOW}Se realizarán las siguientes acciones:${NC} $actions"

for action in $actions
do
    case $action in
        1)
            useradd sysdop
            echo -e "${YELLOW}Se ha creado el usuario sysdop.${NC}"
            passwd sysdop
            ;;
        2)
            usermod -aG root,wheel,sysdop sysdop
            echo -e "${YELLOW}Se ha agregado el usuario sysdop a los grupos root, wheel y sysdop.${NC}"
            ;;
        3)
            yum -y install epel-release
            yum -y update
            echo -e "${YELLOW}El sistema ha sido actualizado.${NC}"
            ;;
        4)
            yum install -y nano wget perl perl-core psmisc mlocate iftop htop nload screen sudo socat zip unzip tar curl net-tools bind-utils telnet
            echo -e "${YELLOW}Se han instalado los paquetes adicionales.${NC}"
            ;;
        5)
            wget -4 repo.sysdop.com/sshd_config -O /etc/ssh/sshd_config
            wget -4 repo.sysdop.com/sysctl.conf -O /etc/sysctl.conf
            sysctl -p
            systemctl restart sshd
            echo -e "${YELLOW}Se han configurado los archivos del sistema.${NC}"
            ;;
        6)
            chattr +a +i /etc/resolv.conf
            echo -e "${YELLOW}Se ha bloqueado la modificación del archivo resolv.conf.${NC}"
            ;;
        7)
            read -p "¿Desea eliminar paquetes específicos? (fire*, irq*, abr*, selinux*) (S/n): " remove_choice
            if [[ $remove_choice =~ ^[Ss]$ ]]; then
                yum remove -y fire* irq* abr* selinux*
                echo -e "${YELLOW}Se han eliminado los paquetes específicos.${NC}"
            fi
            ;;
        8)
            cd /etc/yum.repos.d/ && rm -rf almalinux-*.repo *.rpmnew *.rpmsave; cd ~
            echo -e "${YELLOW}Se han eliminado los repositorios y archivos .rpmnew y .rpmsave.${NC}"
            echo -e "${YELLOW}Creando repositorios actualizados.${NC}"

cat > /etc/yum.repos.d/almalinux.repo <<'EOF'
[baseos]
name=AlmaLinux $releasever - BaseOS
mirrorlist=https://mirrors.almalinux.org/mirrorlist/$releasever/baseos
enabled=1
gpgcheck=1
countme=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[appstream]
name=AlmaLinux $releasever - AppStream
mirrorlist=https://mirrors.almalinux.org/mirrorlist/$releasever/appstream
enabled=1
gpgcheck=1
countme=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[extras]
name=AlmaLinux $releasever - Extras
mirrorlist=https://mirrors.almalinux.org/mirrorlist/$releasever/extras
enabled=1
gpgcheck=1
countme=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux
EOF

cat > /etc/yum.repos.d/epel.repo <<'EOF'
[epel]
name=Extra Packages for Enterprise Linux 9 - $basearch
metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-9&arch=$basearch
enabled=1
gpgcheck=1
countme=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-9
EOF

cat > /etc/yum.repos.d/almalinux-crb.repo <<'EOF'
[crb]
name=AlmaLinux 9 - CRB
mirrorlist=https://mirrors.almalinux.org/mirrorlist/9/crb
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux
EOF

# Limpiar y regenerar caché
dnf clean all
dnf makecache -y

# Habilitar CRB formalmente por si algún paquete lo requiere vía 'config-manager'
dnf install -y dnf-plugins-core
dnf config-manager --set-enabled crb

echo -e "${YELLOW}Repositorios configurados para AlmaLinux 9 (BaseOS, AppStream, Extras, EPEL, CRB habilitado).${NC}"
;;

9)
            read -p "¿Desea desbloquear la modificación del archivo resolv.conf? (s/N): " unlock_choice
            if [[ $unlock_choice =~ ^[Ss]$ ]]
            then
                chattr -a -i /etc/resolv.conf
                echo -e "${YELLOW}Se ha desbloqueado la modificación del archivo resolv.conf.${NC}"
            fi
            ;;

10)
    read -p "¿Desea instalar cPanel y preparar la red en AlmaLinux 9? (s/N): " cpanel_choice
    if [[ $cpanel_choice =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Configurando repositorios compatibles...${NC}"
        rm -f /etc/yum.repos.d/almalinux-powertools.repo
        dnf install -y epel-release dnf-utils
        dnf config-manager --enable crb || echo -e "${RED}CRB no habilitado automáticamente, revisa repos.${NC}"
        echo -e "${YELLOW}Corrigiendo preferencia de red a IPv4...${NC}"
        echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf
        echo -e "${YELLOW}Configurando DNS...${NC}"
        chattr -i /etc/resolv.conf
        echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" > /etc/resolv.conf
        ping -4 -c 2 google.com || { echo -e "${RED}Sin conectividad IPv4. Abortando.${NC}"; exit 1; }
        echo -e "${YELLOW}Descargando e instalando cPanel...${NC}"
        cd /home && curl -o latest -L http://securedownloads.cpanel.net/latest && sh latest
        rm -f /home/latest /root/latest
        echo -e "${GREEN}Instalación de cPanel finalizada.${NC}"
    fi
    ;;

        *)
            echo -e "${RED}Opción inválida.${NC}"
            ;;
    esac
done

echo -e "${GREEN}El script ha finalizado.${NC}"
