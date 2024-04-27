#!/bin/zsh

view_address() {

scutil --get HostName
ifconfig en0 | grep ether | awk '{print $2}'
networksetup -listallhardwareports | awk -v RS= '/en0/{print $NF}'

}

tunrn_off_spoof() {

rm /usr/local/sbin/first-names.txt
rm /usr/local/sbin/spoof-hook.sh
rm /usr/local/sbin/spoof.sh
sudo rm /Library/LaunchDaemons/local.spoof.plist

sudo defaults delete com.apple.loginwindow LogoutHook

sudo scutil --set ComputerName "mwarevn’s MacBook Pro"
sudo scutil --set LocalHostName "mwarevn-MacBook-Pro"
sudo scutil --set HostName "mwarevn-MacBook-Pro"

echo "Done! Reboot your decive now."

}

tunrn_on_spoof() {
    
sudo mkdir -p /usr/local/sbin
sudo chown ${USER}:admin /usr/local/sbin

echo 'export PATH=$PATH:/usr/local/sbin' >> ~/.zshrc
source ~/.zshrc

curl --fail --output /usr/local/sbin/first-names.txt https://sunknudsen.com/privacy-guides/how-to-spoof-mac-address-and-hostname-automatically-at-boot-on-macos/first-names.txt

cat << "EOF" > /usr/local/sbin/spoof.sh
#! /bin/sh

set -e
set -o pipefail

export LC_CTYPE=C

basedir=$(dirname "$0")

# Spoof computer name
first_name=$(sed "$(jot -r 1 1 2048)q;d" $basedir/first-names.txt | sed -e 's/[^a-zA-Z]//g')
model_name=$(system_profiler SPHardwareDataType | awk '/Model Name/ {$1=$2=""; print $0}' | sed -e 's/^[ ]*//')
computer_name="$first_name’s $model_name"
host_name=$(echo $computer_name | sed -e 's/’//g' | sed -e 's/ /-/g')
sudo scutil --set ComputerName "$computer_name"
sudo scutil --set LocalHostName "$host_name"
sudo scutil --set HostName "$host_name"
printf "%s\n" "Spoofed hostname to $host_name"

# Spoof MAC address of Wi-Fi interface
mac_address_prefix=$(networksetup -listallhardwareports | awk -v RS= '/en0/{print $NF}' | head -c 8)
mac_address_suffix=$(openssl rand -hex 3 | sed 's/\(..\)/\1:/g; s/.$//')
mac_address=$(echo "$mac_address_prefix:$mac_address_suffix" | awk '{print tolower($0)}')
networksetup -setairportpower en0 on
sudo /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport --disassociate
sudo ifconfig en0 ether "$mac_address"
printf "%s\n" "Spoofed MAC address of en0 interface to $mac_address"
EOF

chmod +x /usr/local/sbin/spoof.sh

cat << "EOF" | sudo tee /Library/LaunchDaemons/local.spoof.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>local.spoof</string>

    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/sbin/spoof.sh</string>
    </array>

    <key>RunAtLoad</key>
    <true/>
  </dict>
</plist>
EOF

cat << "EOF" > /usr/local/sbin/spoof-hook.sh
#! /bin/sh

# Turn off Wi-Fi interface
networksetup -setairportpower en0 off
EOF

chmod +x /usr/local/sbin/spoof-hook.sh

sudo defaults read com.apple.loginwindow

sudo defaults write com.apple.loginwindow LogoutHook "/usr/local/sbin/spoof-hook.sh"

echo "Done! Reboot your decive now."

}

if [[ $1 == "on" ]]
then
    echo "Turn on the spoof MAC Address...."
    tunrn_on_spoof
elif [[ $1 == "off" ]]
then
    echo "Turn off the spoof MAC Address...."
    tunrn_off_spoof
else
    view_address
fi
