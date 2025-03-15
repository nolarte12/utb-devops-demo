provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_deployment" "ms_practice_mentoring_backend" {
  metadata {
    name = "utb-devops-demo"
    labels = {
      app = "utb-devops-demo"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "utb-devops-demo"
      }
    }

    template {
      metadata {
        labels = {
          app = "utb-devops-demo"
        }
      }

      spec {
        container {
          name  = "utb-devops-demo"
          image = "docker.io/nolartes12/utb-devops-demo:latest"

          port {
            container_port = 8080
          }

          resources {
            requests = {
              cpu = "100m"
            }
            limits = {
              cpu = "500m"
            }
          }
        }
      }
    }
  }
}
