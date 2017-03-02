FROM debian:jessie

MAINTAINER Erick Almeida <ephillipe@gmail.com>

# all the apt-gets in one command & delete the cache after installing

RUN apt-get update \
    && apt-get install -y ca-certificates \
       build-essential make libpcre3-dev libssl-dev wget \
       iputils-arping libexpat1-dev unzip curl libncurses5-dev libreadline-dev \
       perl htop \
    && apt-get -q -y clean 
    
ENV TZ=America/Sao_Paulo
RUN rm -vf /etc/localtime \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime  \
    && echo $TZ > /etc/timezone

ENV NGINX_VERSION 1.9.7
ENV NGINX_STICKY_VERSION master
ENV NGINX_ECHO_VERSION 0.57
ENV NGINX_MISC_VERSION 0.28
ENV LUA_VERSION 2.0.4
ENV LUA_NGINX_VERSION 0.9.16
ENV OPENSSL_VERSION 1.0.2d
ENV PCRE2_VERSION 10.00
ENV NPS_VERSION 1.12.34.2

ADD assets/nginx-goodies-nginx-sticky-module-ng-${NGINX_STICKY_VERSION}.zip /tmp/
ADD assets/echo-nginx-module-${NGINX_ECHO_VERSION}.zip /tmp/
ADD assets/set-misc-nginx-module-${NGINX_MISC_VERSION}.zip /tmp/
ADD assets/ngx_devel_kit.zip /tmp/

ADD assets/luajit-${LUA_VERSION}.tar.gz /tmp/
ADD assets/lua-nginx-module-${LUA_NGINX_VERSION}.zip /tmp/
ADD assets/nps-v${NPS_VERSION}-beta.zip /tmp/

ADD assets/pcre2-${PCRE2_VERSION}.zip /tmp/
ADD assets/openssl-${OPENSSL_VERSION}.tar.gz /tmp/

ADD assets/GeoIP.tar.gz /tmp/
ADD assets/GeoIP.dat.gz /usr/local/share/GeoIP/
ADD assets/GeoLiteCity.dat.gz /usr/local/share/GeoIP/

RUN echo "Descompactando pacotes extras" \
 && cd /tmp/ \
 && unzip -o /tmp/nginx-goodies-nginx-sticky-module-ng-${NGINX_STICKY_VERSION}.zip \
 && unzip -o /tmp/echo-nginx-module-${NGINX_ECHO_VERSION}.zip \
 && unzip -o /tmp/set-misc-nginx-module-${NGINX_MISC_VERSION}.zip \
 && unzip -o /tmp/ngx_devel_kit.zip \
 && unzip -o /tmp/lua-nginx-module-${LUA_NGINX_VERSION}.zip \
 && unzip -o /tmp/nps-v${NPS_VERSION}-beta.zip \
 && gunzip -f /usr/local/share/GeoIP/GeoLiteCity.dat.gz \
 && gunzip -f /usr/local/share/GeoIP/GeoIP.dat.gz \
 && echo "Listando diretório temporário" \
 && ls -lh /tmp/ 

 RUN echo "NPS script Download" \
    && cd /tmp/ngx_pagespeed-${NPS_VERSION}-beta/ \
    && psol_url=https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz \
    [ -e scripts/format_binary_url.sh ] && psol_url=$(scripts/format_binary_url.sh PSOL_BINARY_URL) \
    && wget ${psol_url} \
    && tar -xzvf $(basename ${psol_url})  # extracts to psol/

RUN echo "Building GeoIP Library" \
    && cd /tmp/GeoIP-1.4.8/ \
    && ./configure \
    && make \
    && make install \
    && echo '/usr/local/lib' > /etc/ld.so.conf.d/geoip.conf \
    && ldconfig

RUN echo "Building LuaJit Library" \
    && cd /tmp/LuaJIT-${LUA_VERSION} \
    && make \
    && make PREFIX=/opt/luajit2 install
 
RUN gcc --version \ 
 && echo "Telling to nginx's build system where to find LuaJIT 2.0" \
 && export LUAJIT_LIB=/opt/luajit2/lib \
 && export LUAJIT_INC=/opt/luajit2/include/luajit-2.0 \ 
 && echo "Iniciando compilação do NGINX" \
 && curl http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar -xvz -C /tmp/ \
 && cd /tmp/nginx-${NGINX_VERSION} \ 
 && ./configure --prefix=/etc/nginx \
				--with-pcre-jit \
				--error-log-path=/var/log/nginx/error.log \
                --http-log-path=/var/log/nginx/access.log \
                --sbin-path=/usr/sbin/nginx \
                --conf-path=/etc/nginx/nginx.conf \
                --pid-path=/var/run/nginx.pid \
                --with-ipv6 \
                --with-poll_module \
                --with-http_stub_status_module \
                --with-http_geoip_module \
                --with-http_realip_module \
                --with-http_ssl_module \
                --with-http_v2_module \
                --with-http_gzip_static_module \
                --with-openssl=/tmp/openssl-${OPENSSL_VERSION} \
                --with-ld-opt='-Wl,-rpath,/opt/luajit2/lib/' \
                --add-module=/tmp/nginx-goodies-nginx-sticky-module-ng-${NGINX_STICKY_VERSION} \
                --add-module=/tmp/echo-nginx-module-${NGINX_ECHO_VERSION} \
                --add-module=/tmp/ngx_devel_kit-master \
                --add-module=/tmp/lua-nginx-module-${LUA_NGINX_VERSION} \
                --add-module=/tmp/set-misc-nginx-module-${NGINX_MISC_VERSION} \
                --add-module=/tmp/ngx_pagespeed-${NPS_VERSION}-beta \
 && echo "Configuração do NGINX concluída" \
 && make \ 
 && make install \
 && echo "Instalação do NGINX concluída" \
 && rm -rf /tmp/nginx* \
 && rm -rf /tmp/lua-nginx-module*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log   	

VOLUME ["/var/cache/nginx"]

CMD ["nginx", "-g", "daemon off;"]
