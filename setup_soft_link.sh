#!/bin/bash

# Define the target link and its desired destinations
LINK_PATH="./thirdparty/CoppeliaSim_Edu_V4_1_0_Ubuntu18_04/libcoppeliaSim.so.1"
SERVER_DEST="/home/kb/MyProjects/peract/thirdparty/CoppeliaSim_Edu_V4_1_0_Ubuntu18_04/libcoppeliaSim.so"
LOCAL_DEST="/home/kb/gpu02kb/peract/thirdparty/CoppeliaSim_Edu_V4_1_0_Ubuntu18_04/libcoppeliaSim.so"

# Remove any existing link
[ -L "$LINK_PATH" ] && rm "$LINK_PATH"

# Determine which link to create based on the argument
case "$1" in
    --server)
        ln -s "$SERVER_DEST" "$LINK_PATH"
        ;;
    --local)
        ln -s "$LOCAL_DEST" "$LINK_PATH"
        ;;
    *)
        echo "Usage: $0 [--server | --local]"
        exit 1
        ;;
esac


# user case:
# sh setup_soft_link.sh --server
# sh setup_soft_link.sh --local
