#FROM ghcr.io/oracle/oraclelinux8-instantclient:23doc
FROM oraclelinux:9
# Update the package list
RUN dnf update -y

# Install Python 3.12
RUN dnf install -y python3.12 


RUN python3.12 -m ensurepip
##same for the every underlying os
## Set the environment variable for Python 3.12
ENV PATH=$PATH:/usr/local/bin/python3.12

# Set the default command to run when the container is started
# CMD ["python3.12", "-V"]
WORKDIR /app

COPY requirements.txt . 

COPY ui.py . 
#this is actual logic

RUN pip3 install --no-cache-dir -r requirements.txt 

RUN python3.12 -m pip install --upgrade pip setuptools 

EXPOSE 8501 

HEALTHCHECK CMD curl --fail http://localhost:8501/_stcore/health

ENTRYPOINT ["streamlit", "run", "ui.py", "--server.port=8501", "--server.address=0.0.0.0"]
