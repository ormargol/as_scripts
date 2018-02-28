[[ $_ != $0 ]] && printf "%s != %s\n" $_ $0 && return

source ~/scripts/build/build_and_run.conf

function release_permissions_and_exit {
    printf "General: Permissions Releasing Start\n"
    sudo sed -i "/Defaults timestamp_timeout=-1/d" /etc/sudoers
    if [ $? -ne 0 ]; then
        printf "General: Permissions Releasing Failed!\n\n"
        exit 1
    fi
    printf "General: Permissions Releasing Succeeded!\n\n"
    exit $1
}

printf "\nGeneral: Permissions Obtaining Start\n"
sudo -s exit
if [ $? -ne 0 ]; then
    printf "General: Permissions Obtaining Failed!\n\n"
    exit 1
fi
sudo sh -c 'echo "Defaults timestamp_timeout=-1" >> /etc/sudoers'
if [ $? -ne 0 ]; then
    printf "General: Permissions Obtaining Failed!\n\n"
    sudo sed -i "/Defaults timestamp_timeout=-1/d" /etc/sudoers
    release_permissions_and_exit 1
fi
printf "General: Permissions Obtaining Succeeded!\n\n"

if $PERFORM_FR_BUILD ; then
    printf "$FR_BRANCH: Build Start\n"
    cd $FR_BUILD_SCRIPTS_PATH && ./makever.sh --fapi \
--product=$FR_BUILD_VER_PRODUCT --major=$FR_BUILD_VER_MAJOR \
--minor=$FR_BUILD_VER_MINOR --build=$FR_BUILD_VER_BUILD --release=0 \
--usebuild=$FR_PATH > $FR_BUILD_LOG_PATH 2>&1
    if [ "`tail -1 $FR_BUILD_LOG_PATH`" == "Done! Version $FR_BUILD_VERSION is ready" ]; then
        printf "$FR_BRANCH: Build Succeeded!\n\n"
    else
        printf "$FR_BRANCH: Build Failed!\n\n"
        release_permissions_and_exit 1
    fi
else
    printf "$FR_BRANCH: Build Skipped!\n\n"
fi

if $PERFORM_FR_DEPLOY ; then
    printf "$FR_BRANCH: Deploy Start\n";
    cd $FR_DEPLOY_KRAITIMAGES_TARGET && find $FR_DEPLOY_SOURCE/release -type f\
 -not -iname "metabuild*" -not -iname "*velocity*" -printf '%f\n'\
| xargs -L 1 p4 edit -c $FR_DEPLOY_KRAITIMAGES_P4_CL > /dev/null
    cd $FR_DEPLOY_KRAITIMAGES_TARGET && p4 edit -c\
$FR_DEPLOY_KRAITIMAGES_P4_CL velocity_fapi.tgz > /dev/null
    cd $FR_DEPLOY_KRAITIMAGES_TARGET/debug && find\
 $FR_DEPLOY_SOURCE/debug/vmlinux.fapi.gz -type f -printf '%f\n' | xargs -L 1\
 p4 edit -c $FR_DEPLOY_KRAITIMAGES_P4_CL > /dev/null
    find $FR_DEPLOY_SOURCE/release -type f -not -iname "metabuild*"\
 -exec sudo cp {} $FR_DEPLOY_KRAITIMAGES_TARGET \;
    sudo mv $FR_DEPLOY_KRAITIMAGES_TARGET/velocity_fapi_$FR_DEPLOY_VERSION.tgz\
 $FR_DEPLOY_KRAITIMAGES_TARGET/velocity_fapi.tgz
    find $FR_DEPLOY_SOURCE/debug/vmlinux.fapi.gz\
 -exec sudo cp {} $FR_DEPLOY_KRAITIMAGES_TARGET/debug \;
    printf "$FR_BRANCH: Deploy Succeeded!\n\n"
else
    printf "$FR_BRANCH: Deploy Skipped!\n\n"
fi

if $PERFORM_VER_BUILD ; then
    printf "$VER_BUILD_NUM_TAG: Build Start\n"
    VER_BUILD_FLAGS=""
    if $MAKEVER_PERFORM_BSP_BUILD ; then
        VER_BUILD_FLAGS="$VER_BUILD_FLAGS --bsp"
    fi
    if $MAKEVER_PERFORM_ENC2_BUILD ; then
        VER_BUILD_FLAGS="$VER_BUILD_FLAGS --enc2"
    fi
    if $MAKEVER_PERFORM_ENODEB_MAKE_CLEAN ; then
        VER_BUILD_FLAGS="$VER_BUILD_FLAGS --clean"
    fi
    if $MAKEVER_PERFORM_ENODEB_MAKE_XLPFDD ; then
        VER_BUILD_FLAGS="$VER_BUILD_FLAGS --xlpfdd"
    fi
    if $MAKEVER_PERFORM_ENODEB_MAKE_XLPTDD ; then
        VER_BUILD_FLAGS="$VER_BUILD_FLAGS --xlptdd"
    fi
    if $MAKEVER_PERFORM_ENODEB_MAKE_FSMFDD ; then
        VER_BUILD_FLAGS="$VER_BUILD_FLAGS --fsmfdd"
    fi
    if $MAKEVER_PERFORM_ENODEB_MAKE_FSMTDD ; then
        VER_BUILD_FLAGS="$VER_BUILD_FLAGS --fsmtdd"
    fi
    printf "" > $VER_BUILD_LOG_PATH
    tail -f $VER_BUILD_LOG_PATH | grep -E "### |\*\*\*\* |error\:|Done\!" &
    tailpid=$!
    cd $VER_BUILD_TARGET_PATH && sudo -E ./makever.sh\
            --major=$VER_BUILD_NUM_MAJOR --minor=$VER_BUILD_NUM_MINOR\
            --build=$VER_BUILD_NUM_BUILD --notag --nostore\
            --usebuild=`pwd`/../.\
            $VER_BUILD_FLAGS > $VER_BUILD_LOG_PATH 2>&1
    kill -9 $tailpid
    if [ "`tail -2 $VER_BUILD_LOG_PATH | head -1`" == "Done!" ]; then
                printf "$VER_BUILD_NUM_TAG: Build Succeeded!\n\n"
        else
                printf "$VER_BUILD_NUM_TAG: Build Failed!\n\n"
                release_permissions_and_exit 1
        fi
else
    printf "$VER_BUILD_NUM_TAG: Build Skipped!\n\n"
fi

release_permissions_and_exit 0
