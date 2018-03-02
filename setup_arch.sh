#!/bin/bash 

USAGE( )
{
    echo "$0 valid arguments"
    echo "   -s|--setup [hard drive to install to]: setup drive and install basic arch linux packages."
    echo "          This must be run from the Arch install iso level."
    echo "   --region_city [Region/City]: Example \"America/Detroit\" (required for --setup)"
    echo "   -r|--root_pass [root password]: set the root password (required for --setup)"
    echo "   -u|--user [username]"
    echo "   -p|--pass [password]"
    echo "   -i|--interface [network interface]"
    echo "   -v|--vga [intel/amd/nvidia]: install specific graphics drivers"
    echo ""
    echo "example usage"
    echo "-------------"
    echo "\tfrom arch linux install iso welcome terminal:"
    echo "\t$ ./setup_arch.sh -r [root password] -u [username] -p [user password]"
    echo "OR:"
    echo "\t$ ./setup_arch.sh -d /dev/sda -r [root password]-u duran -p [duran password] --region_city "America/Detroit" -i enp0s3"
    echo ""
} 

# some defaults
DRIVE="/dev/sda"
REG_CITY="America/Detroit"
INTERFACE="enp0s3" 

SCRIPT_NAME=`basename "$0"`
EXEC_STR="$SCRIPT_NAME --intern"
# parse arguments and setup variables
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in 
        -h|--help)
            USAGE
            exit 
            ;;
        --intern) # execute internal commands
            INTERN=$2
            shift 
            ;;
        -d|--drive) # setup and install to given hard driver
            DRIVE=$2
            EXEC_STR="$EXEC_STR -d $DRIVE" 
            echo "DRIVE:$DRIVE"
            shift 
            ;;
        --region_city) # for setting up user's region/city locale
            REG_CITY=$2
            EXEC_STR="$EXEC_STR --region_city $REG_CITY" 
            shift
            ;;
        -r|--root_pass) # give root password 
            RPASS=$2 
            EXEC_STR="$EXEC_STR -r $RPASS" 
            echo "RPASS:$RPASS"
            shift
            ;;
        -u|--user)
            USER="$2"
            EXEC_STR="$EXEC_STR -u $USER" 
            echo "USER:$USER"
            shift
            ;;
        -p|--pass)
            PASS="$2"
            EXEC_STR="$EXEC_STR -p $PASS" 
            echo "PASS:$PASS"
            shift
            ;;
        -i|--interface)
            INTERFACE="$2"
            EXEC_STR="$EXEC_STR -i $INTERFACE" 
            echo "INTERFACE:$INTERFACE"
            shift
            ;;
        -v|--vga) # set graphics driver
            VGA="$2"
            EXEC_STR="$EXEC_STR -v $VGA"
            echo "VGA:$VGA"
            shift
            ;;
        *)
            echo "Invalid argument:$2"
            USAGE
            exit
            ;;
    esac
    shift
done 

if [ -z "$INTERN" ]
then
    # if --intern hasn't been set do initial setup 
    
    #**************************************************************
    # SETUP HARD DRIVE AND INSTALL BASE ARCH
    # 
    timedatectl set-ntp TRUE
    echo -e "o\nn\np\n1\n\n\nw" | fdisk $DRIVE #partition hard drive from /dev
    PART="$DRIVE""1" # the created partition 
    echo "PART:"$PART
    mkfs.ext4 "$PART"
    mount "$PART" /mnt
    pacstrap /mnt base
    genfstab -U /mnt >> /mnt/etc/fstab 
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    if [ -z "$SCRIPT_DIR" ]; 
    then
       echo "No script directory, exitting"
       exit 
    fi
    SCRIPT=$SCRIPT_DIR/$SCRIPT_NAME
    echo "SCRIPT:$SCRIPT"
    echo "EXEC_STR:$EXEC_STR"
    cp $SCRIPT /mnt 
    arch-chroot /mnt /mnt/"$EXEC_STR"
