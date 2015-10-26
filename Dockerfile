FROM debian:jessie

MAINTAINER Erick Almeida <ephillipe@gmail.com>

# all the apt-gets in one command & delete the cache after installing

RUN apt-get update \
    && apt-get install -y ca-certificates \
       build-essential make libpcre3-dev libssl-dev wget \
       iputils-arping libexpat1-dev unzip curl libncurses5-dev libreadline-dev \
       perl htop \
    && apt-get -q -y clean 

ENV NGINX_VERSION 1.9.5
ENV NGINX_STICKY_VERSION 1.2.6
ENV NGINX_ECHO_VERSION 0.57
ENV NGINX_MISC_VERSION 0.28
ENV LUA_VERSION 2.0.4
ENV LUA_NGINX_VERSION 0.9.16
ENV OPENSSL_VERSION 1.0.2d
ENV PCRE2_VERSION 10.00

ADD assets/nginx-${NGINX_VERSION}.tar.gz /tmp/
ADD assets/nginx-sticky-module-${NGINX_STICKY_VERSION}.zip /tmp/
ADD assets/echo-nginx-module-${NGINX_ECHO_VERSION}.zip /tmp/
ADD assets/set-misc-nginx-module-${NGINX_MISC_VERSION}.zip /tmp/
ADD assets/ngx_devel_kit.zip /tmp/

ADD assets/luajit-${LUA_VERSION}.tar.gz /tmp/
ADD assets/lua-nginx-module-${LUA_NGINX_VERSION}.zip /tmp/

ADD assets/pcre2-${PCRE2_VERSION}.zip /tmp/
ADD assets/openssl-${OPENSSL_VERSION}.tar.gz /tmp/

ADD assets/GeoIP.tar.gz /tmp/
ADD assets/GeoIP.dat.gz /usr/local/share/GeoIP/
ADD assets/GeoLiteCity.dat.gz /usr/local/share/GeoIP/

# Build GeoIP:
RUN cd /tmp/GeoIP-1.4.8/ \
    && ./configure \
    && make \
    && make install \
    && echo '/usr/local/lib' > /etc/ld.so.conf.d/geoip.conf \
    && ldconfig

# Build LuaJit and tell nginx's build system where to find LuaJIT 2.0:
RUN cd /tmp/LuaJIT-${LUA_VERSION} \
    && make \
    && make PREFIX=/opt/luajit2 install \
    && export LUAJIT_LIB=/opt/luajit2/lib/ \
    && export LUAJIT_INC=/opt/luajit2/include/luajit-${LUA_VERSION}/
    
RUN unzip -o /tmp/nginx-sticky-module-${NGINX_STICKY_VERSION}.zip \
 && unzip -o /tmp/echo-nginx-module-${NGINX_ECHO_VERSION}.zip \
 && unzip -o /tmp/set-misc-nginx-module-${NGINX_MISC_VERSION}.zip \
 && unzip -o /tmp/ngx_devel_kit.zip \
 && unzip -o /tmp/lua-nginx-module-${LUA_NGINX_VERSION}.zip \
 && ls -lh /tmp/ 
 
RUN gcc --version \ 
 && cd /tmp/nginx-${NGINX_VERSION}/ \ 
 && echo "Iniciando compilação do NGINX" \
 && ./configure --prefix=/etc/nginx \
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
                --add-module=/tmp/nginx-goodies-nginx-sticky-module-ng-c78b7dd79d0d \
                --add-module=/tmp/echo-nginx-module-${NGINX_ECHO_VERSION} \
                --add-module=/tmp/ngx_devel_kit-master \
                --add-module=/tmp/lua-nginx-module-${LUA_NGINX_VERSION} \
                --add-module=/tmp/set-misc-nginx-module-${NGINX_MISC_VERSION} \
 && echo "Configuração do NGINX concluída" \
 && make \
 && make install \
 && rm -rf /tmp/nginx* \
 && rm -rf /tmp/lua-nginx-module*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

VOLUME ["/var/cache/nginx"]

CMD ["nginx", "-g", "daemon off;"]
