#TODO:
# Comments.
# sw upgrade using only linux - done with linux tftpd but failed,
# looks like file was corrupted...why???
# sw upgrade for xlp.
# sw upgrade for ninja.
# print timing and progresses.
# create title fr_deploy_version - if we do fr build then deploy=build, if we dont do build then deploy is from last build (-1).
# VER_BUILD_HISTORY_NUM_TAG is confused and can't recognize that we haven't got latest and build based on our code, and also can't deal with other buildmachine not related.
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

if $PERFORM_AIR4G_BUILD ; then
    printf "$AIR4G_BRANCH: Build Start\n";
    cd $AIR4G_BUILD_PATH && make verbose=1 > $AIR4G_BUILD_LOG_PATH 2>&1
    if [ "`tail -3 $AIR4G_BUILD_LOG_PATH | head -1`" ==\
    "################# Completed making L2 FSM TDD ##############" ]; then
        printf "$AIR4G_BRANCH: Build Succeeded!\n\n"
    else
        printf "$AIR4G_BRANCH: Build Failed!\n\n"
        release_permissions_and_exit 1
    fi
else
    printf "$AIR4G_BRANCH: Build Skipped!\n\n"
fi

if $PERFORM_AIR4G_DEPLOY ; then
    printf "$AIR4G_BRANCH: Deploy Start\n"
    ssh -t $SETUP_USER@$SETUP_IP 'sudo -k; printf "$SETUP_PASSWORD\n" |\
            sudo -S su ; echo; rm -rf $AIR4G_DEPLOY_MIDDLE_PATH; mkdir\
            $AIR4G_DEPLOY_MIDDLE_PATH' > /dev/null 2>&1
    sudo scp -rp -oStrictHostKeyChecking=no -i $LOCAL_SSH_PRIVATE_KEY_PATH\
            $AIR4G_DEPLOY_SOURCE_PATH\
            $SETUP_USER@$SETUP_IP:$AIR4G_DEPLOY_MIDDLE_PATH 2>&1 > /dev/null
    ssh -t $SETUP_USER@$SETUP_IP 'sudo -k; printf "$SETUP_PASSWORD\n" |\
            sudo -S su; echo; for f in `ls $AIR4G_DEPLOY_SOURCE_PATH`;\
            do chmod `stat -c "%a" /bs/$f`\
            $AIR4G_DEPLOY_MIDDLE_PATH/$AIR4G_DEPLOY_SOURCE_DIR/$f; done' >\
            /dev/null 2>&1
    ssh -t $SETUP_USER@$SETUP_IP 'sudo -k; printf "$SETUP_PASSWORD\n" |\
    sudo -S mv $AIR4G_DEPLOY_MIDDLE_PATH/$AIR4G_DEPLOY_SOURCE_DIR/* /bs/' >\
    /dev/null 2>&1
    ssh -t $SETUP_USER@$SETUP_IP 'sudo -k; printf "$SETUP_PASSWORD\n" |\
    sudo -S; sudo busybox reboot'
    printf "$AIR4G_BRANCH: Deploy Succeeded!\n\n"
else
    printf "$AIR4G_BRANCH: Deploy Skipped!\n\n"
fi

if $PERFORM_VER_BUILD ; then
    printf "$VER_BUILD_NUM_TAG: Build Start\n"
    cd $VER_BUILD_TARGET_PATH && sudo ./makever.sh\
            --major=$VER_BUILD_NUM_MAJOR --minor=$VER_BUILD_NUM_MINOR\
            --build=$VER_BUILD_NUM_BUILD --notag --nostore\
            --usebuild=`pwd`/../. > $VER_BUILD_LOG_PATH 2>&1
    if [ "`tail -2 $VER_BUILD_LOG_PATH | head -1`" == "Done!" ]; then
                printf "$VER_BUILD_NUM_TAG: Build Succeeded!\n\n"
        else
                printf "$VER_BUILD_NUM_TAG: Build Failed!\n\n"
                release_permissions_and_exit 1
        fi
else
    printf "$VER_BUILD_NUM_TAG: Build Skipped!\n\n"
fi

if $PERFORM_VER_DEPLOY ; then
    printf "$VER_BUILD_NUM_TAG: Deploy Start\n"
    ssh -t $SETUP_USER@$SETUP_IP 'sudo -k; printf "$SETUP_PASSWORD\n" |\
            sudo -S /bs/bin/software_upgrade.sh tftp $VER_DEPLOY_TFTP_IP\
            $VER_BUILD_NUM_TAG/release/fsm.$VER_BUILD_NUM_TAG.enc' > /dev/null\
            2>&1
    ssh -t $SETUP_USER@$SETUP_IP 'sudo -k; printf "$SETUP_PASSWORD\n" |\
            sudo -S su; let "nbnk=1-`sudo /bs/bin/set_bank.sh | grep Current |\
            xargs echo -n | tail -c 1`"; sudo -k; printf "$SETUP_PASSWORD\n" |\
            sudo -S /bs/bin/set_bank.sh $nbnk' > /dev/null 2>&1
    ssh -t $SETUP_USER@$SETUP_IP 'sudo -k; printf "$SETUP_PASSWORD\n" |\
            sudo -S /bs/bin/set_bank.sh' > /dev/null 2>&1
    ssh -t $SETUP_USER@$SETUP_IP 'sudo -k; printf "$SETUP_PASSWORD\n" |\
            sudo -S; sudo busybox reboot' > /dev/null 2>&1
    printf "$VER_BUILD_NUM_TAG: Deploy Succeeded!\n\n"
else
    printf "$VER_BUILD_NUM_TAG: Deploy Skipped!\n\n"
fi

release_permissions_and_exit 0
