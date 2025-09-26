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