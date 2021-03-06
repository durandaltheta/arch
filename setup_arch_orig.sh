#!/bin/bash

# Default install execution string for Arch Virtual Machine:
# ./setup_arch -s [/dev/myharddrive] -r [rootpass] --region_city [Region/City] -b -u [username] -p [userpass] -i [net interface] -g --guest --wine 
#
# example:
# ./setup_arch -s /dev/sda -r "fakepass" --region_city "America/Detroit" -b -u duran -p "myfakepass" -i "enp0s3" -g --guest --wine
if [ "$EUID" -ne 0 ];
then 
    echo "Must run as root"
    exit
fi

LOG=~

# use for logging if I get around to it
lecho( )
{
    echo $1
    echo $1 > $LOG
}

USAGE( )
{
    echo "$0 valid arguments"
    echo "   -s|--setup [hard drive to install to]: setup drive and install basic arch linux packages."
    echo "          This must be run from the Arch install iso level."
    echo "   -r|--root_pass [root password]: set the root password (required for --setup)"
    echo "   --region_city [Region/City]: Example \"America/Detroit\" (required for --setup)"
    echo "   -b|--basic: setup basic environment and usability programs"
    echo "   -u|--user [username]"
    echo "   -p|--pass [password]"
    echo "   -i|--interface [network interface]"
    echo "   -g|--gui: install the lxqt gui environment"
    echo "   --gnome: install the default gnome project applications"
    echo "   --gnome_extras: install even more gnome project applications"
    echo "   --wine: install wine staging for windows environment emulations"
    echo "   -v|--vga [intel/amd/nvidia]: install specific graphics drivers"
    echo "   --guest: install virtualbox guest utilities to install a bunch of drivers for a guest Arch VM"
    echo "   -l|--log [log path/name]: set the logfile #CURRENTLY A STUB"
    echo ""
    echo "example usage"
    echo "-------------"
    echo "\tfrom arch linux install iso welcome terminal:"
    echo "\t$ ./setup_arch -r [root password] -s /dev/sda"
    echo "\t$ arch-chroot /mnt /setup_arch -s /dev/sda -u duran -p [duran password] --region_city "America/Detroit" -i enp0s3 -b -g --guest --post_setup"
    echo "\t"
    echo "\t"


    echo ""
} 

FIX_OWNER( )
{
    chown -R "$1":"$1" /home/"$1"
}

ROOT_CHECK( )
{
   if [ -z "$PASS" ];
   then
       echo "must provide root password"
       USAGE
       exit
   fi
}

USER_CHECK( )
{
   # Error checking
   if [ -z "$USER" ];
   then
       echo "must provide username"
       USAGE
       exit
   fi

   if [ -z "$PASS" ];
   then
       echo "must provide password"
       USAGE
       exit
   fi
}

INTERFACE_CHECK( )
{
   if [ -z "$INTERFACE" ];
   then
       echo "must provide network interface"
       echo "Use the command 'ip link' (without quotes) to list available interfaces."
       USAGE
       exit
   fi
}

SCRIPT_NAME=`basename "$0"`
EXEC_STR="/""$SCRIPT_NAME"" "

