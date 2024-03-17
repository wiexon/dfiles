#!/bin/bash

# Download the file
wget -O /usr/local/bin/cbot https://raw.githubusercontent.com/wiexon/dfiles/main/cbot/cbot.sh

# Make the file executable
chmod +x /usr/local/bin/cbot

sudo ln -s /usr/local/bin/cbot /usr/bin/cbot

echo "Installation complete"