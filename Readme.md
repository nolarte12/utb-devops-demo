# Guía de Configuración y Despliegue en Kubernetes

## Paso 1. Configurar el entorno de trabajo

Antes de comenzar, es fundamental asegurarse de que el entorno está listo:

- **Docker**: para crear contenedores.
- **Minikube o un clúster de Kubernetes**: para la orquestación.
- **Kubectl**: para administrar Kubernetes.
- **Git y GitHub**: para el control de versiones y el almacenamiento del código.

### Comandos básicos para verificar instalaciones:

```sh
docker --version  
kubectl version --client  
minikube version
terraform version

## Instalar metricas en el minikube
minikube addons enable metrics-server
```

Verificar que metrics-server esté funcionando:

```sh
kubectl get deployment metrics-server -n kube-system
```

## Paso 2. Construcción y publicación del contenedor con Docker

### `Dockerfile`:

```dockerfile
FROM amazoncorretto:21

WORKDIR /app/utb-devops-demo

COPY ./build/libs/demo-0.0.1-SNAPSHOT.jar .

EXPOSE 8080

CMD ["java", "-jar", "demo-0.0.1-SNAPSHOT.jar"]
```

### Para construir y probar el contenedor localmente:

```sh
docker build -t utb-devops-demo .
docker run -d -p 8080:8080 utb-devops-demo
```

### Para subir la imagen a Docker Hub:

```sh
docker tag utb-devops-demo usuario-reemplazar/utb-devops-demo:latest
docker push usuario-reemplazar/utb-devops-demo:latest
```

## Paso 3. Desplegar la aplicación en Kubernetes

Archivos de configuración en Kubernetes, organizados en una carpeta `kubernetes/`.

### `deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: utb-devops-demo
  labels:
    app: utb-devops-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: utb-devops-demo
  template:
    metadata:
      labels:
        app: utb-devops-demo
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
        - name: utb-devops-demo
          image: docker.io/nelsflde/utb-devops-demo:latest
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "256Mi"
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            readOnlyRootFilesystem: true
          livenessProbe:
            httpGet:
              path: actuator/health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
          volumeMounts:
            - name: tmp-volume
              mountPath: /tmp
      volumes:
        - name: tmp-volume
          emptyDir: {}
```

### `service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: utb-devops-demo
spec:
  selector:
    app: utb-devops-demo
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP
```

### `hpa.yaml`:

```yaml
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: utb-devops-demo-hpa
spec:
  maxReplicas: 10
  minReplicas: 2
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: utb-devops-demo
  targetCPUUtilizationPercentage: 50
```

### `networkpolicy.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: utb-devops-demo-policy
spec:
  podSelector:
    matchLabels:
      app: utb-devops-demo
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: default
      ports:
        - protocol: TCP
          port: 8080
  policyTypes:
    - Ingress
```  

### Para aplicar los cambios en Kubernetes:

```sh
kubectl apply -k kubernetes/
kubectl get pods
kubectl get services
kubectl get hpa
kubectl get networkpolicies
```

### URL del servicio: 

```sh
minikube service utb-devops-demo --url
```

### Para simular carga y probar la escalabilidad:

```sh
kubectl run -i --tty load-generator --rm --image=busybox -- /bin/sh
while true; do wget -q -O- http://utb-devops-demo.default.svc.cluster.local/api/hello-world; done
```

## Paso 4. Simulación de fallos y prueba de resiliencia

Para verificar si Kubernetes maneja correctamente los fallos, se eliminará un pod y se validará si se recrea automáticamente.

### Eliminar un pod:

```sh
kubectl delete pod pod utb-devops-demo-XXXX
kubectl get pods
```

## Paso 5. Aplicar Infraestructura como Código (IaC)

Para hacer el despliegue más eficiente, se uso **Terraform**.

### `main.tf`:

```hcl
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
```

### Aplicar Terraform:

```sh
terraform init
terraform apply -auto-approve
terraform terraform state list
```

### Destruir el ambiente Terraform:

```sh
terraform destroy -auto-approve
```

