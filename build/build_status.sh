source build_and_run_new.sh
while true; do clear; wc -l $VER_BUILD_LOG_PATH; grep -E "### |error\:" $VER_BUILD_LOG_PATH; sleep $1; done
