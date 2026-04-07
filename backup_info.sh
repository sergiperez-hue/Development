#!/bin/bash

FECHA=$(date +%Y-%m-%d)
ARCHIVOS=$(ls $HOME | wc -l)

echo "Hoy es $FECHA y tienes $ARCHIVOS archivos en tu HOME"
