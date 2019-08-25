job "hello" {

  datacenters = ["dc1"]

  group "webs" {
    task "http" {
      driver = "docker"

      config {
        image = "hashicorp/http-echo:0.2.3"
        args = [
          "-listen=:${NOMAD_PORT_http}",
          "-text='Hey dude, wassup!'",
        ]
      }
    
      resources {
        cpu    = 500 # MHz
        memory = 128 # MB

        network {
          mbits = 100
          port "http"  {}
          port "https" {}
        }
      }
    }
  }
}