# parse arguments and setup variables
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in 
        -s|--setup) # setup and install to given hard driver
            EXEC_STR="$EXEC_STR -s $2"            
            DRIVE=$2
            echo "DRIVE:$DRIVE"
            shift 
            ;;
        -r|--root_pass) # give root password 
            EXEC_STR="$EXEC_STR -r $2" 
            RPASS=$2 
            echo "RPASS:$RPASS"
            shift
            ;;
        --post_setup) # useful for passing same arguments from install image script instance to /mnt 
            EXEC_STR="$EXEC_STR --post_setup" 
            POST="TRUE"
            ;;
        --region_city) # for setting up user's region/city locale
            EXEC_STR="$EXEC_STR --region_city $2"            
            REG_CITY=$2
            shift
            ;;
        -b|--basic)
            EXEC_STR="$EXEC_STR -b $2"   
            BASIC="TRUE"
            ;;
        -u|--user)
            EXEC_STR="$EXEC_STR -u $2"            
            USER="$2"
            echo "USER:""$2"
            shift
            ;;
        -p|--pass)
            EXEC_STR="$EXEC_STR -p $2"            
            PASS="$2"
            echo "PASS:""$2"
            shift
            ;;
        -i|--interface)
            EXEC_STR="$EXEC_STR -i $2"            
            INTERFACE="$2"
            echo "INTERFACE:""$2"
            shift
            ;;
        -g|--gui)
            EXEC_STR="$EXEC_STR -g $2"            
            GUI="TRUE"
            ;;
        --gnome)
            EXEC_STR="$EXEC_STR --gnome"            
            GNOME_YES="TRUE"
            ;;
        --gnome_extras)
            EXEC_STR="$EXEC_STR --gnome_extras"            
            GNOME_EXTRAS_YES="TRUE"
            ;;
        --wine)
            EXEC_STR="$EXEC_STR --wine"            
            WINE="TRUE"
            ;;
        -v|--vga) # set graphics driver
            EXEC_STR="$EXEC_STR -v $2"            
            if [ -z "$VGA" ]; then
                VGA="$2"
            fi
            shift
            ;;
        --guest) # configure as a virtual machine (vbox) guest
            EXEC_STR="$EXEC_STR --guest"            
            VBOX="TRUE"
            ;;
        -l|--log)
            EXEC_STR="$EXEC_STR -l $2"
            LOG=$2
            shift
            ;;
        *)
            EXEC_STR="$EXEC_STR $2"
            echo "Invalid argument ""$2"
            USAGE
            ;;
    esac
    shift
done

#INSTALL_ARGS="-S --noconfirm"
INSTALL_ARGS="-S"
INSTALL="pacman "$INSTALL_ARGS

if [ -z "$DRIVE" ]; then
    POST="TRUE" # no (or already completed) basic install so we're good to do the rest of the install 
fi


#**************************************************************
# SETUP HARD DRIVE AND INSTALL BASE ARCH
#
if [ -z "$DRIVE" ]; then
    echo "Skipping initial setup & install"
else 
    if [ -z "$RPASS" ]; then 
        echo "Must provide root password with -r|--root_pass) argument"
        USAGE
        exit
    fi  

    if [ -z "$POST" ]; then # we're still on the first stage of the script
        timedatectl set-ntp TRUE
        echo -e "o\nn\np\n1\n\n\nw" | fdisk $DRIVE #partition hard drive from /dev
        PART="$DRIVE""1" # the created partition 
        echo "PART:"$PART
        mkfs.ext4 "$PART"
        mount "$PART" /mnt
        pacstrap /mnt base
        genfstab -U /mnt >> /mnt/etc/fstab 
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        echo "SCRIPT_DIR:"$SCRIPT_DIR
        echo "SCRIPT_NAME:"$SCRIPT_NAME
        if [ -z "$SCRIPT_DIR" ]; 
        then
           echo "No script directory, exitting"
           exit 
        fi
        cp "$SCRIPT_DIR"/"$SCRIPT_NAME" /mnt
        arch-chroot /mnt "$EXEC_STR"" --post_setup"
    fi
fi

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# POST INSTALL
#

