FROM --platform=linux/amd64 ubuntu:20.04 as build-dep

# Use bash for the shell
SHELL ["bash", "-c"]

# Install Node
ENV NODE_VER="14.18.1"
RUN	echo "Etc/UTC" > /etc/localtime && \
	apt update && \
	apt -y install libc6 wget make gcc g++ python && \
	cd ~ && \
	wget https://nodejs.org/download/release/v$NODE_VER/node-v$NODE_VER.tar.gz && \
	tar xf node-v$NODE_VER.tar.gz && \
	cd node-v$NODE_VER && \
	./configure --prefix=/opt/node && \
	make -j$(nproc) > /dev/null && \
	make install

# Install jemalloc
ENV JE_VER="5.2.1"
RUN apt update && \
	apt -y install autoconf && \
	cd ~ && \
	wget https://github.com/jemalloc/jemalloc/archive/$JE_VER.tar.gz && \
	tar xf $JE_VER.tar.gz && \
	cd jemalloc-$JE_VER && \
	./autogen.sh && \
	./configure --prefix=/opt/jemalloc && \
	make -j$(nproc) > /dev/null && \
	make install_bin install_include install_lib

# Install ruby
ENV RUBY_VER="2.6.5"
ENV CPPFLAGS="-I/opt/jemalloc/include"
ENV LDFLAGS="-L/opt/jemalloc/lib/"
RUN apt update && \
	apt -y install build-essential \
		bison libyaml-dev libgdbm-dev libreadline-dev \
		libncurses5-dev libffi-dev zlib1g-dev libssl-dev && \
	cd ~ && \
	wget https://cache.ruby-lang.org/pub/ruby/${RUBY_VER%.*}/ruby-$RUBY_VER.tar.gz && \
	tar xf ruby-$RUBY_VER.tar.gz && \
	cd ruby-$RUBY_VER && \
	./configure --prefix=/opt/ruby \
	  --with-jemalloc \
	  --with-shared \
	  --disable-install-doc && \
	ln -s /opt/jemalloc/lib/* /usr/lib/ && \
	make -j$(nproc) > /dev/null && \
	make install

ENV PATH="${PATH}:/opt/ruby/bin:/opt/node/bin"

# Install package dependency managers
RUN npm install -g yarn && \
	gem install bundler && \
	apt update && \
	apt -y install git libicu-dev libidn11-dev \
	libpq-dev libprotobuf-dev protobuf-compiler

COPY Gemfile* package.json yarn.lock /opt/gabsocial/

# Install application dependencies
RUN cd /opt/gabsocial && \
	bundle install -j$(nproc) --deployment --without development test && \
	yarn install --pure-lockfile

FROM --platform=linux/amd64 ubuntu:20.04

# Copy over all the langs needed for runtime
COPY --from=build-dep /opt/node /opt/node
COPY --from=build-dep /opt/ruby /opt/ruby
COPY --from=build-dep /opt/jemalloc /opt/jemalloc

# Add more PATHs to the PATH
ENV PATH="${PATH}:/opt/ruby/bin:/opt/node/bin:/opt/gabsocial/bin"

# Create the gabsocial user
ARG UID=991
ARG GID=991
RUN apt update && \
	echo "Etc/UTC" > /etc/localtime && \
	ln -s /opt/jemalloc/lib/* /usr/lib/ && \
	apt -y dist-upgrade && \
	apt install -y vim whois wget && \
	addgroup --gid $GID gabsocial && \
	useradd -m -u $UID -g $GID -d /opt/gabsocial gabsocial && \
	echo "gabsocial:`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 | mkpasswd -s -m sha-256`" | chpasswd

# Install gabsocial runtime deps
RUN apt -y --no-install-recommends install \
	  libssl1.1 libpq5 imagemagick ffmpeg \
	  libicu66 libprotobuf17 libidn11 libyaml-0-2 \
	  file ca-certificates tzdata libreadline8 && \
	apt -y install gcc && \
	ln -s /opt/gabsocial /gabsocial && \
	gem install bundler && \
	rm -rf /var/cache && \
	rm -rf /var/lib/apt/lists/*

# Add tini
ENV TINI_VERSION="0.18.0"
ENV TINI_SUM="12d20136605531b09a2c2dac02ccee85e1b874eb322ef6baf7561cd93f93c855"
ADD https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini /tini
RUN echo "$TINI_SUM tini" | sha256sum -c -
RUN chmod +x /tini

# Copy over masto source, and dependencies from building, and set permissions
COPY --chown=gabsocial:gabsocial . /opt/gabsocial
COPY --from=build-dep --chown=gabsocial:gabsocial /opt/gabsocial /opt/gabsocial

# Run masto services in prod mode
ENV RAILS_ENV="production"
ENV NODE_ENV="production"

# Tell rails to serve static files
ENV RAILS_SERVE_STATIC_FILES="true"

# Set the run user
USER gabsocial

# Precompile assets
RUN cd ~ && \
	OTP_SECRET=precompile_placeholder SECRET_KEY_BASE=precompile_placeholder rails assets:precompile && \
	yarn cache clean

# Set the work dir and the container entry point
WORKDIR /opt/gabsocial
ENTRYPOINT ["/tini", "--"]
