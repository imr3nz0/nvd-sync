#!/bin/bash

# ------------------------------------------------------------------------------
# nvd-sync.sh
# Autor: Renzo Franco (@imr3nz0)
# Licença: MIT
# ------------------------------------------------------------------------------

set -euo pipefail

# -----------------------------------------
# 📣 Função para log
# -----------------------------------------
log() {
    echo -e "\033[1;34m[INFO]\033[0m $*"
}

error() {
    echo -e "\033[1;31m[ERRO]\033[0m $*"
    exit 1
}

# -----------------------------------------
# 🔐 Variáveis de configuração (edite conforme necessário)
# -----------------------------------------

NVD_API_KEY="[API_KEY]"
S3_BUCKET="[NOME_DO_BUCKET]"
S3_PREFIX="[DIR_BUCKET]"
WORK_DIR="./dependency-check"
DATA_DIR="./dependency-check-data"
GZ_FILE="dependency-check-data.tar.gz"

# -----------------------------------------
# ✅ Pré-requisitos
# -----------------------------------------

command -v curl >/dev/null 2>&1 || error "curl não está instalado."
command -v unzip >/dev/null 2>&1 || error "unzip não está instalado."
command -v aws >/dev/null 2>&1 || error "AWS CLI não está instalado."

# -----------------------------------------
# 🔍 Buscar versão mais recente
# -----------------------------------------

log "Buscando última versão do Dependency-Check..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/jeremylong/DependencyCheck/releases/latest | grep '"tag_name":' | cut -d '"' -f 4)

if [[ -z "$LATEST_VERSION" ]]; then
    error "Não foi possível obter a versão mais recente da ferramenta."
fi

log "Última versão identificada: $LATEST_VERSION"

ZIP_NAME="dependency-check-${LATEST_VERSION:1}-release.zip"
DOWNLOAD_URL="https://github.com/jeremylong/DependencyCheck/releases/download/${LATEST_VERSION}/${ZIP_NAME}"

# -----------------------------------------
# 📦 Baixar e preparar ferramenta
# -----------------------------------------

log "Baixando arquivo: $ZIP_NAME"
curl -L -o "$ZIP_NAME" "$DOWNLOAD_URL"

log "Extraindo conteúdo..."
rm -rf "$WORK_DIR"
unzip -oq "$ZIP_NAME" -d "$WORK_DIR"
rm -f "$ZIP_NAME"

DC_BIN="$WORK_DIR/dependency-check/bin/dependency-check.sh"
chmod +x "$DC_BIN"

# -----------------------------------------
# 🧠 Gerar banco de dados local
# -----------------------------------------

log "Gerando banco de dados com API Key..."
"$DC_BIN" --updateonly --data "$DATA_DIR" --nvdApiKey "${NVD_API_KEY}"

# -----------------------------------------
# 📦 Compactar base de dados
# -----------------------------------------

log "Compactando dados em $GZ_FILE..."
tar -czf "$GZ_FILE" "$DATA_DIR"

# -----------------------------------------
# ☁️ Enviar para S3
# -----------------------------------------

ARQUIVO_S3="${S3_PREFIX}/${GZ_FILE}"

log "Enviando arquivo para: s3://${S3_BUCKET}/${ARQUIVO_S3}"
aws s3 cp "$GZ_FILE" "s3://${S3_BUCKET}/${ARQUIVO_S3}" --only-show-errors

log "✅ Banco de dados enviado com sucesso!"
log "📍 Local: s3://${S3_BUCKET}/${ARQUIVO_S3}"
