#!/bin/bash

OPTIND=1
nodownload=0
verbose=0

while getopts "h?v?n" opt; do
    case "$opt" in
    h|\?)
        echo "Please read the script ;)"
        exit 0
        ;;  
    v)  verbose=1
        ;;
    n)  nodownload=1
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

LOG_FILE=ovs-$$.out
ERR_FILE=ovs-$$.err

# Close STDOUT file descriptor and Copy it to 3
exec 3<&1
exec 1<&-
# Close STDERR FD and Copy it to 4
exec 4<&2
exec 2<&-

# Open STDOUT as $LOG_FILE file for read and write.
exec 1>$LOG_FILE

# Redirect STDERR to STDOUT
exec 2>$ERR_FILE

C="0" # count
spin() {
    case "$(($C % 4))" in
        0) char="/"
        ;;
        1) char="-"
        ;;
        2) char="\\"
        ;;
        3) char="|"
        ;;
    esac
    echo -ne $char "\r" >&3
    C=$[$C+1]
}

endspin() {
    printf "\r%s\nPlease check logfile: $LOG_FILE\n" "$@" >&3
}

echos () {
    printf "\r%s\n" "$@" >&3
}

if [ "$nodownload" == "0" ]; then
    echos "Starting to install Openvswitch with support for NSH"
    git clone https://github.com/priteshk/ovs.git
    if [ $? -gt 0 ]; then
        endspin "ERROR:Cloning git repo failed."
        exit 1
    fi
fi

spin
cd ovs
spin
git stash
spin
git checkout nsh-v8
spin
git branch -v >&3
spin
git clean -x -d -f

spin
echos "Removing old ovs configuration."
sudo systemctl stop openvswitch
spin
sudo kill `cd /var/run/openvswitch && cat ovsdb-server.pid ovs-vswitchd.pid`
spin
sudo rm -rf /var/run/openvswitch
spin
sudo mkdir -p /var/run/openvswitch
spin
sudo rm -rf /etc/openvswitch
spin
sudo mkdir -p /etc/openvswitch
spin
sudo rm -rf /var/run/openvswitch
spin
sudo mkdir -p /var/run/openvswitch
spin
sudo rm -rf /var/log/openvswitch
spin
sudo mkdir -p /var/log/openvswitch
spin
sudo rmmod openvswitch
spin
sudo rmmod gre
spin
sudo rmmod vxlan
spin
sudo rmmod libcrc32c
spin
sudo rmmod openvswitch
spin
sudo yum remove -y openvswitch
spin
./boot.sh
spin
./configure --with-linux=/lib/modules/`uname -r`/build
spin
sudo make uninstall
spin
git clean -x -d -f

spin
#sudo apt-get install -y build-essential
sudo yum groupinstall -y "Development Tools" "Development Libraries"
spin
sudo yum install -y fakeroot
spin
#sudo apt-get install -y debhelper
spin
sudo yum install -y autoconf
spin
sudo yum install -y automake
spin
sudo yum install -y openssl-devel
spin
sudo yum install -y bzip2
spin
sudo yum install -y openssl
spin
sudo yum install -y graphviz
spin
sudo yum install -- '*python*' -python3-queuelib -python-django-federated-login -gcc-python3-plugin -python-qpid_messaging -gcc-python2-plugin -gcc-python3-debug-plugin -python-django* -django* -gcc-python2-debug-plugin -python3-django15-1.5.8-1 python-django-bash-completion* -python-django15*
spin
sudo yum install -y procps
spin
sudo yum install -y python-qt4
spin
sudo yum install -y python-zope-interface
spin
sudo yum install -y python-twisted-conch
spin
sudo yum install -y libtool
spin
sudo yum install -y rpm-build

spin
./boot.sh
spin
./configure
spin
make dist
spin
cp openvswitch.*.tar.gz ~/
spin
echos "openvswitch built,..moving to ${HOME}/rpmbuild/SOURCES"
spin
if [ ! -d ~/rpmbuild/SOURCES ]; then
  echo "creating rpmbuild dir..."
fi
spin
mv -f openvswitch-*.tar.gz ~/rpmbuild/SOURCES/
spin
pushd ~/rpmbuild/SOURCES/
spin
tar -xzf openvswitch*.tar.gz
spin
ls
cd openvswitch-*
if [ $(cat etc/*release* | grep -i Fedora) ]; then
  os_type=fedora
elif [ $(cat /etc/*release* | grep -i CentOS|rhel) ]; then
  os_type=rhel6
else
  echo "ERROR: OS Type is not Fedora or RHEL/CentOS..exiting!"
  exit 1
fi
spin
kernel_version=$(uname -a | awk '{print $3}')

echo "OS Type $os_type detected with kernel version $kernel_version"

kernel_major=$(echo $kernel_version | cut -d . -f  1 )
spin
if [ $kernel_major -gt 3 ]; then
  echo "Will not build kernel module as kernel is too new"
  build_kernel=false
else
  echo "Building kernel module..."
  if rpmbuild -bb -D "kversion $kernel_version" -D "kflavors default" --without check rhel/openvswitch-kmod-${os_type}.spec; then
    echo " Kernel RPM built!"
    build_kernel=true
  else
    echo "Unable to build kernel RPM..will try to build userspace RPM"
    build_kernel=false
  fi
fi

spin
echo "Building userspace module"
if rpmbuild -bb -D "kversion $kernel_version" -D "kflavors default" --without check rhel/openvswitch-${os_type}.spec; then
  echo "RPM built successfully!!"
  build_user=true
else
  echo "Unable to build user RPM.  Check Logs. Exiting..."
  exit 1
fi
spin

popd
pushd ~/rpmbuild/RPMS/
echo "Installing RPM..."
if sudo rpm -i openvswitch-*.rpm; then
  echo "Able to install openvswitch!"
else
  endspin "Unable to install openvswitch! Check ~/rpmbuild/RPMS/"
  exit 1
fi
popd
spin
sudo systemctl restart openvswitch
spin
sudo systemctl enable openvswitch
sudo lsmod | grep -i open
spin
sudo ovs-vsctl show >&3
spin

echo "Install Complete!"
