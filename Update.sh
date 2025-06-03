#!/bin/bash

# Script pour rechercher et appliquer les mises à jour sur Debian/Ubuntu

# S'assurer que le script est exécuté en tant que root
if [ "$(id -u)" -ne 0 ]; then
  echo "Ce script doit être exécuté en tant que root ou avec sudo." >&2
  exit 1
fi

echo "----------------------------------------------------"
echo "Mise à jour de la liste des paquets..."
echo "----------------------------------------------------"
apt update

# Vérifier si la mise à jour de la liste des paquets a réussi
if [ $? -ne 0 ]; then
  echo "Erreur lors de la mise à jour de la liste des paquets. Arrêt du script." >&2
  exit 1
fi

echo ""
echo "----------------------------------------------------"
echo "Mise à niveau des paquets installés..."
echo "----------------------------------------------------"
apt upgrade -y

# Vérifier si la mise à niveau a réussi
if [ $? -ne 0 ]; then
  echo "Erreur lors de la mise à niveau des paquets. Tentative de continuer..." >&2
  # Il est possible que certaines erreurs ne soient pas critiques, donc on continue
fi

echo ""
echo "----------------------------------------------------"
echo "Mise à niveau complète du système (full-upgrade)..."
echo "Ceci peut supprimer des paquets si nécessaire."
echo "----------------------------------------------------"
apt full-upgrade -y

# Vérifier si la mise à niveau complète a réussi
if [ $? -ne 0 ]; then
  echo "Erreur lors de la mise à niveau complète du système. Tentative de continuer..." >&2
fi

echo ""
echo "----------------------------------------------------"
echo "Suppression des paquets inutiles (autoremove)..."
echo "----------------------------------------------------"
apt autoremove -y

# Vérifier si la suppression automatique a réussi
if [ $? -ne 0 ]; then
  echo "Erreur lors de la suppression des paquets inutiles." >&2
  # Pas critique, on continue
fi

echo ""
echo "----------------------------------------------------"
echo "Nettoyage des fichiers de paquets téléchargés (clean)..."
echo "----------------------------------------------------"
apt clean

# Vérifier si le nettoyage a réussi
if [ $? -ne 0 ]; then
  echo "Erreur lors du nettoyage des fichiers de paquets." >&2
fi

echo ""
echo "----------------------------------------------------"
echo "Le processus de mise à jour est terminé."
echo "Il est recommandé de redémarrer si des mises à jour importantes"
echo "(comme un nouveau noyau) ont été installées."
echo "----------------------------------------------------"

exit 0
