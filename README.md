# 📘 Ejecutar Ollama en Docker Offline (con modelos Llama 3)

## 🔹 Requisitos previos
1. **WSL2** activado en Windows. Verificar con:
   ```powershell
   wsl --status
   ```
2. **Docker Desktop** con integración WSL2 habilitada.
3. **GPU NVIDIA** (opcional, pero recomendado).
   - Comprobar en el host:
     ```bash
     nvidia-smi
     ```

---

## 🔹 Configuración de GPU en Docker
Si al probar:
```bash
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```
no funciona, instala el **NVIDIA Container Toolkit** dentro de WSL:

```bash
# Añadir repositorio
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |   sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit.gpg] https://#' |   sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Instalar toolkit
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configurar Docker
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

Probar de nuevo:
```bash
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

---

## 🔹 Descargar imagen de Ollama y modelos
1. Descargar la imagen base de Ollama:
   ```bash
   docker pull ollama/ollama:latest
   ```

2. Levantar un contenedor temporal (con internet) para bajar modelos:
   ```bash
   docker run -d --gpus all -p 11434:11434 --name ollama-tmp ollama/ollama:latest
   ```

3. Entrar en el contenedor:
   ```bash
   docker exec -it ollama-tmp bash
   ```

4. Descargar modelos (ejemplo con **Llama 3.2 (3B)** y **Llama 3.1 (8B)**):
   ```bash
   ollama pull llama3.2
   ollama pull llama3.1:8b
   ```

---

## 🔹 Crear Modelfiles personalizados
### Ejemplo 1: Profesor amable (basado en `llama3.2`)
En el host:
```bash
echo 'FROM llama3.2
SYSTEM "Eres un profesor amable que responde con ejemplos sencillos. Siempre debes explicar como si enseñaras a un estudiante de secundaria. Arranca siempre pidiendo a los estudiantes que presenten atencion"' > Modelfile_profesor
```

Copiarlo al contenedor:
```bash
docker cp Modelfile_profesor ollama-tmp:/root/Modelfile_profesor
```

Dentro del contenedor:
```bash
ollama create profesor-amable -f /root/Modelfile_profesor
```

### Ejemplo 2: Razonador paso a paso (basado en `llama3.1:8b`)
En el host:
```bash
echo 'FROM llama3.1:8b
SYSTEM "Eres un experto en razonamiento lógico. Siempre explica tus respuestas paso a paso, mostrando el razonamiento detrás de cada conclusión. Arranca siempre pidiendo a los universitarios que se callen"' > Modelfile_razonador
```

Copiar y crear en el contenedor:
```bash
docker cp Modelfile_razonador ollama-tmp:/root/Modelfile_razonador
docker exec -it ollama-tmp bash -c "ollama create razonador -f /root/Modelfile_razonador"
```

---

## 🔹 Crear imagen offline con modelos incluidos
1. Parar el contenedor temporal:
   ```bash
   docker stop ollama-tmp
   ```

2. Guardar su estado como imagen nueva:
   ```bash
   docker commit ollama-tmp ollama-offline
   ```
## 🔹 Eliminar imagen online
   ```bash
   docker stop ollama-tmp
   docker rm ollama-tmp
   docker rmi ollama/ollama:latest
   ```

---


## 🔹 Usar Ollama en modo offline (servidor estable)
Levantar el servidor Ollama sin internet:
```bash
docker run -d --network=none --gpus all -p 11434:11434 --name ollama-off ollama-offline
```

Entrar al chat con tu modelo:
```bash
docker exec -it ollama-off ollama run profesor-amable
```

O con el modelo de razonamiento:
```bash
docker exec -it ollama-off ollama run razonador
```

## 🔹 Script de arranque con prompts embebidos
En lugar de usar `Modelfiles` externos, puedes gestionar los prompts directamente en el script.  
Crea el archivo `~/.ollama_chat.sh` con este contenido:

```bash
#!/bin/bash

MODEL=${1:-profesor-amable}   # Modelo por defecto
CONTAINER_NAME=ollama-off
IMAGE_NAME=ollama-offline

# --- DEFINICIÓN DE PROMPTS ---
PROMPT_PROFESOR='FROM llama3.2
SYSTEM "Eres un profesor amable que responde con ejemplos sencillos. Siempre debes explicar como si enseñaras a un estudiante de secundaria."'

PROMPT_RAZONADOR='FROM llama3.1:8b
SYSTEM "Eres un experto en razonamiento lógico. Siempre explica tus respuestas paso a paso, mostrando el razonamiento detrás de cada conclusión. Arranca siempre pidiendo a los universitarios que se callen."'
# -----------------------------

# Comprobar si el contenedor ya está corriendo
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    echo "✅ El servidor Ollama ya está corriendo en el contenedor $CONTAINER_NAME"
else
    echo "🚀 Arrancando servidor Ollama offline..."
    docker run -d --network=none --gpus all -p 11434:11434 --name $CONTAINER_NAME $IMAGE_NAME
    sleep 2
fi

# Crear los Modelfiles directamente dentro del contenedor
echo "$PROMPT_PROFESOR" | docker exec -i $CONTAINER_NAME tee /root/Modelfile_profesor >/dev/null
docker exec -it $CONTAINER_NAME ollama create profesor-amable -f /root/Modelfile_profesor

echo "$PROMPT_RAZONADOR" | docker exec -i $CONTAINER_NAME tee /root/Modelfile_razonador >/dev/null
docker exec -it $CONTAINER_NAME ollama create razonador -f /root/Modelfile_razonador

# Entrar al chat con el modelo elegido
echo "💬 Iniciando chat con el modelo: $MODEL"
docker exec -it $CONTAINER_NAME ollama run $MODEL
```

Dar permisos de ejecución:
```bash
chmod +x ~/.ollama_chat.sh
```

---

## 🔹 Alias para usar el script
Edita tu `~/.bashrc` y añade al final:
```bash
alias ollama='~/.ollama_chat.sh'
```

Recarga la configuración:
```bash
source ~/.bashrc
```

---

## 🔹 Uso
- Chat con el modelo **profesor-amable** (por defecto):
  ```bash
  ollama
  ```

- Chat con el modelo **razonador**:
  ```bash
  ollama razonador
  ```

---

## 🔹 Notas finales
- `--network=none` garantiza que el contenedor funcione **100% offline**.  
- Si no tienes GPU, quita `--gpus all`.  
- Los prompts se gestionan directamente desde el script, lo que hace más fácil actualizar el comportamiento de los modelos.  