if [ "$POST" == "TRUE" ]; then # we know we are in the /mnt version of the script, ok to continue

    #**************************************************************
    # COMPLETING BASIC INSTALL
    #
    if [ -z "$DRIVE" ]; then
        echo "Skipping secondary install"
    elif [ -z "$REG_CITY" ]; then 
        echo "Must provide Region/City with --region_city) argument for basic install"
        USAGE
        exit
    fi
    else 
        # error checks
        ROOT_CHECK # do we have root password?

        # do stuff
        ln -s /usr/share/zoneinfo/"$REG_CITY" /etc/localtime 
        hwclock --systohc
        sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen 
        locale-gen 
        echo "LANG=en_US.UTF-8" >> /etc/locale.conf 
        echo "system_durandal" >> /etc/hostname 
        mkinitcpio -p linux
        echo "root|$RPASS" | chpasswd 
        $INSTALL --noconfirm grub
        grub-install --target=i386-pc $DRIVE 
        grub-mkconfig -o /boot/grub/grub.cfg
    fi

    #**************************************************************
    # SETUP BASIC ENVIRONMENT 
    #
    if [ "$BASIC" == "TRUE" ]; then
        # Error checking 
        USER_CHECK # do we have username and password?
        INTERFACE_CHECK # do we have the ethernet interface? 

        # do stuff
        echo "setting up basic evironment"
        dhcpcd "$INTERFACE"

        systemctl enable dhcpcd@"$INTERFACE".service # permanently fix networking

        echo "setting up user"
        $INSTALL --noconfirm sudo
        useradd -m -G wheel -s /bin/bash "$USER"
        echo "$USER:$PASS" | chpasswd
        echo "$USER ALL=(ALL) ALL" >> /etc/sudoers

        echo "install basic usability packages"
        $INSTALL --noconfirm git # repository management
        $INSTALL --noconfirm vim # text editor
        $INSTALL --noconfirm guake # drop down terminal 
        $INSTALL --noconfirm gnome-terminal # generic terminal: most basic, reliable, maximully featured terminal
        $INSTALL --noconfirm gcc # c/c++ compiler
        $INSTALL --noconfirm make # basic build system 
        $INSTALL --noconfirm cmake # common build control system 
        $INSTALL --noconfirm --needed base-devel # used for installing alternative packages

        # configure the environment to be sane
        echo "configuring environment"
        cd /home/"$USER"
        git clone https://github.com/durandaltheta/vim
        cd vim/vimfiles/
        ./install.sh $USER # install custom vim settings

        echo 'alias ll="ls -l"' >> /home/"$USER"/.bash_profile  
        echo 'alias l="ls -F"' >> /home/"$USER"/.bash_profile
        echo 'alias la="ls -a"' >> /home/"$USER"/.bash_profile
        echo 'alias ll="ls -l"' >> /home/"$USER"/.bashrc
        echo 'alias l="ls -F"' >> /home/"$USER"/.bashrc
        echo 'alias la="ls -a"' >> /home/"$USER"/.bashrc

        cp /usr/share/applications/guake.desktop /etc/xdg/autostart/ # autostart guake 

        # setup script to enable sharing
        # will need to manually VirtualBox->Devices->Shared Folders->Shared Folders Settings and add 
        # a new shared folder named "Documents" (typically assigned to "My Documents" in windows)
        echo "#!/bin/bash" > /usr/local/bin/setup_share
        echo "if [ "$#" -ne 2 ]; then" >> /usr/local/bin/setup_share
        echo "\tUsage: setup_share [Shared folder name] [local mount directory]" >> /usr/local/bin/setup_share
        echo "\texit"
        echo "fi"
        echo "mount -t vboxsf $1 $2"

        mkdir -p /home/$USER/s 

        echo "[Unit]" > /lib/systemd/system/setupshare.service
        echo "Description=VirtualBox Setup Shared Folder Service" >> /lib/systemd/system/setupshare.service
        echo "After=vboxservice.service" >> /lib/systemd/system/setupshare.service
        echo "" >> /lib/systemd/system/setupshare.service
        echo "[Service]" >> /lib/systemd/system/setupshare.service
        echo "User=root" >> /lib/systemd/system/setupshare.service
        echo "ExecStart=/usr/local/bin/setup_share Documents /home/$USER/s" >> /lib/systemd/system/setupshare.service
        echo "" >> /lib/systemd/system/setupshare.service
        echo "[Install]" >> /lib/systemd/system/setupshare.service
        echo "WantedBy=multi-user.target" >> /lib/systemd/system/setupshare.service 

        systemctl enable setupshare.service 


        #--- bonus usability scripts
        # update arch linux
        echo "#!/bin/bash" > /usr/local/bin/linux_update
        echo "pacman -Syu" >> /usr/local/bin/linux_update 
        chmod +x /usr/local/bin/linux_update

        # install non pacman package
        echo "#!/bin/bash" > /usr/local/bin/install_pkg
        echo "git clone https://aur.archlinux.org/$1.git" >> /usr/local/bin/install_pkg
        echo "cd $1" >> /usr/local/bin/install_pkg 
        echo "makepkg -sirc" >> /usr/local/bin/install_pkg
        echo "cd ..; rm -rf $1" >> /usr/local/bin/install_pkg
        chmod +x /usr/local/bin/install_pkg

        FIX_OWNER "$USER"
    fi


    #**************************************************************
    # OPTIONAL PACKAGES
    #

    #~~~ VBOX ~~~
    if [ -z "$VBOX" ]; then
        echo "Skipping setting up VBox guest packages"
    else 
        echo "Setting up VBox guest PACKAGES"
        if [ "$VBOX" == "TRUE" ]; then
            #echo "2\ny" | $INSTALL virtualbox-guest-utils
            $INSTALL virtualbox-guest-utils
            systemctl enable vboxservice.service
        fi 
    fi

    #~~~ VGA ~~~
    if [ -z "$VGA" ]; then
        echo "Skipping graphics driver packages"
    else
        echo "Setting up graphics drivers"
        if [ "$VGA" == "intel" ]; then
            $INSTALL xf86-video-intel
        elif [ "$VGA" == "nvidia" ]; then
            $INSTALL nvidia
        elif [ "$VGA" == "amd" ]; then
            $INSTALL xf86-video-amdgpu
            $INSTALL xf86-video-ati
        fi
    fi

    #~~~ GUI ~~~
    if [ -z "$GUI" ];then
        echo "Skipping gui packages"
    else 
        echo "Setting up gui"
        #Maybe I need to an alternate version of this depending on whether we are guests or not?
        #echo "1\n1\ny" | $INSTALL xorg-server # not sure if necessary
        if [ -z "$VBOX" ]; then
            $INSTALL xorg-server # probably necessary
        else 
            $INSTALL xorg-server # probably necessary
        fi
        $INSTALL --noconfirm xorg-server-utils
        $INSTALL --noconfirm xorg-xinit 
        #echo "\ny" | $INSTALL xorg-drivers # bonus video drivers
        $INSTALL xorg-drivers # bonus video drivers
        #echo "\n\ny" | $INSTALL lxqt # desktop environment
        $INSTALL lxqt # desktop environment
        $INSTALL --noconfirm oxygen-icons # default icon theme
        $INSTALL --noconfirm slim # desktop manager
        $INSTALL --noconfirm slim-themes # additional themes for SLiM
        $INSTALL --noconfirm lxrandr # there are problems (as guest vm?) with standard screen size control
        $INSTALL --noconfirm hwinfo
        hwinfo # run to set some things up

        systemctl enable slim.service #enables slim at boot

        $INSTALL --noconfirm chromium # chrome base browser

        sed -i '84s/.*/current_theme\tarchlinux/' /etc/slim.conf # change to archlinux theme

        # setup .xinitrc so gui will start
        echo "#!/bin/bash " > /home/"$USER"/.xinitrc

        echo "if [ -d /etc/X11/xinit/xinitrc ]; then" >> /home/"$USER"/.xinitrc
        echo '   for f in /etc/X11/xinit/xinitrc.d/*; do' >> /home/"$USER"/.xinitrc
        echo '      [ -x "$f" ] && . "$f"' >> /home/"$USER"/.xinitrc
        echo '   done' >> /home/"$USER"/.xinitrc
        echo '   unset f' >> /home/"$USER"/.xinitrc
        echo "fi" >> /home/"$USER"/.xinitrc

        echo "exec startlxqt" >> /home/"$USER"/.xinitrc 

        # fix ownsership of files
        FIX_OWNER "$USER"
    fi

    #~~~ GNOME ~~~
    if [ -z "$GNOME_YES" ];then
        echo "Skipping gnome packages"
    else
        echo "Intalling gnome packages"
        $INSTALL --noconfirm gnome # install gnome applications
    fi 

    #~~~ GNOME-EXTRAS ~~~
    if [ -z "$GNOME_EXTRAS_YES" ];then
        echo "Skipping gnome extra packages"
    else
        echo "Intalling gnome extra packages"
        $INSTALL --noconfirm gnome-extra # install more gnome applications
    fi

    #~~~ WINE ~~~
    if [ -z "$WINE" ];then
        echo "Skipping wine packages"
    else
        echo "Intalling wine (wine-staging) packages"
        #enable multilib
        echo '[multilib]' >> /etc/pacman.conf
        echo 'Include = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf
        $INSTALL --noconfirm wine-staging # install gnome applications
        $INSTALL --noconfirm wine-mono
        $INSTALL --noconfirm wine_gecko
    fi
fi 

echo "COMPLETED SETUP ... EXITING"
echo "Reboot to complete installation"
#reboot
