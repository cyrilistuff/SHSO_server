FROM ubuntu:latest

# Update the package lists in the Ubuntu image
RUN apt-get update

# Optionally, install additional packages
RUN apt install -y curl openjdk-8-jre

# Create a folder to persist the server data
RUN mkdir /sfs

# Download Smartfox Server Pro zip and extract it.
RUN curl -L -o SFSPRO_linux64_1.6.6.tar.gz https://www.smartfoxserver.com/download/get/77
RUN tar -xf SFSPRO_linux64_1.6.6.tar.gz --strip-components=1 -C /sfs -k || true

# Copy local files.
# ADD ./shso-server/sfs/jre /sfs/jre
RUN sed -i 's,java -cp "./:./sfsExtensions/:,java -cp "./:./sfsExtensions/:lib/mysql.jar:,g' /sfs/Server/start.sh

# Set scripts to be executable.
RUN chmod +x /sfs/Server/start.sh

WORKDIR /sfs/Server
ENTRYPOINT ["sh", "./start.sh"]
