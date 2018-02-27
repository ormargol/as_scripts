source build_and_run.conf
while true; do clear; wc -l $VER_BUILD_LOG_PATH; grep -E "### |\*\*\*\* |error\:|Done\!" $VER_BUILD_LOG_PATH; sleep $1; done
