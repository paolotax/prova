#!/bin/bash

# Crea la directory per le icone se non esiste
mkdir -p app/assets/images/icons/ios

# Estrai il contenuto SVG dal file erb e salvalo come file SVG puro
awk '/^<svg/,/<\/svg>/' app/views/voice_notes/index.html.erb > app/assets/images/logo.svg

# Funzione per generare un'icona
generate_icon() {
    size=$1
    output_name=$2
    
    echo "Generando icona $output_name ($size x $size)..."
    magick app/assets/images/logo.svg \
        -background none \
        -density 1200 \
        -resize ${size}x${size} \
        "app/assets/images/icons/ios/$output_name.png"
}

# iPhone Notifications
generate_icon 40 "icon-20@2x"  # 20pt @2x
generate_icon 60 "icon-20@3x"  # 20pt @3x

# iPhone Settings
generate_icon 58 "icon-29@2x"  # 29pt @2x
generate_icon 87 "icon-29@3x"  # 29pt @3x

# iPhone Spotlight
generate_icon 80 "icon-40@2x"  # 40pt @2x
generate_icon 120 "icon-40@3x" # 40pt @3x

# iPhone App
generate_icon 120 "icon-60@2x" # 60pt @2x
generate_icon 180 "icon-60@3x" # 60pt @3x

# iPad
generate_icon 76 "icon-76"     # 76pt @1x
generate_icon 152 "icon-76@2x" # 76pt @2x
generate_icon 167 "icon-83.5@2x" # 83.5pt @2x

# App Store
generate_icon 1024 "icon-1024" # App Store

echo "Generazione icone completata!"