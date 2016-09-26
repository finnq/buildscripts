#!/bin/bash

CMD="$1"
EXTRACMD="$2"
A_TOP=${PWD}
DATE=$(date +%D)
MACHINE_TYPE=`uname -m`
CM_VERSION=14.0

# Common defines (Arch-dependent)
case `uname -s` in
    Darwin)
        txtrst='\033[0m'  # Color off
        txtred='\033[0;31m' # Red
        txtgrn='\033[0;32m' # Green
        txtylw='\033[0;33m' # Yellow
        txtblu='\033[0;34m' # Blue
        THREADS=`sysctl -an hw.logicalcpu`
        ;;
    *)
        txtrst='\e[0m'  # Color off
        txtred='\e[0;31m' # Red
        txtgrn='\e[0;32m' # Green
        txtylw='\e[0;33m' # Yellow
        txtblu='\e[0;34m' # Blue
        THREADS=`cat /proc/cpuinfo | grep processor | wc -l`
        ;;
esac

check_root() {
    if [ ! $( id -u ) -eq 0 ]; then
        echo -e "${txtred}Please run this script as root."
        echo -e "\r\n ${txtrst}"
        exit
    fi
}

check_machine_type() {
    echo "Checking machine architecture..."
    if [ ${MACHINE_TYPE} == 'x86_64' ]; then
        echo -e "${txtgrn}Detected: ${MACHINE_TYPE}. Good!"
        echo -e "\r\n ${txtrst}"
    else
        echo -e "${txtred}Detected: ${MACHINE_TYPE}. Bad!"
        echo -e "${txtred}Sorry, I do only support building on 64-bit machines."
        echo -e "${txtred}32-bit is soooo 1970, consider a upgrade. ;-)"
        echo -e "\r\n ${txtrst}"
        exit
    fi
}

install_arch_packages()
{
    # x86_64
    pacman -S jdk7-openjdk jre7-openjdk jre7-openjdk-headless perl git gnupg flex bison gperf zip unzip lzop sdl wxgtk \
    squashfs-tools ncurses libpng zlib libusb libusb-compat readline schedtool \
    optipng python2 perl-switch lib32-zlib lib32-ncurses lib32-readline \
    gcc-libs-multilib gcc-multilib lib32-gcc-libs binutils libtool-multilib
}

