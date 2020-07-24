#!/bin/sh
# Luke's Auto Rice Boostrapping Script (LARBS)
# by Luke Smith <luke@lukesmith.xyz>
# License: GNU GPLv3

### OPTIONS AND VARIABLES ###

while getopts ":a:r:b:p:h" o; do case "${o}" in
	h) printf "Optional arguments for custom use:\\n  -r: Dotfiles repository (local file or url)\\n  -p: Dependencies and programs csv (local file or url)\\n  -a: AUR helper (must have pacman-like syntax)\\n  -h: Show this message\\n" && exit ;;
	r) dotfilesrepo=${OPTARG} && git ls-remote "$dotfilesrepo" || exit ;;
	b) repobranch=${OPTARG} ;;
	p) progsfile=${OPTARG} ;;
	a) aurhelper=${OPTARG} ;;
	*) printf "Invalid option: -%s\\n" "$OPTARG" && exit ;;
esac done

[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/lukesmithxyz/voidrice.git"
[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/usuarioroot/LARBS-es/master/progs.csv"
[ -z "$aurhelper" ] && aurhelper="yay"
[ -z "$repobranch" ] && repobranch="master"
[ -z "$libkey" ] && libkey="https://raw.githubusercontent.com/clearlinux-pkgs/setxkbmap/master/CFDF148828C642A7.pkey"
[ -z "$libgit" ] && libgit="https://aur.archlinux.org/libxft-bgra.git"

### FUNCTIONS ###

if type xbps-install >/dev/null 2>&1; then
	installpkg(){ xbps-install -y "$1" >/dev/null 2>&1 ;}
	grepseq="\"^[PGV]*,\""
elif type apt >/dev/null 2>&1; then
	installpkg(){ apt-get install -y "$1" >/dev/null 2>&1 ;}
	grepseq="\"^[PGU]*,\""
else
	distro="arch"
	installpkg(){ pacman --noconfirm --needed -S "$1" >/dev/null 2>&1 ;}
	grepseq="\"^[PGA]*,\""
fi

error() { clear; printf "ERROR:\\n%s\\n" "$1"; exit;}

welcomemsg() { \
	dialog --title "Bienvenidos!" --msgbox "Bienvenido a la secuencia de comandos de Bootstrapping de Auto-Rice de Luke!\\n\\nEste script instalará automáticamente un escritorio Linux con todas las funciones, que utilizo como mi máquina principal.\\n\\n-Luke" 10 60

	dialog --colors --title "Important Note!" --yes-label "Todo listo!" --no-label "Regresar..." --yesno "Asegúrese de que la computadora que está utilizando tenga actualizaciones pacman actuales y llaveros Arch actualizados.\\n\\nSi no, la instalación de algunos programas podría fallar." 8 70
	}

getuserandpass() { \
	# Prompts user for new username an password.
	name=$(dialog --inputbox "Primero, ingrese un nombre para la cuenta de usuario." 10 60 3>&1 1>&2 2>&3 3>&1) || exit
	while ! echo "$name" | grep "^[a-z_][a-z0-9_-]*$" >/dev/null 2>&1; do name=$(dialog --no-cancel --inputbox "Nombre de usuario no válido. Dé un nombre de usuario que comience con una letra, con solo letras minúsculas, - o _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(dialog --no-cancel --passwordbox "Ingrese una contraseña para esa usuario." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(dialog --no-cancel --passwordbox "Vuelva a escribir la contraseña." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(dialog --no-cancel --passwordbox "Las contraseñas no coinciden.\\n\\nIngrese de nuevo la contraseña." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(dialog --no-cancel --passwordbox "Vuelva a escribir la contraseña." 10 60 3>&1 1>&2 2>&3 3>&1)
	done ;}

usercheck() { \
	! (id -u "$name" >/dev/null) 2>&1 ||
	dialog --colors --title "ADVERTENCIA!" --yes-label "CONTINUAR" --no-label "No espera..." --yesno "El usuario \`$name\` ya existe en este sistema. LARBS se puede instalar para un usuario ya existente, pero \\Zbsobreescribirá\\Zn cualquier configuración/archivos de puntos conflictivos en la cuenta de usuario.\\n\\nLARBS \\Zbno\\Zn sobrescribirá sus archivos de usuario, documentos, videos, etc., así que no te preocupes por eso, solo haz clic en <CONTINUAR> si no te importa que se sobrescriba tu configuración.\\n\\nTenga en cuenta también que LARBS cambiará la contraseña de "$name" a la que acaba de dar." 14 70
	}

preinstallmsg() { \
	dialog --title "Empecemos!" --yes-label "Vamos!" --no-label "No, espera...!" --yesno "El resto de la instalación ahora será totalmente automatizado, para que pueda sentarse y relajarse..\\n\\nTomará algo de tiempo, pero cuando haya terminado, podra relajarse aún más con su sistema completa.\\n\\nAhora solo presione <Vamos!> y el sistema comenzará la instalación!" 13 60 || { clear; exit; }
	}

adduserandpass() { \
	# Adds user `$name` with password $pass1.
	dialog --infobox "Agregando usuario... \"$name\"..." 4 50
	useradd -m -g wheel -s /bin/bash "$name" >/dev/null 2>&1 ||
	usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	repodir="/home/$name/.local/src"; mkdir -p "$repodir"; chown -R "$name":wheel $(dirname "$repodir")
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2 ;}

refreshkeys() { \
	dialog --infobox "Refrescando el Llavero de Arch..." 4 40
	pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1
	}

newperms() { # Set special sudoers settings for install (or after).
	sed -i "/#LARBS/d" /etc/sudoers
	echo "$* #LARBS" >> /etc/sudoers ;}

manualinstall() { # Installs $1 manually if not installed. Used only for AUR helper here.
	[ -f "/usr/bin/$1" ] || (
	dialog --infobox "Instalando \"$1\", un ayudante de AUR..." 4 50
	cd /tmp || exit
	rm -rf /tmp/"$1"*
	curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/"$1".tar.gz &&
	sudo -u "$name" tar -xvf "$1".tar.gz >/dev/null 2>&1 &&
	cd "$1" &&
	sudo -u "$name" makepkg --noconfirm -si >/dev/null 2>&1
	cd /tmp || return) ;}

maininstall() { # Installs all needed programs from main repo.
	dialog --title "LARBS Instalación" --infobox "Instalando \`$1\` ($n de $total). $1 $2" 5 70
	installpkg "$1"
	}

gitmakeinstall() {
	progname="$(basename "$1" .git)"
	dir="$repodir/$progname"
	dialog --title "LARBS Instalación" --infobox "Instalando \`$progname\` ($n of $total) vía \`git\` y \`make\`. $(basename "$1") $2" 5 70
	sudo -u "$name" git clone --depth 1 "$1" "$dir" >/dev/null 2>&1 || { cd "$dir" || return ; sudo -u "$name" git pull --force origin master;}
	cd "$dir" || exit
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return ;}

aurinstall() { \
	dialog --title "LARBS Instalación" --infobox "Instalando \`$1\` ($n of $total) de el AUR. $1 $2" 5 70
	echo "$aurinstalled" | grep "^$1$" >/dev/null 2>&1 && return
	sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
	}

pipinstall() { \
	dialog --title "LARBS Instalación" --infobox "Instalando el paquete Python \`$1\` ($n of $total). $1 $2" 5 70
	command -v pip || installpkg python-pip >/dev/null 2>&1
	yes | pip install "$1"
	}

installationloop() { \
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" | sed '/^#/d' | eval grep "$grepseq" > /tmp/progs.csv
	total=$(wc -l < /tmp/progs.csv)
	aurinstalled=$(pacman -Qqm)
	while IFS=, read -r tag program comment; do
		n=$((n+1))
		echo "$comment" | grep "^\".*\"$" >/dev/null 2>&1 && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case "$tag" in
			"A") aurinstall "$program" "$comment" ;;
			"G") gitmakeinstall "$program" "$comment" ;;
			"P") pipinstall "$program" "$comment" ;;
			*) maininstall "$program" "$comment" ;;
		esac
	done < /tmp/progs.csv ;}

