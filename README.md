# 1. Canary Deployment - NGINX

Canary Deployments allows us to test the "new" environment by splitting some of the requests' destination to this new environment, allowing us to progressively validate its functionalities.

## 1.1. Configuration file

With _nginx_ working as a load balancer, we are allowed to define which percentage of requests we'd like to have forwarded to each endpoint. Speaking in _nginx_ terms, we _proxy\_pass_ the incoming request to a [_split\_clients_](https://nginx.org/en/docs/http/ngx_http_split_clients_module.html?_ga=2.214050199.1665763877.1630400841-1500436540.1630400841) method where they will be redirected to a certain _upstream_, according to the given percentage.

Cutting out the rest of the file, here is a sample of the main ideas arround the nginx's configuration file, as describe above:
``` js
http {
    server {
        listen 8080;
        location / {
            proxy_pass         http://$app_upstream;
        }
    }

    split_clients $request_id $app_upstream {
        70% app1;
        *   app2;
    }

    upstream app1 {
        server google.pt;
    }

    upstream app2 {
        server gmail.com;
    }
}
```

## 1.2. Applying Nginx configurations

To update the configuration file and its percentages, we need to reload the configuration file into the nginx running process.

There are 2 ways for the new _nginx_ configuration to be loaded:
- On the nginx process __Startup__ [1.2.1]
- Sending a restart __Signal__ [1.2.2]
    
### 1.2.1. Nginx startup

When the nginx process is launched, the configuration file _nginx.confg_ under /etc/nginx/ is read.

As we are launching _nginx_ as a docker container, we cannot restart the nginx's process to reload it's new configuration (nginx is the Entrypoint of the Docker image), as the container would die.

Therefore, we need to recreate the Docker Container each time we need to upload a new configuration file (i.e. updating the split percentages), resulting in an undesired downtime.

To facilitate in this matter, a script was created for redeploying the nginx (load balancer) container:

``` bash
#!/bin/bash

echo 'Removing "nginx-custom" Docker Container...'
docker container rm -f nginx-custom
echo '"nginx-custom" Docker Container removed successfully!'

echo 'Launching new "nginx-custom" container...'
docker run --name nginx-custom -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro -d -p 8080:8080 nginx:latest;
```

The script above used nginx's latest image and mounts the _nginx.conf_ inside the script's directory to the _nginx_'s configuration file location to make it easier to apply changes.

### 1.2.2. Signal Restart

To avoid recreating a container and going through a short downtime, there is another method which applies the new configuration with a "graceful restart" ([source](https://www.nginx.com/blog/dynamic-reconfiguration-with-nginx-plus/))

- ```  When you change a configuration file and restart NGINX to pick up the new configuration, it implements a “graceful restart”. Both the old and new copies of NGINX run side by side for a short period of time. The old processes don’t accept any new connections and terminate once all their existing connections terminate. ```

The way this works, is we send a signal to the nginx client, telling it what we desire to do, through the following command: ```nginx -s <SIGNAL>```

There are [4 possible signals](https://docs.nginx.com/nginx/admin-guide/basic-functionality/runtime-control/):
- **quit** – Shut down gracefully
- **reload** – Reload the configuration file
- **reopen** – Reopen log files
- **stop** – Shut down immediately (fast shutdown)

Using the _docker exec_ command, we can send a restart signal to the nginx client:

``` bash
# syntax
docker exec -it {​​​​​​​​container_name}​​​​​​​​ {​​​​​​​​command}​​​​​​​​
# example
docker exec -it nginx-custom nginx -s reload
```

## 1.3. Testing the load balancer

To test the Load Balancer, we can use the [Apache Benchmark](https://httpd.apache.org/docs/2.4/programs/ab.html) tool to make sure the traffic gets forwarded properly.

``` bash
# syntax
ab -n <requests_nr> -c <parallel_requests> <endpoint>
# example
ab -n 200 -c 10 http://51.124.107.250:8080/
```

After that, we can take the metrics through a _grep_ to the Docker Container's logs:

``` bash
# example
docker logs nginx-custom | grep gmail.com | wc
    (output)     69     414    2760
docker logs nginx-custom | grep google.pt | wc
    (output)     56     336    2240
```
