# scripts


The initial config script is meant to run in my environment, change it according to yours.

It sets the IP based on what you set the hostname to resolve to in your DNS server.
It gets dns servers, domain name, and gateway from the original DHCP config.

`wget -O config.sh https://raw.githubusercontent.com/nathanthorpe/scripts/master/initialconfig.sh && sudo sh ./config.sh`