putgitrepo() { # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
	dialog --infobox "Descargando e instalando archivos de configuración..." 4 60
	[ -z "$3" ] && branch="master" || branch="$repobranch"
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2"
	chown -R "$name":wheel "$dir" "$2"
	sudo -u "$name" git clone --recursive -b "$branch" --depth 1 "$1" "$dir" >/dev/null 2>&1
	sudo -u "$name" cp -rfT "$dir" "$2"
	}

installlibkey() {
	dialog --infobox "Descargando la llave para instalar libxft-bgra..." 4 60
	([ -f "$libkey" ] && cp "$libkey" /tmp/lib.pkey)  || curl -Ls "$libkey" | sed '/^#/d' > /tmp/lib.pkey
	gpg --input /tmp/lib.pkey
	return;
}

systembeepoff() { dialog --infobox "Deshaciendoce de ese pitido de error retardado.." 10 50
	rmmod pcspkr
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;}

finalize(){ \
	dialog --infobox "Preparando mensaje de bienvenida..." 4 50
	dialog --title "Todo Completo!" --msgbox "Felicidades! Con que no haya habido errores ocultos, la secuencia de comandos se completó correctamente y todos los programas y archivos de configuración deben estar en su lugar.\\n\\nPara ejecutar el nuevo entorno gráfico, cierre la sesión y vuelva a iniciarlo como su nuevo usuario, luego ejecute el comando \"startx\" para iniciar el entorno gráfico (se iniciará automáticamente en tty1).\\n\\n.t Luke" 12 80
	}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Check if user is root on Arch distro. Install dialog.