prepare_environment()
{
    echo "Which 64-bit distribution are you running?"
    echo "1) Arch Linux"
    echo "2) Debian"
    read -n1 distribution
    echo -e "\r\n"

    case $distribution in
    "1")
        # Arch Linux
        echo "Installing packages for Arch Linux"
        install_arch_packages
        mv /usr/bin/python /usr/bin/python.bak
        ln -s /usr/bin/python2 /usr/bin/python
        ;;
    "2")
        # Debian
        echo "Installing packages for Debian"
        apt-get update
        apt-get install git-core gnupg flex bison gperf build-essential \
        zip curl libc6-dev lib32ncurses5 libncurses5-dev x11proto-core-dev \
        libx11-dev libreadline6-dev lib32readline-gplv2-dev libgl1-mesa-glx \
        libgl1-mesa-dev g++-multilib mingw32 openjdk-6-jdk tofrodos \
        python-markdown libxml2-utils xsltproc zlib1g-dev pngcrush \
        libcurl4-gnutls-dev comerr-dev krb5-multidev libcurl4-gnutls-dev \
        libgcrypt11-dev libglib2.0-dev libgnutls-dev libgnutls-openssl27 \
        libgnutlsxx27 libgpg-error-dev libgssrpc4 libgstreamer-plugins-base0.10-dev \
        libgstreamer0.10-dev libidn11-dev libkadm5clnt-mit8 libkadm5srv-mit8 \
        libkdb5-6 libkrb5-dev libldap2-dev libp11-kit-dev librtmp-dev libtasn1-3-dev \
        libxml2-dev tofrodos python-markdown lib32z-dev ia32-libs
        ln -s /usr/lib32/libX11.so.6 /usr/lib32/libX11.so
        ln -s /usr/lib32/libGL.so.1 /usr/lib32/libGL.so
        ;;
        
    *)
        # No distribution
        echo -e "${txtred}No distribution set. Aborting."
        echo -e "\r\n ${txtrst}"
        exit
        ;;
    esac
    
    echo "Do you want me to get android sources for you? (y/n)"
    read -n1 sources
    echo -e "\r\n"

    case $sources in
    "Y" | "y")
        echo "Choose a branch:"
        echo "1) cm-14.0 (nougat)"
        read -n1 branch
        echo -e "\r\n"

        case $branch in
            "1")
                # cm-14.0
                branch="staging/cm-14.0"
                ;;
            *)
                # no branch
                echo -e "${txtred}No branch choosen. Aborting."
                echo -e "\r\n ${txtrst}"
                exit
                ;;
        esac

        echo "Target Directory (~/android/CyanogenMod):"
        read working_directory

        if [ ! -n $working_directory ]; then 
            working_directory="~/android/CyanogenMod"
        fi

        echo "Installing to $working_directory"
        curl https://storage.googleapis.com/git-repo-downloads/repo > /usr/local/bin/repo
        chmod a+x /usr/local/bin/repo
        source ~/.profile
        
        mkdir -p $working_directory
        cd $working_directory
        repo init -u git://github.com/CyanogenMod/android.git -b $branch
        repo selfupdate
        mkdir -p $working_directory/.repo/local_manifests
        touch $working_directory/.repo/local_manifests/buildscripts.xml
        curl https://raw.github.com/finnq/buildscripts/$branch/buildscripts.xml > $working_directory/.repo/local_manifests/buildscripts.xml
        repo sync -j15
        echo "Sources synced to $working_directory"        
        exit
        ;;
    "N" | "n")
        # nothing to do
        exit
        ;;
    esac
}

