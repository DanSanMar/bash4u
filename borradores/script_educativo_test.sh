#!/bin/bash

# 🚀 Función para mostrar el menú principal
mostrar_menu() {
    echo "----------------------------"
    echo "   CUESTIONARIO DE BASH     "
    echo "1. Preguntas sobre condicionales (if-elif-else)"
    echo "2. Preguntas sobre bucles (for)"
    echo "3. Preguntas sobre bucles (while)"
    echo "4. Preguntas sobre bucles (until)"
    echo "5. Preguntas sobre operadores lógicos (&&, ||)"
    echo "6. Salir"
    echo "----------------------------"
}

# 🧠 Función para preguntas sobre condicionales
preguntas_condicionales() {
    echo "Pregunta 1: ¿Qué operador se usa para comparar cadenas en Bash?"
    echo "a) ==      b) !=      c) >       d) <"
    read -p "Tu respuesta: " respuesta

    case $respuesta in
        a|A)
            echo "✅ Correcto! El operador '==' se usa para comparar cadenas."
            ;;
        *)
            echo "❌ Incorrecto. La respuesta correcta es 'a) =='."
            ;;
    esac

    echo "Pregunta 2: ¿Qué hace el operador 'elif' en Bash?"
    echo "a) Compara dos números      b) Ejecuta un bloque si la condición anterior falla"
    echo "c) Sale del script         d) No existe"
    read -p "Tu respuesta: " respuesta

    case $respuesta in
        b|B)
            echo "✅ Correcto! 'elif' se ejecuta si la condición anterior falla."
            ;;
        *)
            echo "❌ Incorrecto. La respuesta correcta es 'b) Ejecuta un bloque si la
condición anterior falla'."
            ;;
    esac
}

# 🔄 Función para preguntas sobre bucles for
preguntas_for() {
    echo "Pregunta 1: ¿Qué hace el bucle 'for i in {1..5}'?"
    echo "a) Itera de 1 a 5      b) Itera de 1 a 5 con paso de 2"
    echo "c) Itera de 5 a 1      d) No existe"
    read -p "Tu respuesta: " respuesta

    case $respuesta in
        a|A)
            echo "✅ Correcto! Itera de 1 a 5."
            ;;
        *)
            echo "❌ Incorrecto. La respuesta correcta es 'a) Itera de 1 a 5'."
            ;;
    esac

    echo "Pregunta 2: ¿Qué estructura se usa para iterar sobre una lista de elementos en
Bash?"
    echo "a) for ... in ...      b) while ... do ..."
    echo "c) until ... do ...    d) if ... then ..."
    read -p "Tu respuesta: " respuesta

    case $respuesta in
        a|A)
            echo "✅ Correcto! 'for ... in ...' se usa para iterar sobre listas."
            ;;
        *)
            echo "❌ Incorrecto. La respuesta correcta es 'a) for ... in ...'."
            ;;
    esac
}

# 🔄 Función para preguntas sobre bucles while
preguntas_while() {
    echo "Pregunta 1: ¿Qué hace el bucle 'while true; do ...; done'?"
    echo "a) Se ejecuta una vez      b) Se ejecuta hasta que se cumpla una condición"
    echo "c) Se ejecuta infinitamente d) No existe"
    read -p "Tu respuesta: " respuesta

    case $respuesta in
        c|C)
            echo "✅ Correcto! 'while true' se ejecuta infinitamente."
            ;;
        *)
            echo "❌ Incorrecto. La respuesta correcta es 'c) Se ejecuta infinitamente'."
            ;;
    esac

    echo "Pregunta 2: ¿Qué se usa para salir de un bucle while en Bash?"
    echo "a) exit      b) break      c) continue      d) return"
    read -p "Tu respuesta: " respuesta

    case $respuesta in
        b|B)
            echo "✅ Correcto! 'break' se usa para salir de un bucle."
            ;;
        *)
            echo "❌ Incorrecto. La respuesta correcta es 'b) break'."
            ;;
    esac
}

# 🔄 Función para preguntas sobre bucles until
preguntas_until() {
    echo "Pregunta 1: ¿Qué hace el bucle 'until [ -f \"archivo.txt\" ]; do ...; done'?"
    echo "a) Se ejecuta hasta que el archivo exista"
    echo "b) Se ejecuta mientras el archivo exista"
    echo "c) No existe en Bash"
    echo "d) Se ejecuta una vez"
    read -p "Tu respuesta: " respuesta

    case $respuesta in
        a|A)
            echo "✅ Correcto! 'until' se ejecuta hasta que la condición sea verdadera."
            ;;
        *)
            echo "❌ Incorrecto. La respuesta correcta es 'a) Se ejecuta hasta que el
archivo exista'."
            ;;
    esac

    echo "Pregunta 2: ¿Qué operador se usa para comparar si un archivo no existe en
'until'?"
    echo "a) -f      b) -e      c) -d      d) -x"
    read -p "Tu respuesta: " respuesta

    case $respuesta in
        a|A)
            echo "✅ Correcto! '-f' comprueba si un archivo existe."
            ;;
        *)
            echo "❌ Incorrecto. La respuesta correcta es 'a) -f'."
            ;;
    esac
}

# 🔄 Función para preguntas sobre operadores lógicos
preguntas_operadores() {
    echo "Pregunta 1: ¿Qué hace el operador '&&' en Bash?"
    echo "a) Ejecuta el segundo comando si el primero falla"
    echo "b) Ejecuta el segundo comando si el primero tiene éxito"
    echo "c) No existe"
    echo "d) Sale del script"
    read -p "Tu respuesta: " respuesta

    case $respuesta in
        b|B)
            echo "✅ Correcto! '&&' ejecuta el segundo comando si el primero es exitoso."
            ;;
        *)
            echo "❌ Incorrecto. La respuesta correcta es 'b) Ejecuta el segundo comando si
el primero tiene éxito'."
            ;;
    esac

    echo "Pregunta 2: ¿Qué hace el operador '||' en Bash?"
    echo "a) Ejecuta el segundo comando si el primero falla"
    echo "b) Ejecuta el segundo comando si el primero tiene éxito"
    echo "c) No existe"
    echo "d) Sale del script"
    read -p "Tu respuesta: " respuesta

    case $respuesta in
        a|A)
            echo "✅ Correcto! '||' ejecuta el segundo comando si el primero falla."
            ;;
        *)
            echo "❌ Incorrecto. La respuesta correcta es 'a) Ejecuta el segundo comando si
el primero falla'."
            ;;
    esac
}

# 🔄 Función principal del script
main() {
    while true; do
        mostrar_menu
        read -p "Elige una opción (1-6): " opcion

        case $opcion in
            1) preguntas_condicionales ;;
            2) preguntas_for ;;
            3) preguntas_while ;;
            4) preguntas_until ;;
            5) preguntas_operadores ;;
            6) echo "¡Hasta pronto!"; break ;;
            *)
                echo "❌ Opción no válida. Por favor, elige un número entre 1 y 6."
                ;;
        esac

        read -p "¿Quieres seguir jugando? (s/n): " seguir
        if [[ "$seguir" != "s" && "$seguir" != "S" ]]; then
            echo "¡Hasta pronto!"
            break
        fi
    done
}

# 🎮 Iniciar el cuestionario
main
