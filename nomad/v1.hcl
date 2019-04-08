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
  }
}