# openvpn-for-usg
Dockerfile to build Openvpn for UniFi Security Gateway (https://store.ui.com/products/unifi-security-gateway).

The firmware for the UniFi Security Gateway (USG) includes a very old openvpn version (2.3.2) that does not support TLS1.2. This is a security issue and also limits the usefulness of the USG's openvpn as many VPN service providers requires TLS1.2 or later.

This dockerfile builds openvpn 2.5.7 with statically linked libraries for the USG. This makes it possible to install and execute the openvpn binary on an USG without updating any of the USG's existing libraries. That will reduce the risk of collateral damage due to library version incompatibilities.



This is loosely based on the steps described by Anubisss (https://gist.github.com/Anubisss/afea82b97058e418e8030ee35e40f54f)
