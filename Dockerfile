FROM debian

RUN apt-get update -y
RUN apt-get install -y wget gcc make gpg \
    libdb-dev libncurses5-dev libgmp-dev autoconf

RUN wget https://s3.amazonaws.com/morecobol/gnucobol-3.0-rc1/gnucobol-3.0-rc1.tar.gz \
         https://s3.amazonaws.com/morecobol/gnucobol-3.0-rc1/gnucobol-3.0-rc1.tar.gz.sig \
         https://ftp.gnu.org/gnu/gnu-keyring.gpg
RUN gpg --verify --keyring ./gnu-keyring.gpg gnucobol-3.0-rc1.tar.gz.sig
RUN tar zxf gnucobol-3.0-rc1.tar.gz

WORKDIR /gnucobol-3.0-rc1
RUN ./configure
RUN make
RUN make install
RUN make check
RUN ldconfig

WORKDIR /
COPY dist/banking /usr/local/bin/banking
COPY dist/balance.txt /root/balance.txt
RUN chmod +x /usr/local/bin/banking

COPY dist/wrapper /usr/local/bin/wrapper
RUN chmod +x /usr/local/bin/wrapper

EXPOSE 8080
ENTRYPOINT "/usr/local/bin/wrapper"