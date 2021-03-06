
docs_port = 8000

Vagrant.configure("2") do |config|
  config.vm.box = "subutai/stretch"
  config.vm.network "forwarded_port", guest: 8000, host: 8000, auto_correct: true

  config.vm.synced_folder ".", "/readthedocs", disabled: false

  config.vm.provider :kvm do |_, override|
    config.vm.synced_folder ".", "/readthedocs", disabled: false, nfs: true
  end  

  config.vm.provision 'shell',
    env: {
      "ACNG_HOST" => ENV['ACNG_HOST'],
      "ACNG_PORT" => ENV['ACNG_PORT'],
      "APPROX_HOST" => ENV['APPROX_HOST'],
      "APPROX_PORT" => ENV['APPROX_PORT'],
      "GDRIVE_TOKEN_FILE" => ENV['GDRIVE_TOKEN_FILE'],
      "GDRIVE_RTD_ROOT" => ENV['GDRIVE_RTD_ROOT']
      }, inline: <<-SHELL

    export DEBIAN_FRONTEND=noninteractive

    # Tuck these away into the environment so they're available to synchronize
    echo "GDRIVE_RTD_ROOT='$GDRIVE_RTD_ROOT'" >> /etc/environment

    if [ -n "$ACNG_HOST" -a -n "$ACNG_PORT" ]; then
      ACNG_URL="http://$ACNG_HOST:$ACNG_PORT"

      # Apt settings
      echo 'Using '$ACNG_URL' for deb pkg caching'
      echo 'Acquire::http::Proxy "'$ACNG_URL'";' > /etc/apt/apt.conf.d/02proxy
    fi

    if [ -f sources.list ]; then
      echo "Nearest mirror already set."
    else
      echo "Finding nearest apt mirror even when caching (not everything gets cached)"
      apt-get -y update
      apt-get install -y netselect-apt
      country=`curl -s ipinfo.io | grep country | awk -F ':' '{print $2}' | sed -e 's/[", ]//g'`
      if [ "KG" = "$country" ]; then
        country='KZ'
      fi

      netselect-apt -c $country &> /dev/null
      if [ ! "$?" = "0" ]; then
        netselect-apt -c US &> /dev/null
      fi

      if [ -f "sources.list" ]; then
        rm /etc/apt/sources.list

        while read line; do
          if [ -n "$(echo $line | egrep '^#.*')" -o -z "$(echo $line | grep '^deb .*')" ]; then
            continue;
          fi

          echo "$line non-free" >> /etc/apt/sources.list;
          echo "$line non-free" | sed -e 's/deb /deb-src /' >> /etc/apt/sources.list;
        done < sources.list
      fi
    fi

    if [ -f /root/sphinx_installed ]; then
      echo "Python and Sphinx already installed ..."
    else
      apt-get -y update
      apt-get install -y git python python-pip python-dev build-essential
      pip install --upgrade pip==9.0.3
      pip install --upgrade virtualenv
      pip install sphinx sphinx-autobuild recommonmark
      pip install sphinx_rtd_theme
      touch /root/sphinx_installed
    fi

    if [ -f /root/gdrive_installed ]; then
      echo "GDrive already installed ..."
    else
      # Get the google drive client
      wget 'https://cdn.subutai.io:8338/kurjun/rest/raw/download?id=6915b900-149d-4ad2-8440-f75b2272f1c5&token=e584e0f25663e755aac4994ba5d4e759c9380bea8b237947a6861f291e9e50cb' -O /usr/local/bin/gdrive >/dev/null 2>&1
      chmod +x /usr/local/bin/gdrive
      touch /root/gdrive_installed
    fi

    # This is huge, need libre office and ruby
    if [ -f /root/converters_installed ]; then
      echo "Converters already installed ..."
    else
      echo "Brace yourself this could take a while: libreoffice and word to markdown ruby install"
      apt-get install -y libreoffice ruby ruby-dev zlib1g-dev
      gem install word-to-markdown
      apt-get install -y pandoc
      touch /root/converters_installed
    fi

    # Before exiting in privileged mode setup iptables and routing
    # sphinx-autobuild does not listen on all interface just localhost

    # sysctl -w net.ipv4.conf.enp0s8.route_localnet=1
    # iptables -t nat -I PREROUTING -p tcp -d 172.16.0.0/16 --dport 8000 -j DNAT --to-destination 127.0.0.1:8000
  SHELL
  
  if ENV['GDRIVE_TOKEN_FILE'].nil? && ARGV[1] == 'up'
    puts 'Cannot enable google drive client without a proper token file.'
    puts 'Set the path to the token file using the GDRIVE_TOKEN_FILE environment variable.'
    puts 'If you do not have a token file, then log into the VM and run \'gdrive about\''
    puts 'It will prompt you with a URL to go to and authenticate to get a verification code.'
    puts 'You provide this code, and it stores the bearer token in a token file.'
    puts 'Copy the bearer token file generated in the VM under /home/subutai/.gdrive with'
    puts 'the name \'token_v2.json\' to somewhere safe, like your hosts $HOME/.ssh and'
    puts 'set GDRIVE_TOKEN_FILE to its path. You can then reprovision using:'
    puts ''
    puts 'GDRIVE_TOKEN_FILE=$HOME/.ssh/token_v2.json vagrant provision'
    puts ''
    puts 'You can also export this environment variable to permanently set it in'
    puts 'your shell profile file. Then you do not have to provide this value on'
    puts 'every vagrant up commands.'
  elsif !ENV['GDRIVE_TOKEN_FILE'].nil?
    config.vm.provision 'file',
      source: File.expand_path(ENV['GDRIVE_TOKEN_FILE']), 
      destination: '/tmp/token_v2.json'
  end

  config.vm.provision 'shell', privileged: false, 
  env: {
    "ACNG_HOST" => ENV['ACNG_HOST'],
    "ACNG_PORT" => ENV['ACNG_PORT'],
    "APPROX_HOST" => ENV['APPROX_HOST'],
    "APPROX_PORT" => ENV['APPROX_PORT'],
    "GDRIVE_TOKEN_FILE" => ENV['GDRIVE_TOKEN_FILE'],
    "GDRIVE_RTD_ROOT" => ENV['GDRIVE_RTD_ROOT']
    }, inline: <<-SHELL

    if [ -f /tmp/token_v2.json ]; then
      if [ ! -d $HOME/.gdrive ]; then
        mkdir $HOME/.gdrive
      fi

      mv /tmp/token_v2.json $HOME/.gdrive
      gdrive about
    else
      echo 'Google drive client could not initialize.'
      echo
      echo 'Setup bearer token file and re-provision with vagrant.'
      echo 'Will NOT attempt site generation or start sphinx auto '
      echo 'build daemon. See the following wiki for more information:'
      echo
      echo 'https://github.com/subutai-io/docs/wiki/Using-the-Vagrant-VM'
      echo
      echo 'Existing with non-zero status.'
      exit 1
    fi

    cd /readthedocs

    # This will dump into /readthedocs if the folder in gdocs is named readthedocs
    ./download.sh

    # Convert Word to Markdown
    ./convert.sh

    # Generate the RTD site with auto build daemon
    nohup sphinx-autobuild . _build/html vagrant &
  SHELL
end
