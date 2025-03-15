# Guía de Configuración y Despliegue en Kubernetes

## Paso 1. Configurar el entorno de trabajo

Antes de comenzar, es fundamental asegurarse de que el entorno está listo. Cada estudiante o grupo debe tener instalado:

- **Docker**: para crear contenedores.
- **Minikube o un clúster de Kubernetes**: para la orquestación.
- **Kubectl**: para administrar Kubernetes.
- **Git y GitHub**: para el control de versiones y el almacenamiento del código.

### Comandos básicos para verificar instalaciones:

```sh
docker --version  
kubectl version --client  
minikube version
```

## Paso 2. Construcción y publicación del contenedor con Docker

Cada grupo debe crear un `Dockerfile` que defina el entorno en el que se ejecutará la aplicación.

### Ejemplo de `Dockerfile`:

```dockerfile
FROM node:18  
WORKDIR /app  
COPY . /app  
RUN npm install
CMD ["npm", "start"]  
EXPOSE 3000
```

### Para construir y probar el contenedor localmente:

```sh
docker build -t mi-api .
docker run -d -p 3000:3000 mi-api
```

### Para subir la imagen a Docker Hub:

```sh
docker tag mi-api usuario-propio-reemplazar/mi-api:latest
docker push usuario-propio-reemplazar/mi-api:latest
```

## Paso 3. Desplegar la aplicación en Kubernetes

Ahora, el equipo debe definir los archivos de configuración en Kubernetes, organizados en una carpeta `kubernetes/`.

### Ejemplo de `deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mi-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: mi-api
  template:
    metadata:
      labels:
        app: mi-api
    spec:
      containers:
      - name: mi-api
        image: usuario-propio-reemplazar/mi-api:latest
        ports:
        - containerPort: 3000
```

### Ejemplo de `service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mi-api-service
spec:
  selector:
    app: mi-api
  ports:
    - protocol: TCP
      port: 80
      targetPort: 3000
  type: LoadBalancer
```

### Para aplicar los cambios en Kubernetes:

```sh
kubectl apply -k kubernetes/
kubectl get pods
kubectl get services
```

### Para obtener la URL del servicio:

```sh
minikube service mi-api-service --url
```

## Paso 4. Implementar escalabilidad automática

Para garantizar que el sistema se adapte a la demanda, se debe configurar un **Horizontal Pod Autoscaler (HPA)**.

### Ejemplo de `hpa.yaml`:

```yaml
apiVersion: autoscaling/v2beta2
kind: HorizontalPodAutoscaler
metadata:
  name: mi-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: mi-api
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

### Para aplicar el HPA en Kubernetes:

```sh
kubectl apply -f kubernetes/hpa.yaml
kubectl get hpa
```

### Para simular carga y probar la escalabilidad:

```sh
kubectl run -i --tty load-generator --rm --image=busybox -- /bin/sh
while true; do wget -q -O- http://mi-api-service; done
```

## Paso 5. Simulación de fallos y prueba de resiliencia

Para verificar si Kubernetes maneja correctamente los fallos, se eliminará un pod y se validará si se recrea automáticamente.

### Eliminar un pod:

```sh
kubectl delete pod mi-api-XXXX
kubectl get pods
```

Si el pod no se recrea automáticamente, verificar el número de réplicas:

```sh
kubectl get deployment mi-api
kubectl scale deployment mi-api --replicas=3
```

## Paso 6. Aplicar Infraestructura como Código (IaC)

Para hacer el despliegue más eficiente, se recomienda usar herramientas como **Ansible** o **Terraform**.

### Ejemplo de `main.tf` con Terraform:

```hcl
provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_deployment" "mi_api" {
  metadata {
    name = "mi-api"
    labels = {
      app = "mi-api"
    }
  }
  spec {
    replicas = 3
    selector {
      match_labels = {
        app = "mi-api"
      }
    }
    template {
      metadata {
        labels = {
          app = "mi-api"
        }
      }
      spec {
        container {
          image = "usuario-propio-reemplazar/mi-api:latest"
          name  = "mi-api"
          port {
            container_port = 3000
          }
        }
      }
    }
  }
}
```

### Para aplicar Terraform:

```sh
terraform init
terraform apply
```