else 
    # if --itern was set it's time to install custom packages and settings 
    
    INSTALL="pacman -S --noconfirm"

    #**************************************************************
    # ERROR CHECKING
    #
    # Root Check: do we have root password?
    if [ -z "$RPASS" ];
    then
       echo "must provide root password"
       USAGE
       exit
    fi

    # User Check: do we have username and password?
    if [ -z "$USER" ];
    then
       echo "must provide username"
       USAGE
       exit
    fi

    if [ -z "$PASS" ];
    then
       echo "must provide user password"
       USAGE
       exit
    fi

    # Interface Check: do we have the ethernet interface?
    if [ -z "$INTERFACE" ];
    then
       echo "Must provide network interface"
       echo "Use the command 'ip link' (without quotes) to list available interfaces."
       USAGE
       exit
    fi 

    # VGA Check: do we have the graphical driver type?
    if [ -z "$VGA" ]; then
        echo "Must select grapics driver package"
        USAGE
        exit
    fi


    #**************************************************************
    # REQUIRED SETUP 
    #
    echo "Setting up Date, Time, and Language"
    ln -s /usr/share/zoneinfo/"$REG_CITY" /etc/localtime 
    hwclock --systohc
    sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen 
    locale-gen 
    echo "LANG=en_US.UTF-8" >> /etc/locale.conf 
    echo "system_durandal" >> /etc/hostname  


    echo "Setting up initial Ramdisk"
    mkinitcpio -p linux 


    echo "Setting up Root"
    echo "root|$RPASS" | chpasswd 


    echo "Setting up Grub Boot Loader"
    $INSTALL grub
    grub-install --target=i386-pc $DRIVE 
    grub-mkconfig -o /boot/grub/grub.cfg


    echo "Setting up User: $USER"
    $INSTALL sudo
    useradd -m -G wheel -s /bin/bash "$USER"
    echo "$USER:$PASS" | chpasswd
    echo "$USER ALL=(ALL) ALL" >> /etc/sudoers


    echo "Setting up Network"
    dhcpcd "$INTERFACE"
    systemctl enable dhcpcd@"$INTERFACE".service # permanently fix networking



    #**************************************************************
    # INSTALL PACKAGES 
    #
    echo "Installing Default Linux Packages"
    $INSTALL wget 
    $INSTALL cpio 
    $INSTALL curl
    $INSTALL vim # terminal text editor


    echo "Installing Development Packages"
    $INSTALL git # repository management
    $INSTALL gcc # c/c++ compiler
    $INSTALL make # basic build system 
    $INSTALL cmake # common build control system 
    $INSTALL ctags # basic c/c++ tagging system
    $INSTALL autoconf # automatic build configuration
    $INSTALL --needed base-devel # used for installing alternative packages 


    echo "Installing Graphics Drivers"
    if [ "$VGA" == "intel" ]; then
        $INSTALL xf86-video-intel
    elif [ "$VGA" == "nvidia" ]; then
        $INSTALL nvidia
    elif [ "$VGA" == "amd" ]; then
        $INSTALL xf86-video-amdgpu
        $INSTALL xf86-video-ati
    fi


    echo "Installing Basic Graphics Environment"
    $INSTALL weston 
    $INSTALL xorg-server-xwayland # for non-wayland gui applications
    $INSTALL gnome # install gnome desktop and applications
    $INSTALL lxrandr # there are problems (as guest vm?) with standard screen size control
    $INSTALL hwinfo
    hwinfo # run to set some things up  


    echo "Installing Graphical Packages"
    $INSTALL firefox # chrome base browser
    $INSTALL gnome-extras # install all the other gnome stuff
    $INSTALL gnome-terminal # sanity check install of default terminal
    $INSTALL gnome-initial-setup # welcome setup program


    echo "Installing Favorite Linux Packages"
    $INSTALL guake # drop down terminal, personal favorite


    echo "Intalling Wine and Multilib Packages"
    echo '[multilib]' >> /etc/pacman.conf
    echo 'Include = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf
    $INSTALL wine-staging # install gnome applications
    $INSTALL wine-mono
    $INSTALL wine_gecko



    #**************************************************************
    # CONFIGURE ENVIRONMENT 
    #
    # configure the environment to be sane
    echo "Configuring Graphics Environment" 

    # setup login manager gdm 
    systemctl enable gdm.service

    # setup autostart for gnome
    echo 'if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]] && [[ -z $XDG_SESSION_TYPE ]]; then' >> /home/"$USER"/.bash_profile
    echo '    XDG_SESSION_TYPE=wayland exec dbus-run-session gnome-session' >> /home/"$USER"/.bash_profile
    echo 'fi' >> /home/"$USER"/.bash_profile 


    echo "Configuring Environment"
    cd /home/"$USER"
    git clone https://github.com/durandaltheta/vim
    cd vim/vimfiles/
    ./install_vim.sh $USER # install custom vim settings

    echo 'alias ll="ls -l"' >> /home/"$USER"/.bash_profile  
    echo 'alias l="ls -F"' >> /home/"$USER"/.bash_profile
    echo 'alias la="ls -a"' >> /home/"$USER"/.bash_profile
    echo 'alias ll="ls -l"' >> /home/"$USER"/.bashrc
    echo 'alias l="ls -F"' >> /home/"$USER"/.bashrc
    echo 'alias la="ls -a"' >> /home/"$USER"/.bashrc

    cp /usr/share/applications/guake.desktop /etc/xdg/autostart/ # autostart guake 

    cd /home/"$USER"

    #--- bonus usability scripts
    # update arch linux
    echo "#!/bin/bash" > /usr/local/bin/system-update
    echo "pacman -Syu" >> /usr/local/bin/system-update 
    chmod +x /usr/local/bin/system-update 


    # fix ownsership of files
    chown -R "$USER":"$USER" /home/"$USER" 

    echo "Installation Complete - Reboot now with command 'reboot'"
fi
