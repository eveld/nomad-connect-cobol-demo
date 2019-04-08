job "banking" {
  datacenters = ["dc1"]
  type = "service"

  group "backend" {
    count = 1

    restart {
      attempts = 2
      interval = "30m"
      delay = "15s"

      mode = "fail"
    }

    task "cobol" {
      driver = "exec"

      artifact {
        source = "http://localhost:8888/files/wrapper.zip"
      }

      artifact {
        source = "http://localhost:8888/files/banking.zip"
      }

      artifact {
        source = "http://localhost:8888/files/accounts.db"
        destination = "data"
      }

      config {
        command = "wrapper"
        args = [
          "${NOMAD_ADDR_http}"
        ]
      }

      env {
        PATH = "$PATH:${NOMAD_TASK_DIR}"
      }

      resources {
        cpu    = 500
        memory = 256
        network {
          mbits = 10
          port "http" {}
        }
      }
    }

    task "sidecar" {
      driver = "exec"

      config {
        command = "consul"
        args    = [
          "connect", "envoy",
          "-sidecar-for", "cobol-${NOMAD_ALLOC_ID}",
          "-admin-bind", "${NOMAD_ADDR_envoyadmin}"
        ]
      }

      artifact {
        source = "http://localhost:8888/files/consul.zip"
      }

      artifact {
        source = "http://localhost:8888/files/envoy.zip"
      }

      env {
        PATH="${PATH}:${NOMAD_TASK_DIR}"
      }

      resources {
        network {
          port "ingress" {}
          port "envoyadmin" {}
        }
      }
    }

    task "register" {
      driver = "exec"
      kill_timeout = "10s"

      artifact {
        source = "http://localhost:8888/files/consul.zip"
      }

      config {
        command = "bash"
        args = [
          "local/init.sh"
        ]
      }

      env {
        PATH="${PATH}:${NOMAD_TASK_DIR}"
      }

      template {
        data = <<EOH
        {
          "service": {
            "name": "cobol",
            "ID": "cobol-{{ env "NOMAD_ALLOC_ID" }}",
            "port": {{ env "NOMAD_PORT_cobol_http" }},
            "connect": {
              "sidecar_service": {
                "port": {{ env "NOMAD_PORT_sidecar_ingress" }},
                "proxy": {
                  "local_service_address": "{{ env "NOMAD_IP_cobol_http" }}"
                }
              }
            }
          }
        }
        EOH
        destination = "local/service.json"
      }

      template {
        data = <<EOH
        #!/bin/bash
        set -x
        consul services register local/service.json
        trap "consul services deregister local/service.json" INT
        tail -f /dev/null &
        PID=$!
        wait $PID
        EOH

        destination = "local/init.sh"
      }

      resources {
        memory = 100
      }
    }
  }

  group "frontend" {
    count = 1

    restart {
      attempts = 2
      interval = "30m"
      delay = "15s"

      mode = "fail"
    }

    task "rating" {
      driver = "exec"

      artifact {
        source = "http://localhost:8888/files/rating.zip"
      }

      config {
        command = "rating"
        args = [
          "${NOMAD_ADDR_http}",
          "${NOMAD_ADDR_sidecar_upstream}"
        ]
      }

      env {
        PATH = "$PATH:${NOMAD_TASK_DIR}"
      }

      resources {
        cpu    = 500
        memory = 256
        network {
          mbits = 10
          port "http" {}
        }
      }
    }

    task "sidecar" {
      driver = "exec"

      config {
        command = "consul"
        args    = [
          "connect", "envoy",
          "-sidecar-for", "rating-${NOMAD_ALLOC_ID}",
          "-admin-bind", "${NOMAD_ADDR_envoyadmin}"
        ]
      }

      artifact {
        source = "http://localhost:8888/files/consul.zip"
      }

      artifact {
        source = "http://localhost:8888/files/envoy.zip"
      }

      env {
        PATH="${PATH}:${NOMAD_TASK_DIR}"
      }

      resources {
        network {
          port "upstream" {}
          port "ingress" {}
          port "envoyadmin" {}
        }
      }
    }

    task "register" {
      driver = "exec"
      kill_timeout = "10s"

      artifact {
        source = "http://localhost:8888/files/consul.zip"
      }

      config {
        command = "bash"
        args = [
          "local/init.sh"
        ]
      }

      env {
        PATH="${PATH}:${NOMAD_TASK_DIR}"
      }

      template {
        data = <<EOH
        {
          "service": {
            "name": "rating",
            "ID": "rating-{{ env "NOMAD_ALLOC_ID" }}",
            "port": {{ env "NOMAD_PORT_rating_http" }},
            "connect": {
              "sidecar_service": {
                "port": {{ env "NOMAD_PORT_sidecar_ingress" }},
                "proxy": {
                  "local_service_address": "{{ env "NOMAD_IP_rating_http" }}",
                  "upstreams": [
                    {
                      "destination_name": "cobol",
                      "local_bind_port": {{ env "NOMAD_PORT_sidecar_upstream"}}
                    }
                  ]
                }
              }
            }
          }
        }
        EOH
        destination = "local/service.json"
      }

      template {
        data = <<EOH
        #!/bin/bash
        set -x
        consul services register local/service.json
        trap "consul services deregister local/service.json" INT
        tail -f /dev/null &
        PID=$!
        wait $PID
        EOH

        destination = "local/init.sh"
      }

      resources {
        memory = 100
      }
    }
  }

  group "website" {
    count = 1

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:latest"

        network_mode = "host"
        
        volumes = [
          "local/index.html:/usr/share/nginx/html/index.html",
          "local/nginx.conf:/etc/nginx/nginx.conf"
        ]

        port_map {
          http = 80
        }
      }

      artifact {
        source = "http://localhost:8888/files/index.html"
      }

      template {
        data = <<EOH
        events {
          worker_connections  1024;
        }

        http {
          upstream api {
            keepalive 100;
            server 127.0.0.1:{{ env "NOMAD_PORT_sidecar_upstream" }};
          }

          server {
            location / {
              root   /usr/share/nginx/html;
              index  index.html;
            }

            location /upload {
              proxy_http_version 1.1;
              proxy_pass http://api;
              proxy_pass_request_headers on;
            }
          }
        }
        EOH
        destination = "local/nginx.conf"
      }

      resources {
        network {
          port "http" {}
        }
      }
    }

    task "sidecar" {
      driver = "exec"

      config {
        command = "consul"
        args    = [
          "connect", "envoy",
          "-sidecar-for", "website-${NOMAD_ALLOC_ID}",
          "-admin-bind", "${NOMAD_ADDR_envoyadmin}"
        ]
      }

      artifact {
        source = "http://localhost:8888/files/consul.zip"
      }

      artifact {
        source = "http://localhost:8888/files/envoy.zip"
      }

      env {
        PATH="${PATH}:${NOMAD_TASK_DIR}"
      }

      resources {
        network {
          port "upstream" {}
          port "envoyadmin" {}
        }
      }
    }

    task "register" {
      driver = "exec"
      kill_timeout = "10s"

      artifact {
        source = "http://localhost:8888/files/consul.zip"
      }

      config {
        command = "bash"
        args = [
          "local/init.sh"
        ]
      }

      env {
        PATH="${PATH}:${NOMAD_TASK_DIR}"
      }

      template {
        data = <<EOH
        {
          "service": {
            "name": "website",
            "ID": "website-{{ env "NOMAD_ALLOC_ID" }}",
            "port": {{ env "NOMAD_PORT_nginx_http" }},
            "connect": {
              "sidecar_service": {
                "proxy": {
                  "upstreams": [
                    {
                      "destination_name": "rating",
                      "local_bind_port": {{ env "NOMAD_PORT_sidecar_upstream" }}
                    }
                  ]
                }
              }
            }
          }
        }
        EOH
        destination = "local/service.json"
      }

      template {
        data = <<EOH
        #!/bin/bash
        set -x
        consul services register local/service.json
        trap "consul services deregister local/service.json" INT
        tail -f /dev/null &
        PID=$!
        wait $PID
        EOH

        destination = "local/init.sh"
      }

      resources {
        memory = 100
      }
    }
  }
}