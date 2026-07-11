# GLIA: run the first-boot wizard once, at the first interactive login
# (skipped on the live ISO and after completion)
if [ -t 0 ] && [ ! -f /etc/glia/.firstboot-done ] && [ ! -d /run/archiso ]; then
    /usr/local/bin/glia-firstboot
fi
