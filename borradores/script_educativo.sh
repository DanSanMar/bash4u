#!/bin/bash

# 🌟 Bienvenida al script
echo "¡Bienvenido al script de ejemplo! Este script muestra:"
echo "1. Condicionales (if, elif, else, case)"
echo "2. Bucles (for, while, until)"
echo "3. Uso de operadores lógicos (&&, ||, test)"
echo "4. Manejo de archivos y entrada del usuario"
echo "5. Funciones y estructura de código"
echo "Presiona Enter para continuar..."
read

# 🔄 Función para mostrar un menú
mostrar_menu() {
    echo "----------------------------"
    echo "   MENÚ PRINCIPAL         "
    echo "1. Ejemplo con condicionales (if-elif-else)"
    echo "2. Ejemplo con bucles (for)"
    echo "3. Ejemplo con bucles (while)"
    echo "4. Ejemplo con bucles (until)"
    echo "5. Salir"
    echo "----------------------------"
}

# 🧪 Ejemplo 1: Condicionales (if-elif-else)
ejemplo_condicionales() {
    echo "Ejemplo 1: Condicionales"
    echo "Ingresa un número (1-3) o 'salir' para terminar:"
    read opcion

    if [[ "$opcion" == "1" ]]; then
        echo "¡Elegiste la opción 1! ¡Bien hecho!"
    elif [[ "$opcion" == "2" ]]; then
        echo "¡Elegiste la opción 2! ¡Felicidades!"
    elif [[ "$opcion" == "3" ]]; then
        echo "¡Elegiste la opción 3! ¡Muy bien!"
    elif [[ "$opcion" == "salir" ]]; then
        echo "Saliendo del ejemplo..."
        return
    else
        echo "Opción no válida. Por favor, intenta de nuevo."
    fi
}

# 🔄 Ejemplo 2: Bucles (for) con listas y rangos
ejemplo_for() {
    echo "Ejemplo 2: Bucles (for)"
    echo "Iterando sobre una lista de frutas:"
    for fruta in manzana naranja plátano; do
        echo "- $fruta"
    done

    echo "Iterando sobre un rango de números (1 a 5):"
    for i in {1..5}; do
        echo "- Número $i"
    done
}

# 🔄 Ejemplo 3: Bucles (while) para esperar entrada del usuario
ejemplo_while() {
    echo "Ejemplo 3: Bucles (while)"
    echo "Ingresa 'fin' para terminar:"
    while true; do
        read -p "Ingresa algo: " entrada
        if [[ "$entrada" == "fin" ]]; then
            echo "¡Terminaste el bucle!"
            break
        else
            echo "Repetiendo... (ingresa 'fin' para terminar)"
        fi
    done
}

# 🔄 Ejemplo 4: Bucles (until) para esperar un archivo
ejemplo_until() {
    echo "Ejemplo 4: Bucles (until)"
    echo "Creando un archivo temporal (temp.txt) en 3 segundos..."
    sleep 3
    touch temp.txt

    until [ -f "temp.txt" ]; do
        echo "Esperando a que se cree 'temp.txt'..."
        sleep 1
    done

    echo "¡Archivo encontrado! Eliminando 'temp.txt'..."
    rm temp.txt
}

# 🔄 Ejemplo 5: Uso de operadores lógicos (&&, ||)
ejemplo_operadores() {
    echo "Ejemplo 5: Operadores lógicos"
    echo "Verificando si un archivo existe (ejemplo.txt):"
    if [ -f "ejemplo.txt" ]; then
        echo "¡El archivo existe! Procesando..."
        cat ejemplo.txt
    else
        echo "El archivo no existe. Creando 'ejemplo.txt'..."
        echo "Este es un ejemplo de contenido" > ejemplo.txt
    fi

    echo "Usando operadores lógicos (&&):"
    ls -l /home && echo "Directorio existente" || echo "Directorio no encontrado"
}

# 🔄 Función principal del script
main() {
    while true; do
        mostrar_menu
        read -p "Elige una opción (1-5): " opcion

        case "$opcion" in
            1) ejemplo_condicionales ;;
            2) ejemplo_for ;;
            3) ejemplo_while ;;
            4) ejemplo_until ;;
            5) echo "¡Hasta luego!"; break ;;
            *) echo "Opción no válida. Intenta de nuevo." ;;
        esac

        echo "Presiona Enter para continuar..."
        read
    done
}
# 🚀 Iniciar el script
main
