FROM     ubuntu:trusty
MAINTAINER "Stefan Jenkner <stefan@jenkner.org>"

ENV DEBIAN_FRONTEND noninteractive
ENV TERM=xterm
RUN apt-get update

RUN apt-get install -y --no-install-recommends \
        adduser \
        apt-utils \
        ca-certificates \
        devscripts \
        git-core \
        lsb-release \
        procps \
        wget \
    && apt-get clean
RUN cd /tmp \
    && git clone https://github.com/scarygliders/X11RDP-o-Matic.git \
    && cd X11RDP-o-Matic \
    && ./X11rdp-o-matic.sh --justdoit --withsound \
    && cd .. \
#    && rm -rf X11RDP-o-Matic
    && echo
RUN apt-get install -y --no-install-recommends \
    fakeroot \
    gnupg \
    ubuntu-keyring \
    pulseaudio \
    && apt-get clean
RUN apt-get -y build-dep pulseaudio
RUN cd /tmp && apt-get -y source pulseaudio && cd /tmp/pulseaudio-4.0 && dpkg-buildpackage -us -uc -rfakeroot
RUN cd /tmp/X11RDP-o-Matic/xrdp/sesman/chansrv/pulse \
    && make PULSE_DIR=/tmp/pulseaudio-4.0 \
    && mkdir -p /usr/lib/pulse-4.0/modules \
    && cp module-xrdp-sink.so /usr/lib/pulse-4.0/modules \
    && cp module-xrdp-source.so /usr/lib/pulse-4.0/modules \
    && rm -rf /tmp/pulseaudio-4.0

# Desktop Environment
RUN apt-get install -y --no-install-recommends \
        byobu \
        ca-certificates \
        command-not-found \
        dbus \
        fuse \
        language-pack-de \
        language-pack-en-base \
        less \
        mr \
        paprefs \
        pulseaudio-utils \
        sudo \
        supervisor \
        tango-icon-theme \
        vcsh \
        vim-nox \
        wget \
        xfonts-base \
        xubuntu-artwork \
        xfce4-session \
        xterm \
        zsh \
        openssh-server \
    && apt-get clean

# Cleanup
RUN /etc/init.d/xrdp force-stop

# DBus
RUN mkdir -p /var/run/dbus
RUN chown messagebus:messagebus /var/run/dbus
RUN dbus-uuidgen --ensure

# Supervisord
RUN echo "[supervisord]\nnodaemon=true\n" > /etc/supervisor/conf.d/supervisord.conf
RUN echo "[program:xrdp]\ncommand=/usr/sbin/xrdp --nodaemon\n" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "[program:xrdp-sesman]\ncommand=/usr/sbin/xrdp-sesman -n\n" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "[program:dbus-daemon]\ncommand=/bin/dbus-daemon --system --nofork\nuser=messagebus\n" >> /etc/supervisor/conf.d/supervisord.conf

# User
RUN useradd -m -d /home/guest -p guest guest
RUN echo 'guest:docker' |chpasswd
RUN chsh -s /bin/zsh guest
RUN adduser guest sudo
RUN adduser guest fuse
RUN echo "/usr/bin/startxfce4" > /home/guest/.xsession

RUN echo 'root:root123' |chpasswd

RUN sed -ri 's/^#?PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config
RUN mkdir /root/.ssh

EXPOSE 3389 22
CMD ["/usr/bin/supervisord"]
