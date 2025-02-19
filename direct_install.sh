#!/bin/bash
#####################################################################
# Direct installation script for END_PRINT macro
# Author: ss1gohan13
# Created: 2025-02-19 15:47:06 UTC
#####################################################################

# Change to home directory first
cd ~ || {
    echo -e "\e[31m[ERROR]\e[0m Failed to change to home directory"
    exit 1
}

# Get the raw content directly from GitHub and pipe it to bash
curl -sSL https://raw.githubusercontent.com/ss1gohan13/A-better-print_start-macro-SV08/main/install_end_print.sh | bash
