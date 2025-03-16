provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_deployment" "utb-devops-demo" {
  metadata {
    name = "utb-devops-demo"
    labels = {
      app = "utb-devops-demo"
    }
  }

  spec {
    replicas = 2

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
        # Configuración de seguridad: Pod Security Context
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          fs_group        = 1000
        }

        container {
          name  = "utb-devops-demo"
          image = "docker.io/nelsflde/utb-devops-demo:latest"

          port {
            container_port = 8080
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          # Configuración de seguridad: Container Security Context
          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
          }

          # liveness probe
          liveness_probe {
            http_get {
              path = "actuator/health"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          # Directorio para escritura temporal
          volume_mount {
            name       = "tmp-volume"
            mount_path = "/tmp"
          }
        }

        # Volumen temporal escribir en /tmp
        volume {
          name = "tmp-volume"
          empty_dir {}
        }
      }
    }
  }
}

# Service para exponer la aplicación
resource "kubernetes_service" "utb-devops-demo" {
  metadata {
    name = "utb-devops-demo"
  }
  spec {
    selector = {
      app = "utb-devops-demo"
    }
    port {
      port        = 80
      target_port = 8080
    }
    type = "ClusterIP"
  }
}

# Horizontal Pod Autoscaler para escalado automático
resource "kubernetes_horizontal_pod_autoscaler_v1" "utb-devops-demo" {
  metadata {
    name = "utb-devops-demo-hpa"
  }

  spec {
    max_replicas = 10
    min_replicas = 2

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.utb-devops-demo.metadata[0].name
    }

    target_cpu_utilization_percentage = 50
  }
}

# NetworkPolicy para restringir tráfico
resource "kubernetes_network_policy" "utb-devops-demo" {
  metadata {
    name = "utb-devops-demo-policy"
  }

  spec {
    pod_selector {
      match_labels = {
        app = "utb-devops-demo"
      }
    }

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "default"
          }
        }
      }
      ports {
        port     = 8080
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress"]
  }
}
