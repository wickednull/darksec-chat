#!/bin/sh
# Title: DarkSec-Chat Configuration
# Author: wickednull
# Description: Configuration for DarkSec-Chat mesh+web chat client

# Web API URL for chat bridge.
# Empty or example.com = use the built-in DarkSec endpoint:
#   https://darksec.uk/api/chat
# To connect your own website chat, set the full endpoint URL:
#   https://your-site.example/api/chat
export WEB_API_URL=""

# Default display name (can be changed in-app on first run)
export USERNAME="PagerUser"

# Mesh networking ports (must match other peers for mesh discovery)
export UDP_PORT=9999
export TCP_PORT=9998