# create kernel zip after successfull build
create_kernel_zip()
{
    echo -e "${txtgrn}Creating kernel zip...${txtrst}"
    if [ -e ${ANDROID_PRODUCT_OUT}/boot.img ]; then
        echo -e "${txtgrn}Bootimage found...${txtrst}"
        if [ -e ${A_TOP}/buildscripts/targets/${CMD}/kernel_updater-script ]; then

            echo -e "${txtylw}Package KERNELUPDATE:${txtrst} out/target/product/${CMD}/kernel-cm-${CM_VERSION}-$(date +%Y%m%d)-${CMD}-signed.zip"
            cd ${ANDROID_PRODUCT_OUT}

            rm -rf kernel_zip
            rm kernel-cm-${CM_VERSION}-*

            mkdir -p kernel_zip/system/lib/modules
            mkdir -p kernel_zip/META-INF/com/google/android

            echo "Copying boot.img..."
            cp boot.img kernel_zip/
            echo "Copying kernel modules..."
            cp -R system/lib/modules/* kernel_zip/system/lib/modules
            echo "Copying update-binary..."
            cp obj/EXECUTABLES/updater_intermediates/updater kernel_zip/META-INF/com/google/android/update-binary
            echo "Copying updater-script..."
            cat ${A_TOP}/buildscripts/targets/${CMD}/kernel_updater-script > kernel_zip/META-INF/com/google/android/updater-script
                
            echo "Zipping package..."
            cd kernel_zip
            zip -qr ../kernel-cm-${CM_VERSION}-$(date +%Y%m%d)-${CMD}.zip ./
            cd ${ANDROID_PRODUCT_OUT}

            echo "Signing package..."
            java -jar ${ANDROID_HOST_OUT}/framework/signapk.jar ${A_TOP}/build/target/product/security/testkey.x509.pem ${A_TOP}/build/target/product/security/testkey.pk8 kernel-cm-${CM_VERSION}-$(date +%Y%m%d)-${CMD}.zip kernel-cm-${CM_VERSION}-$(date +%Y%m%d)-${CMD}-signed.zip
            rm kernel-cm-${CM_VERSION}-$(date +%Y%m%d)-${CMD}.zip
            echo -e "${txtgrn}Package complete:${txtrst} out/target/product/${CMD}/kernel-cm-${CM_VERSION}-$(date +%Y%m%d)-${CMD}-signed.zip"
            md5sum kernel-cm-${CM_VERSION}-$(date +%Y%m%d)-${CMD}-signed.zip
            cd ${A_TOP}
        else
            echo -e "${txtred}No instructions to create out/target/product/${CMD}/kernel-cm-${CM_VERSION}-$(date +%Y%m%d)-${CMD}-signed.zip... skipping."
            echo -e "\r\n ${txtrst}"
        fi
    else
        echo -e "${txtred}Bootimage not found... skipping."
        echo -e "\r\n ${txtrst}"
    fi
}

echo -e "${txtblu} #####################################################################"
echo -e "${txtblu} \r\n"                                                   
echo -e "${txtblu}                CCCCCCCCCCCCC MMMMMMMM               MMMMMMMM "
echo -e "${txtblu}             CCC::::::::::::C M:::::::M             M:::::::M "
echo -e "${txtblu}           CC:::::::::::::::C M::::::::M           M::::::::M "
echo -e "${txtblu}          C:::::CCCCCCCC::::C M:::::::::M         M:::::::::M "
echo -e "${txtblu}         C:::::C       CCCCCC M::::::::::M       M::::::::::M "
echo -e "${txtblu}        C:::::C               M:::::::::::M     M:::::::::::M "
echo -e "${txtblu}        C:::::C               M:::::::M::::M   M::::M:::::::M "
echo -e "${txtblu}        C:::::C               M::::::M M::::M M::::M M::::::M "
echo -e "${txtblu}        C:::::C               M::::::M  M::::M::::M  M::::::M "
echo -e "${txtblu}        C:::::C               M::::::M   M:::::::M   M::::::M "
echo -e "${txtblu}        C:::::C               M::::::M    M:::::M    M::::::M "
echo -e "${txtblu}         C:::::C       CCCCCC M::::::M     MMMMM     M::::::M "
echo -e "${txtblu}          C:::::CCCCCCCC::::C M::::::M               M::::::M "
echo -e "${txtblu}           CC:::::::::::::::C M::::::M               M::::::M "
echo -e "${txtblu}             CCC::::::::::::C M::::::M               M::::::M "
echo -e "${txtblu}                CCCCCCCCCCCCC MMMMMMMM               MMMMMMMM "
echo -e "${txtblu} \r\n"
echo -e "${txtblu}                     CyanogenMod ${CM_VERSION} buildscript"
echo -e "${txtblu}                visit us @ http://www.cyanogenmod.org"
echo -e "${txtblu} \r\n"
echo -e "${txtblu} #####################################################################"
echo -e "\r\n ${txtrst}"

# Check for build target
if [ -z "${CMD}" ]; then
	echo -e "${txtred}No build target set."
	echo -e "${txtred}Usage: ./build.sh hammerhead (complete build)"
	echo -e "${txtred}       ./build.sh hammerhead kernel (bootimage only)"
	echo -e "${txtred}       ./build.sh clean (make clean, wipes entire out/ directory)"
    echo -e "${txtred}       ./build.sh clobber (make clober, wipes entire out/ directory, same as clean)"
    echo -e "${txtred}       ./build.sh prepare (prepares the build environment)"
    echo -e "\r\n ${txtrst}"
    exit
fi

# Starting Timer
START=$(date +%s)

case "$EXTRACMD" in
    eng)
		BUILD_TYPE=eng
		;;
    userdebug)
		BUILD_TYPE=userdebug
		;;
    *)
		BUILD_TYPE=eng
		;;
esac

# Device specific settings
case "$CMD" in
    prepare)
        check_root
        check_machine_type
        prepare_environment
        exit
        ;;
    clean)
        make clean
        exit
        ;;
    clobber)
        make clobber
        exit
        ;;
    *)
        lunch=cm_${CMD}-${BUILD_TYPE}
        brunch=${lunch}
        ;;
esac

# create env.sh if it doesn't exist
if [ ! -f env.sh ]; then
    # Enable ccache
    echo "export USE_CCACHE=1" > env.sh
    # Fix for Archlinux
    echo "export LC_ALL=C" > env.sh
fi

# create empty patches.txt if it doesn't exist
if [ ! -f patches.txt ]; then
    touch patches.txt
fi

# Apply gerrit changes from patches.txt. One change-id per line!
if [ -f patches.txt ]; then
    while read line; do
        line=$(sed 's/\s\?#.*$//g' <<< $line)
        GERRIT_CHANGES+="$line "    
    done < patches.txt

    if [[ ! -z ${GERRIT_CHANGES} && ! ${GERRIT_CHANGES} == " " ]]; then
        echo -e "${txtylw}Applying patches...${txtrst}"
        python vendor/cm/build/tools/repopick.py $GERRIT_CHANGES --ignore-missing --start-branch auto --abandon-first
        echo -e "${txtgrn}Patches applied!${txtrst}"
        read -p "Press any key to continue... " -n1 -s
        echo
    fi
fi

# Setting up Build Environment
echo -e "${txtgrn}Setting up Build Environment...${txtrst}"
. build/envsetup.sh
lunch ${lunch}

# Allow setting of additional flags
if [ -f env.sh ]; then
    source env.sh
fi

# fix module copy for archlinux
mkdir -p ${ANDROID_PRODUCT_OUT}/system/lib
mkdir -p ${ANDROID_PRODUCT_OUT}/system/usr
cd ${ANDROID_PRODUCT_OUT}/system/usr
ln -sf ../lib .
cd -

# Start the Build
case "$EXTRACMD" in
    kernel)
        echo -e "${txtgrn}Rebuilding bootimage...${txtrst}"

        rm -rf ${ANDROID_PRODUCT_OUT}/kernel_zip
        rm ${ANDROID_PRODUCT_OUT}/kernel
        rm ${ANDROID_PRODUCT_OUT}/boot.img
        rm -rf ${ANDROID_PRODUCT_OUT}/root
        rm -rf ${ANDROID_PRODUCT_OUT}/ramdisk*
        rm -rf ${ANDROID_PRODUCT_OUT}/combined*

        mka bootimage
        if [ ! -e ${ANDROID_PRODUCT_OUT}/obj/EXECUTABLES/updater_intermediates/updater ]; then
        	mka updater
        fi
        if [ ! -e ${ANDROID_HOST_OUT}/framework/signapk.jar ]; then
            mka signapk
        fi
        create_kernel_zip
        ;;
    recovery)
        echo -e "${txtgrn}Rebuilding recoveryimage...${txtrst}"

        rm -rf ${ANDROID_PRODUCT_OUT}/obj/KERNEL_OBJ
        rm ${ANDROID_PRODUCT_OUT}/kernel
        rm ${ANDROID_PRODUCT_OUT}/recovery.img
        rm ${ANDROID_PRODUCT_OUT}/recovery
        rm -rf ${ANDROID_PRODUCT_OUT}/ramdisk*

        mka ${ANDROID_PRODUCT_OUT}/recovery.img
        ;;
    *)
        echo -e "${txtgrn}Building Android...${txtrst}"
        brunch ${brunch}
        create_kernel_zip
        ;;
esac

END=$(date +%s)
ELAPSED=$((END - START))
E_MIN=$((ELAPSED / 60))
E_SEC=$((ELAPSED - E_MIN * 60))
printf "${txtgrn}Elapsed: "
[ $E_MIN != 0 ] && printf "%d min(s) " $E_MIN
printf "%d sec(s)\n ${txtrst}" $E_SEC

# Postbuild script for uploading builds
if [ -f postbuild.sh ]; then
    source postbuild.sh
fi
