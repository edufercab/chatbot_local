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
SYSTEM "Eres un profesor amable que responde con ejemplos sencillos. Siempre debes explicar como si enseñaras a un estudiante de secundaria."' > Modelfile_profesor
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
SYSTEM "Eres un experto en razonamiento lógico. Siempre explica tus respuestas paso a paso, mostrando el razonamiento detrás de cada conclusión."' > Modelfile_razonador
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

3. (Opcional) Exportar a un archivo `.tar`:
   ```bash
   docker save -o ollama-offline.tar ollama-offline
   # Importar en otra máquina:
   # docker load -i ollama-offline.tar
   ```

---

## 🔹 Usar Ollama en modo offline
### Opción A — Modo servidor estable (API o chat)
Levantar el servidor Ollama sin internet:
```bash
docker run -d --network=none --gpus all -p 11434:11434 --name ollama-off ollama-offline
```

Entrar al chat con tu modelo:
```bash
docker exec -it ollama-off ollama run profesor-amable
```

### Opción B — Atajo: chat directo en un solo comando
Con modelo `profesor-amable`:
```bash
docker run -it --network=none --gpus all --rm --entrypoint="" ollama-offline bash -c "ollama serve & sleep 2 && ollama run profesor-amable"
```

Con modelo `razonador`:
```bash
docker run -it --network=none --gpus all --rm --entrypoint="" ollama-offline bash -c "ollama serve & sleep 2 && ollama run razonador"
```

---

## 🔹 Notas finales
- `--network=none` garantiza que el contenedor funcione **100% offline**.  
- Si no tienes GPU, quita `--gpus all`.  
- Los modelos añadidos con `ollama create` quedan embebidos en la imagen `ollama-offline`.  
