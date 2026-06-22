# Claude Code
.claude/

# Python cache
__pycache__/
*.pyc
*.pyo

# Chat data (user conversations)
Shared/chat_data/

# Downloaded models (large files)
Shared/models/*.gguf
Shared/models/ollama_data/

# Ollama binaries
Shared/bin/ollama-windows.exe
Shared/bin/ollama-linux
Shared/bin/ollama-darwin
Shared/bin/llama-server*
Shared/bin/temp_ollama*
Shared/bin/ollama*

# Portable Python
Shared/python/
Shared/python-embed.zip

# Vendor assets (downloaded on install)
Shared/vendor/

# Ollama runtime
Shared/lib/
Shared/models/.ollama-runtime/
Shared/.ollama-runtime/

# Log files
Shared/logs/

# Temporary files
*.tmp
*.zip
*.tgz


# Ollama engine binaries (large DLLs)
Shared/bin/*.dll
Shared/bin/*.exe
Shared/bin/*.so
Shared/bin/*.dylib

# CUDA libraries
Shared/bin/cublas*
Shared/bin/cudart*
Shared/bin/ggml-cuda*
Shared/bin/ggml-vulkan*
