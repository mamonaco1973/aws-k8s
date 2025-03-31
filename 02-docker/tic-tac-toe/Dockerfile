# Use the official Ubuntu 24.04 base image
FROM ubuntu:24.04

# Update the package manager and install Python 3 and pip
RUN apt update -y && \                              
    apt install -y python3-pip && \                 
    apt-get clean && \                              
    mkdir /tic-tac-toe && \                               
    chmod 777 /tic-tac-toe                                

# Copy application files to the /tic-tac-toe directory in the container
COPY game.js /tic-tac-toe/                                 
COPY index.html /tic-tac-toe                       
COPY styles.css /tic-tac-toe                     
COPY start.sh /tic-tac-toe

# Expose port 8000 for HTTP server
EXPOSE 8000                                         

# Set the default command to run the python based HTTP server
ENTRYPOINT [ "/tic-tac-toe/start.sh" ]          
