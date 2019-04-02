job "banking" {
  datacenters = ["dc1"]
  type = "service"

  group "web" {
    count = 1

    restart {
      attempts = 2
      interval = "30m"
      delay = "15s"

      mode = "fail"
    }

    ephemeral_disk {
      size = 300
    }

    task "cobol" {
      driver = "docker"

      config {
        image = "eveld/cobol"

        port_map {
          http = 8080
        }
      }

      resources {
        cpu    = 500
        memory = 256
        network {
          mbits = 10
          port "http" {}
        }
      }

    //   service {
    //     name = "redis-cache"
    //     tags = ["global", "cache"]
    //     port = "db"
    //     check {
    //       name     = "alive"
    //       type     = "tcp"
    //       interval = "10s"
    //       timeout  = "2s"
    //     }
    //   }

      # The "template" stanza instructs Nomad to manage a template, such as
      # a configuration file or script. This template can optionally pull data
      # from Consul or Vault to populate runtime configuration data.
      #
      # For more information and examples on the "template" stanza, please see
      # the online documentation at:
      #
      #     https://www.nomadproject.io/docs/job-specification/template.html
      #
      # template {
      #   data          = "---\nkey: {{ key \"service/my-key\" }}"
      #   destination   = "local/file.yml"
      #   change_mode   = "signal"
      #   change_signal = "SIGHUP"
      # }

      # The "template" stanza can also be used to create environment variables
      # for tasks that prefer those to config files. The task will be restarted
      # when data pulled from Consul or Vault changes.
      #
      # template {
      #   data        = "KEY={{ key \"service/my-key\" }}"
      #   destination = "local/file.env"
      #   env         = true
      # }
    }
  }
}