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
        source = "http://localhost:8888/files/wrapper"
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
        source = "http://localhost:8888/files/envoy.tar.gz"
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
}