installpkg dialog || error "¿Estás seguro de que estás ejecutando esto como usuario root y tienes conexión a Internet?"

# Welcome user and pick dotfiles.
welcomemsg || error "Usuario salido."

# Get and verify username and password.
getuserandpass || error "Usuario salido."

# Give warning if user already exists.
usercheck || error "Usuario salido."

# Last chance for user to back out before install.
preinstallmsg || error "Usuario salido."

### The rest of the script requires no user input.

adduserandpass || error "Error al agregar nombre de usuario y/o contraseña."

# Refresh Arch keyrings.
refreshkeys || error "Error al actualizar automáticamente el llavero Arch. Considera hacerlo manualmente."

dialog --title "LARBS Instalación" --infobox "Instalando \`basedevel\` y \`git\` para instalar otro software requerido para la instalación de otros programas." 5 70
installpkg curl
installpkg base-devel
installpkg git
installpkg ntp

dialog --title "LARBS Instalación" --infobox "Sincronización del tiempo del sistema para garantizar la instalación exitosa y segura del software..." 4 70
ntpdate 0.us.pool.ntp.org >/dev/null 2>&1

[ "$distro" = arch ] && { \
	[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case

	# Allow user to run sudo without password. Since AUR programs must be installed
	# in a fakeroot environment, this is required for all builds with AUR.
	newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

	# Make pacman and yay colorful and adds eye candy on the progress bar because why not.
	grep "^Color" /etc/pacman.conf >/dev/null || sed -i "s/^#Color$/Color/" /etc/pacman.conf
	grep "ILoveCandy" /etc/pacman.conf >/dev/null || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf

	# Use all cores for compilation.
	sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

	manualinstall $aurhelper || error "Error al instalar el ayudante de AUR."
	}

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installationloop
installlibkey

dialog --title "LARBS Instalación" --infobox "Finalmente instalando \`libxft-bgra\` para habilitar emoji de color en suckless software sin errores." 5 70
yes | sudo -u "$name" $aurhelper -S libxft-bgra >/dev/null 2>&1

# Install the dotfiles in the user's home directory
putgitrepo "$dotfilesrepo" "/home/$name" "$repobranch"
rm -f "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/FUNDING.yml"
# make git ignore deleted LICENSE & README.md files
git update-index --assume-unchanged "/home/$name/README.md"
git update-index --assume-unchanged "/home/$name/LICENSE"

# Most important command! Get rid of the beep!
systembeepoff

# Make zsh the default shell for the user.
chsh -s /bin/zsh $name >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"

# dbus UUID must be generated for Artix runit.
dbus-uuidgen > /var/lib/dbus/machine-id

# Block Brave autoupdates just in case. (I don't know if these even exist on Linux, but whatever.)
grep -q "laptop-updates.brave.com" /etc/hosts || echo "0.0.0.0 laptop-updates.brave.com" >> /etc/hosts

# Start/restart PulseAudio.
killall pulseaudio; sudo -u "$name" pulseaudio --start

# This line, overwriting the `newperms` command above will allow the user to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
[ "$distro" = arch ] && newperms "%wheel ALL=(ALL) ALL #LARBS
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/yay,/usr/bin/pacman -Syyuw --noconfirm"

# Last message! Install complete!
finalize
clear
