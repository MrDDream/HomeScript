# Fichier /etc/skel/.zshrc pour une configuration Oh My Zsh centralisée

# Exporter le chemin d'installation de Oh My Zsh
# Ne pas changer cette ligne si vous avez suivi les étapes ci-dessus.
export ZSH="/opt/oh-my-zsh"

# --- CHOIX DU THÈME ---
# Choisissez votre thème ici.
# Pour voir la liste des thèmes : https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# "robbyrussell" est le thème par défaut, simple et efficace.
# "agnoster" est un autre thème très populaire (nécessite des polices spéciales).
ZSH_THEME="agnoster"

# --- EXEMPLES DE CONFIGURATION ---
# Décommenter pour activer les plugins (doivent être dans $ZSH/plugins/*)
plugins=(history docker zsh-syntax-highlighting zsh-autosuggestions)

# Décommenter pour activer la correction orthographique des commandes
# ENABLE_CORRECTION="true"

# Décommenter pour avoir des couleurs dans la commande 'ls'
# eval "$(dircolors)"
# zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Charger Oh My Zsh à la fin de la configuration
source "$ZSH/oh-my-zsh.sh"

# Vous pouvez ajouter vos propres alias et exports ici, après le chargement de Oh My Zsh
# export EDITOR='nano'
# alias ll='ls -alF'