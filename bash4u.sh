#!/bin/bash
# bash4u.sh — curso interactivo de Bash scripting de cero a experto.
#
# Fase 1: motor (pantallas, estado, etapas, validación, XP) + niveles piloto 0, 1, 2 y 4.
# Todo el curso vive en este archivo; ver README.md para el uso.
#
# Convenciones internas:
#   - Textos y mensajes en español.
#   - Sin dependencias externas (solo bash 4.3+ y coreutils).
#   - Cada nivel declara demo_0N y RETOS_0N; cada reto define R_* con definir_reto.
#   - El estado se guarda en ${XDG_DATA_HOME:-$HOME/.local/share}/bash4u/estado.

set -uo pipefail

VERSION="0.3.3"
DIR_DATOS="${XDG_DATA_HOME:-$HOME/.local/share}/bash4u"
ARCH_ESTADO="$DIR_DATOS/estado"
DIR_PRACTICAS="${BASH4U_PRACTICAS:-$HOME/bash4u-practicas}"

# ---------------------------------------------------------------- opciones ---
MODO_PLANO=0
MODO_RAPIDO=0
AUTOTEST=0
CAPS_OVERRIDE=""
CAPS_OVERRIDE_ACTIVO=0
FORZAR=0        # con --si no se pide confirmación (útil en scripts)

# ------------------------------------------------------------------ colores ---
C_RESET=""
C_TITULO=""
C_OK=""
C_ERR=""
C_AVISO=""
C_GRIS=""
C_PROMPT=""
C_XP=""

# ------------------------------------------------------------------- estado ---
EST_VERSION=1
EST_COMPLETADAS=""
EST_LECCION=""
EST_XP=0
EST_DESBLOQUEOS=""
EST_RETOS=""
EST_PENDIENTES=""
EST_PISTAS=0
EST_EXAMEN=0

# -------------------------------------------------------------------- retos ---
R_ID=""
R_ENUNCIADO=""
R_PISTA=""
R_SOLUCION=""
R_MALA=""
R_FIXTURE=""
R_TIMEOUT=5
R_CASOS=()
R_ARCHIVO=""
R_CHEQUEO=""
R_LOGRO=""
DETALLE_FALLO=""
STTY_ORIG=""

# Posición del reto dentro del nivel (para mostrar «2 de 3»).
RETO_INDICE=0
RETO_CUANTOS=0

# =============================================================== utilidades ===

error() { printf '%s\n' "bash4u: $*" >&2; }

lista_contiene() {
    [[ ",${1:-}," == *",${2},"* ]]
}

# Divide una lista "a,b,c" en el array global LISTA.
# Se hace con expansiones de parámetros y no con `read -a <<< ...`: el
# here-string depende de un fichero temporal y, si ese fichero falla, el
# array sale vacío en silencio (y con él se pierde el progreso).
dividir_lista() {
    LISTA=()
    local lista=${1:-} elemento
    [[ -z $lista ]] && return 0
    while [[ $lista == *,* ]]; do
        elemento=${lista%%,*}
        LISTA+=("$elemento")
        lista=${lista#*,}
    done
    LISTA+=("$lista")
}

agregar_lista() {
    local lista=${1:-} item=$2
    if [[ -z $lista ]]; then
        printf '%s' "$item"
    elif lista_contiene "$lista" "$item"; then
        printf '%s' "$lista"
    else
        printf '%s,%s' "$lista" "$item"
    fi
}

quitar_lista() {
    local lista=${1:-} item=$2 salida="" x
    [[ -z $lista ]] && return 0
    dividir_lista "$lista"
    for x in "${LISTA[@]}"; do
        [[ $x == "$item" ]] && continue
        salida=${salida:+$salida,}$x
    done
    printf '%s' "$salida"
}

contar_lista() {
    local lista=${1:-}
    [[ -z $lista ]] && { printf '0'; return 0; }
    dividir_lista "$lista"
    printf '%s' "${#LISTA[@]}"
}

# ==================================================================== estado ===

rango_actual() {
    if (( EST_XP >= 700 )); then
        printf 'Experto'
    elif (( EST_XP >= 450 )); then
        printf 'Ingeniero de shell'
    elif (( EST_XP >= 250 )); then
        printf 'Automatizador'
    elif (( EST_XP >= 100 )); then
        printf 'Scriptor'
    else
        printf 'Aprendiz'
    fi
}

estado_defecto() {
    EST_VERSION=1
    EST_COMPLETADAS=""
    EST_LECCION=""
    EST_XP=0
    EST_DESBLOQUEOS=""
    EST_RETOS=""
    EST_PENDIENTES=""
    EST_PISTAS=0
    EST_EXAMEN=0
}

cargar_estado() {
    estado_defecto
    [[ -f $ARCH_ESTADO ]] || return 0

    local clave valor
    while IFS='=' read -r clave valor; do
        case $clave in
            version)        [[ $valor =~ ^[0-9]+$ ]] && EST_VERSION=$valor ;;
            completadas)    EST_COMPLETADAS=$valor ;;
            leccion)        EST_LECCION=$valor ;;
            xp)             [[ $valor =~ ^[0-9]+$ ]] && EST_XP=$valor ;;
            desbloqueos)    EST_DESBLOQUEOS=$valor ;;
            retos)          EST_RETOS=$valor ;;
            pendientes)     EST_PENDIENTES=$valor ;;
            pistas)         [[ $valor =~ ^[0-9]+$ ]] && EST_PISTAS=$valor ;;
            examen)         [[ $valor =~ ^[0-9]+$ ]] && EST_EXAMEN=$valor ;;
        esac
    done < "$ARCH_ESTADO"
}

guardar_estado() {
    mkdir -p "$DIR_DATOS" || return 1
    local temporal="$ARCH_ESTADO.tmp.$$"
    {
        printf 'version=%s\n' "$EST_VERSION"
        printf 'completadas=%s\n' "$EST_COMPLETADAS"
        printf 'leccion=%s\n' "$EST_LECCION"
        printf 'xp=%s\n' "$EST_XP"
        printf 'desbloqueos=%s\n' "$EST_DESBLOQUEOS"
        printf 'retos=%s\n' "$EST_RETOS"
        printf 'pendientes=%s\n' "$EST_PENDIENTES"
        printf 'pistas=%s\n' "$EST_PISTAS"
        printf 'examen=%s\n' "$EST_EXAMEN"
    } > "$temporal" && mv "$temporal" "$ARCH_ESTADO"
}

sumar_xp() {
    EST_XP=$((EST_XP + $1))
    guardar_estado
}

# =============================================================== etapas / UI ===

caps_etapa() {
    case $1 in
        0) printf '' ;;
        1) printf 'colores' ;;
        2) printf 'colores,menu' ;;
        3) printf 'colores,menu,editor' ;;
        4) printf 'colores,menu,editor,fzf' ;;
        5) printf 'colores,menu,editor,fzf,stats' ;;
        *) return 1 ;;
    esac
}

tiene_cap() {
    local lista=$EST_DESBLOQUEOS
    (( CAPS_OVERRIDE_ACTIVO )) && lista=$CAPS_OVERRIDE
    lista_contiene "$lista" "$1"
}

desbloquear() {
    local cap=$1
    lista_contiene "$EST_DESBLOQUEOS" "$cap" && return 1
    EST_DESBLOQUEOS=$(agregar_lista "$EST_DESBLOQUEOS" "$cap")
    guardar_estado
    return 0
}

configurar_colores() {
    if [[ $MODO_PLANO -eq 0 && -t 1 ]] && tiene_cap colores; then
        C_RESET=$'\e[0m'
        C_TITULO=$'\e[1;36m'
        C_OK=$'\e[1;32m'
        C_ERR=$'\e[1;31m'
        C_AVISO=$'\e[1;33m'
        C_GRIS=$'\e[2m'
        C_PROMPT=$'\e[1;34m'
        C_XP=$'\e[1;35m'
    else
        C_RESET=""; C_TITULO=""; C_OK=""; C_ERR=""
        C_AVISO=""; C_GRIS=""; C_PROMPT=""; C_XP=""
    fi
}

cabecera_ui() {
    printf '%s\n' "${C_XP}XP ${EST_XP} · $(rango_actual)${C_RESET}   ${C_GRIS}bash4u ${VERSION}${C_RESET}"
}

hay_color() {
    [[ -n $C_RESET ]]
}

pantalla() {
    local titulo=$1 cuerpo=${2:-} pie=${3:-}

    if [[ $MODO_PLANO -eq 1 || ! -t 1 ]]; then
        printf '\n== %s ==\n' "$titulo"
        [[ -n $cuerpo ]] && printf '%s\n' "$cuerpo"
        [[ -n $pie ]] && printf '%s\n' "$pie"
        return 0
    fi

    command -v clear >/dev/null 2>&1 && clear
    cabecera_ui
    printf '%s\n\n' "${C_TITULO}${titulo}${C_RESET}"
    [[ -n $cuerpo ]] && printf '%s\n' "$cuerpo"
    if [[ -n $pie ]]; then
        printf '%s\n' "────────────────────────────────────────"
        printf '%s\n' "${C_GRIS}${pie}${C_RESET}"
    fi
    return 0
}

pausa() {
    [[ $AUTOTEST -eq 1 ]] && return 0
    # Sin teclado (por ejemplo, entrada por tubería) no tiene sentido pedir Enter.
    [[ -t 0 ]] || return 0
    printf '%s' "${C_GRIS}(Enter para continuar)${C_RESET} "
    IFS= read -r -e _ || return 1
    return 0
}

# Comandos disponibles en las pausas de una lección:
#   Enter     avanzar
#   :atras    volver a la pantalla o parte anterior
#   :inicio   empezar la lección desde el principio
#   :salir    volver al menú sin cerrar el programa
# Devuelve 0, 2, 3 o 4; 1 si se cierra la entrada.
leer_comando_nav() {
    local linea
    if ! IFS= read -r -e linea; then
        return 1
    fi
    case $linea in
        "") return 0 ;;
        :atras|:atrás) return 2 ;;
        :inicio|:reiniciar) return 3 ;;
        :salir) return 4 ;;
        *)
            printf '%s\n' "${C_GRIS}  Usa Enter, :atras, :inicio o :salir.${C_RESET}"
            return 5
            ;;
    esac
}

pausa_nav() {
    [[ $AUTOTEST -eq 1 ]] && return 0
    [[ -t 0 ]] || return 0

    local rc
    while true; do
        printf '%s' "${C_GRIS}(Enter) :atras :inicio :salir${C_RESET} "
        leer_comando_nav
        rc=$?
        (( rc == 5 )) && continue
        return $rc
    done
}

# Pinta un texto con una animación muy leve (se desactiva en tests y en modo plano).
escribir() {
    local texto=$1 i
    if [[ $MODO_RAPIDO -eq 1 || $AUTOTEST -eq 1 || $MODO_PLANO -eq 1 || ! -t 1 ]]; then
        printf '%s\n' "$texto"
        return 0
    fi
    for (( i = 0; i < ${#texto}; i++ )); do
        printf '%s' "${texto:i:1}"
        sleep 0.004
    done
    printf '\n'
}

paginar() {
    local texto=$1
    while [[ $texto == *$'\n' ]]; do texto=${texto%$'\n'}; done

    local -a lineas=()
    local resto=$texto
    # Se parte por saltos de línea con expansiones de parámetros (sin
    # here-strings: si el fichero temporal falla, el texto se perdería).
    while [[ $resto == *$'\n'* ]]; do
        lineas+=("${resto%%$'\n'*}")
        resto=${resto#*$'\n'}
    done
    lineas+=("$resto")
    local total=${#lineas[@]} i=0 por_pagina=18 fin inicio rc

    if [[ $MODO_PLANO -eq 0 && -t 1 ]] && command -v tput >/dev/null 2>&1; then
        por_pagina=$(($(tput lines 2>/dev/null || printf '24') - 9))
    fi
    (( por_pagina < 6 )) && por_pagina=6

    while (( i < total )); do
        inicio=$i
        fin=$((i + por_pagina))
        (( fin > total )) && fin=$total
        printf '%s\n' "${lineas[@]:i:fin-i}"
        i=$fin
        if (( i < total )); then
            [[ $AUTOTEST -eq 1 ]] && continue
            [[ -t 0 ]] || continue
            while true; do
                printf '%s' "${C_GRIS}-- Más -- (Enter) :atras :inicio :salir${C_RESET} "
                leer_comando_nav
                rc=$?
                case $rc in
                    0) break ;;
                    2)
                        if (( inicio > 0 )); then
                            i=$((inicio - por_pagina))
                            (( i < 0 )) && i=0
                        else
                            return 2
                        fi
                        break
                        ;;
                    1|3|4) return $rc ;;
                    5) continue ;;
                esac
            done
        fi
    done
    return 0
}

configurar_terminal() {
    [[ -t 0 ]] || return 0
    STTY_ORIG=$(stty -g 2>/dev/null) || { STTY_ORIG=""; return 0; }
    trap 'restaurar_terminal' EXIT
    trap 'restaurar_terminal; exit 130' INT TERM
}

restaurar_terminal() {
    [[ -n $STTY_ORIG ]] && stty "$STTY_ORIG" 2>/dev/null
    return 0
}

# ================================================================ validación ===

normalizar() {
    printf '%s' "$1" | sed -e 's/\r$//' -e 's/[[:space:]]*$//'
}

# Ejecuta el código del alumno contra todos los casos del reto actual.
# Usa R_CASOS, R_FIXTURE, R_TIMEOUT y deja el motivo en DETALLE_FALLO.
ejecutar_codigo() {
    local codigo=$1
    DETALLE_FALLO=""

    if (( ${#R_CASOS[@]} == 0 )); then
        DETALLE_FALLO="el reto no define casos de prueba"
        return 1
    fi

    local sandbox programa="reto.sh"
    sandbox=$(mktemp -d) || { DETALLE_FALLO="no se pudo crear el sandbox"; return 1; }
    [[ -n $R_ARCHIVO ]] && programa=$R_ARCHIVO
    printf '%s\n' "$codigo" > "$sandbox/$programa"

    if [[ -n $R_FIXTURE ]]; then
        ( cd "$sandbox" && bash -c "$R_FIXTURE" ) >/dev/null 2>&1
    fi

    local caso entrada esperado salida exit_esperado exit_real resto
    local archivo_salida="$sandbox/salida.txt"
    for caso in "${R_CASOS[@]}"; do
        # Formato: entrada|salida esperada|exit. La entrada y la salida pueden
        # ser multilínea; el separador es el primer y el último «|».
        entrada=${caso%%|*}
        resto=${caso#*|}
        exit_esperado=${resto##*|}
        esperado=${resto%|*}
        [[ -z $exit_esperado ]] && exit_esperado=0

        # La salida va a un archivo y se recorta: un bucle infinito no debe
        # poder llenar la memoria ni la pantalla.
        : > "$archivo_salida"
        ( cd "$sandbox" && printf '%s\n' "$entrada" \
            | timeout -k 1 "$R_TIMEOUT" bash "$programa" >"$archivo_salida" 2>/dev/null )
        exit_real=$?
        salida=$(head -c 100000 "$archivo_salida" 2>/dev/null)

        if [[ "$(normalizar "$salida")" != "$(normalizar "$esperado")" ]] \
            || (( exit_real != exit_esperado )); then
            local mostrado=${esperado:-"(sin salida)"}
            local obtenido=${salida:-"(sin salida)"}
            local cabecera=""
            if [[ -n $entrada ]]; then
                cabecera="Entrada de prueba:
[${entrada}]

"
            fi
            DETALLE_FALLO="${cabecera}Esperaba:
${mostrado}
(código de salida ${exit_esperado})

Obtuve:
${obtenido}
(código de salida ${exit_real})"
            if (( exit_real == 124 )); then
                DETALLE_FALLO+=$'\n'"Tu script no terminó en ${R_TIMEOUT} s (¿un bucle sin salida?)."
            fi
            rm -rf "$sandbox"
            return 1
        fi
    done

    # Comprobación opcional del resultado (archivos creados, permisos, etc.).
    if [[ -n $R_CHEQUEO ]]; then
        if ! ( cd "$sandbox" && bash -c "$R_CHEQUEO" ) >/dev/null 2>&1; then
            DETALLE_FALLO="la salida es correcta, pero falta el archivo o el efecto esperado"
            rm -rf "$sandbox"
            return 1
        fi
    fi

    rm -rf "$sandbox"
    return 0
}

# ==================================================================== retos ===

definir_reto() {
    R_ID=$1
    R_ENUNCIADO=$2
    R_PISTA=$3
    R_SOLUCION=$4
    R_MALA=$5
    R_FIXTURE=${6:-}
    R_TIMEOUT=${7:-5}
    R_ARCHIVO=""
    R_CHEQUEO=""
    R_LOGRO=""
    R_NOTA="CÓMO SE EJECUTA
El curso ejecuta tu código con bash; no necesitas shebang ni chmod.
La entrada de prueba la pone el curso: tú escribes solo el código."
    shift 7
    R_CASOS=("$@")
}

bucle_reto() {
    local xp=${1:-10}
    local intentos=0 max=3
    local -a lineas=()
    local linea codigo limpia titulo guardado cuerpo

    titulo="Reto ${R_ID}"
    (( RETO_CUANTOS > 0 )) && titulo+=" · ${RETO_INDICE} de ${RETO_CUANTOS}"

    while (( intentos < max )); do
        lineas=()
        pantalla "$titulo" "${R_ENUNCIADO}

${R_NOTA}

Escribe tu solución, una línea por vez.
Cuando termines, escribe una línea con solo:   #fin/# fin 
Si te atascas: :pista   ·   Ver tu código: :ver   ·   Empezar de nuevo: :borrar"

        while true; do
            printf '%s' "${C_PROMPT}> ${C_RESET}"
            if ! IFS= read -r -e linea; then
                printf '\n'
                printf '%s\n' "Entrada cerrada; reto cancelado."
                return 1
            fi

            limpia=$linea
            limpia=${limpia#"${limpia%%[![:space:]]*}"}
            limpia=${limpia%"${limpia##*[![:space:]]}"}

            case $limpia in
                "# fin"|"#fin") break ;;
                ":ver")
                    if (( ${#lineas[@]} )); then
                        printf '%s\n' "${lineas[@]}"
                    else
                        printf '%s\n' "(vacío)"
                    fi
                    continue ;;
                ":borrar")
                    lineas=()
                    printf '%s\n' "(borrado)"
                    continue ;;
                ":pista")
                    printf '%s\n' "Pista: $R_PISTA"
                    EST_PISTAS=$((EST_PISTAS + 1))
                    guardar_estado
                    continue ;;
                ":cancelar")
                    printf '%s\n' "Reto cancelado."
                    return 1 ;;
            esac

            lineas+=("$linea")
        done

        if (( ${#lineas[@]} == 0 )); then
            printf '%s\n' "No escribiste nada. Vuelve a intentarlo."
            pausa || true
            continue
        fi

        codigo=$(printf '%s\n' "${lineas[@]}")
        if [[ -n $R_ARCHIVO ]]; then
            while [[ $codigo == $'\n'* ]]; do
                codigo=${codigo#$'\n'}
            done
        fi

        if ejecutar_codigo "$codigo"; then
            local nuevo=0
            if ! lista_contiene "$EST_RETOS" "$R_ID"; then
                nuevo=1
            fi

            guardado=""
            if [[ -n $R_ARCHIVO ]]; then
                if mkdir -p "$DIR_PRACTICAS" 2>/dev/null \
                    && printf '%s\n' "$codigo" > "$DIR_PRACTICAS/$R_ARCHIVO"; then
                    guardado="Guardado en ${DIR_PRACTICAS}/${R_ARCHIVO}"
                fi
            fi
            EST_RETOS=$(agregar_lista "$EST_RETOS" "$R_ID")
            EST_PENDIENTES=$(quitar_lista "$EST_PENDIENTES" "$R_ID")

            if (( nuevo )); then
                sumar_xp "$xp"
                cuerpo="✔ Correcto. +${xp} XP"
            else
                cuerpo="✔ Correcto. Ya lo tenías superado; no suma XP de nuevo."
            fi

            [[ -n $R_LOGRO ]] && cuerpo+=$'\n'$'\n'"${R_LOGRO}"
            [[ -n $guardado ]] && cuerpo+=$'\n'$'\n'"${guardado}"
            pantalla "Reto ${R_ID} superado" "$cuerpo" "Enter para continuar"
            pausa || true
            return 0
        fi

        intentos=$((intentos + 1))
        if (( intentos < max )); then
            pantalla "Reto ${R_ID} · todavía no" "${DETALLE_FALLO}" \
                "Intento ${intentos} de ${max} · Enter para reintentar"
            pausa || true
        else
            pantalla "Reto ${R_ID} · sin intentos" "${DETALLE_FALLO}

Solución de referencia:

${R_SOLUCION}" "Enter para continuar"
            pausa || true
        fi
    done

    EST_PENDIENTES=$(agregar_lista "$EST_PENDIENTES" "$R_ID")
    guardar_estado
    return 1
}

funcion_reto_por_id() {
    local id=$1
    printf 'reto_%02d_%s' "${id%%.*}" "${id#*.}"
}

pantalla_desbloqueo() {
    local nombre=$1 texto=$2 codigo=$3
    pantalla "¡NUEVA HABILIDAD: ${nombre}!" "${texto}

El código que lo hace posible:

${C_GRIS}${codigo}${C_RESET}" "Enter para continuar"
    pausa
}

# ================================================================ lecciones ===

TITULOS=(
    [0]="La terminal y tu primer script"
    [1]="Variables y comillas"
    [2]="Entrada, salida y códigos de estado"
    [3]="Decisiones: tests y condicionales"
    [4]="Bucles y menús"
    [5]="Funciones"
    [6]="Argumentos y opciones"
    [7]="Pipelines y texto"
    [8]="Arrays"
    [9]="Archivos y limpieza"
    [10]="Robustez"
    [11]="Procesos"
    [12]="Proyecto final"
)

LECCIONES=(
    "0|La terminal y tu primer script|leccion_00"
    "1|Variables y comillas|leccion_01"
    "2|Entrada, salida y códigos de estado|leccion_02"
    "4|Bucles y menús|leccion_04"
)

funcion_leccion() {
    printf 'leccion_%02d' "$1"
}

ejecutar_leccion() {
    local num=$1 fn
    if [[ ! $num =~ ^([0-9]|1[0-2])$ ]]; then
        error "Nivel inválido: $num"
        return 2
    fi

    fn=$(funcion_leccion "$num")
    if ! declare -F "$fn" >/dev/null 2>&1; then
        pantalla "Nivel ${num} · ${TITULOS[$num]}" "En construcción.

Este nivel todavía no está disponible en la versión ${VERSION}." "Enter para volver"
        pausa
        return 1
    fi

    "$fn"
}

# Recorre una lista de funciones de paso. Cada paso pinta su pantalla y
# devuelve 0; la pausa posterior permite avanzar, volver, reiniciar o salir.
# Si paginar devuelve 2 (atrás en la primera página), se vuelve al paso anterior.
recorrer_pasos() {
    local -n pasos=$1
    local i=0 total=${#pasos[@]} rc

    while (( i < total )); do
        "${pasos[i]}"
        rc=$?
        if (( rc == 0 )); then
            pausa_nav
            rc=$?
        fi
        case $rc in
            0) i=$((i + 1)) ;;
            2) (( i > 0 )) && i=$((i - 1)) ;;
            3) i=0 ;;
            4) return 4 ;;
            *) return 1 ;;
        esac
    done
    return 0
}

siguiente_leccion() {
    local n fn
    for (( n = 0; n <= 12; n++ )); do
        fn=$(funcion_leccion "$n")
        declare -F "$fn" >/dev/null 2>&1 || continue
        lista_contiene "$EST_COMPLETADAS" "$n" && continue
        printf '%s' "$n"
        return 0
    done
    return 0
}

ejecutar_retos_de() {
    local num=$1 nombre todos=1
    nombre=$(printf 'RETOS_%02d' "$num")

    if ! declare -p "$nombre" >/dev/null 2>&1; then
        return 1
    fi

    local -n retos="$nombre"
    local r
    RETO_CUANTOS=${#retos[@]}
    RETO_INDICE=0
    for r in "${retos[@]}"; do
        RETO_INDICE=$((RETO_INDICE + 1))
        "$r"
        bucle_reto || todos=0
    done
    unset -n retos
    (( todos ))
}

finalizar_leccion() {
    local num=$1 nuevo=0

    if ! lista_contiene "$EST_COMPLETADAS" "$num"; then
        EST_COMPLETADAS=$(agregar_lista "$EST_COMPLETADAS" "$num")
        nuevo=1
        sumar_xp 20
    fi
    EST_LECCION=$num
    guardar_estado

    case $num in
        2)
            if desbloquear colores; then
                configurar_colores
                pantalla_desbloqueo "COLORES" \
                    "Has aprendido a formatear la salida con printf.
Desde ahora el curso usa color para señalar estados." \
                    'printf "\e[1;32m✔ Correcto\e[0m\n"'
            fi ;;
        4)
            if desbloquear menu; then
                pantalla_desbloqueo "MENÚS" \
                    "Has aprendido case y bucles.
Desde ahora el curso se navega con un menú, igual que el que acabas de escribir." \
                    'while true; do
  mostrar_menu
  read -r opcion
  case $opcion in
    1) accion_uno ;;
    2) accion_dos ;;
    q) break ;;
  esac
done'
            fi ;;
        8)
            if desbloquear stats; then
                pantalla_desbloqueo "ESTADÍSTICAS" \
                    "Con arrays ya puedes guardar tu progreso.
Desde ahora el menú muestra tu mapa de niveles." \
                    'progreso+=("nivel $n")
printf "%s\n" "${progreso[@]}"'
            fi ;;
    esac

    if (( nuevo )); then
        pantalla "Nivel ${num} superado" "+20 XP · ${EST_XP} XP totales · rango: $(rango_actual)" "Enter para continuar"
        pausa
    fi
    return 0
}

# ------------------------------------------------------------ nivel 0 --------

demo_00_comillas() {
    printf '%s\n' "→ Comillas dobles: agrupan el texto y conservan los espacios."
    printf '%s\n' '  echo "Hola,   mundo"'
    echo "Hola,   mundo"

    printf '%s\n' "→ Comillas simples: también conservan los espacios."
    printf '%s\n' "  echo 'Hola,   mundo'"
    echo 'Hola,   mundo'

    printf '%s\n' "→ Sin comillas: bash separa por espacios y solo queda uno."
    printf '%s\n' "  echo Hola,   mundo"
    echo Hola,   mundo

    printf '%s\n' "→ Las dobles expanden \$HOME; las simples lo dejan literal."
    printf '%s\n' '  echo "Vivo en $HOME"'
    echo "Vivo en $HOME"
    printf '%s\n' "  echo 'Vivo en \$HOME'"
    echo 'Vivo en $HOME'

    printf '%s\n' '→ La barra invertida permite imprimir una comilla doble:'
    printf '%s\n' '  echo "Él dijo \"hola\""'
    echo "Él dijo \"hola\""

    printf '%s\n' '→ Y un dólar literal dentro de comillas dobles:'
    printf '%s\n' '  echo "Cuesta \$5"'
    echo "Cuesta \$5"

    printf '%s\n' "→ Las comillas no se imprimen: solo agrupan el texto."
    printf '%s\n' "  echo '\"Hola\"'"
    echo '"Hola"'
}

demo_00_resto() {
    local tmp
    tmp=$(mktemp -d) || return 0
    (
        cd "$tmp" || exit 0

        printf '%s\n' "→ Trabajamos en una carpeta temporal para no tocar tus archivos."
        printf '%s\n' "→ pwd muestra dónde estás:"
        pwd

        printf '%s\n' "→ ls lista lo que hay (al principio está vacía):"
        ls -A

        printf '%s\n' "→ echo imprime texto:"
        echo "Hola, bash"

        printf '%s\n' "→ > envía la salida a un archivo; no se ve en pantalla:"
        printf '%s\n' "Hola, archivo" > saludo.txt
        printf '%s\n' "→ cat muestra el contenido del archivo:"
        cat saludo.txt

        printf '%s\n' "→ creamos un script con shebang y un echo:"
        printf '%s\n' '#!/bin/bash' 'echo "Hola desde un script"' > hola.sh
        cat hola.sh

        printf '%s\n' "→ bash lo ejecuta:"
        bash hola.sh

        printf '%s\n' "→ bash -n revisa la sintaxis sin ejecutar:"
        bash -n hola.sh && printf '%s\n' "sin errores de sintaxis"

        printf '%s\n' "→ chmod +x da permiso de ejecución:"
        chmod +x hola.sh
        ls -l hola.sh

        printf '%s\n' "→ ./hola.sh lo ejecuta directamente:"
        ./hola.sh
    )
    rm -rf "$tmp"
}

# El self-test ejecuta demo_00; el nivel 0 llama a las dos partes por separado.
demo_00() {
    demo_00_comillas
    demo_00_resto
}

reto_00_1() {
    definir_reto \
        "0.1" \
        "OBJETIVO
Escribe el contenido de tu primer script, hola.sh, que salude.
Un archivo .sh es, por convención, un script de shell: texto con
órdenes de bash.

SALIDA ESPERADA
Hola, bash

El shebang es parte del ejercicio: la primera línea debe ser
#!/bin/bash. No tienes que crear el archivo a mano." \
        "Escribe dos líneas:
  #!/bin/bash
  echo \"Hola, bash\"" \
        '#!/bin/bash
echo "Hola, bash"' \
        '#!/bin/bash
echo "Adiós"' \
        '' 5 \
        "|Hola, bash|0"
    R_ARCHIVO="hola.sh"
    R_NOTA="CÓMO SE EJECUTA
El curso guarda tu texto como hola.sh y lo ejecuta con bash.
No hace falta chmod +x."
    R_LOGRO="Has escrito un script con shebang y lo has ejecutado con bash."
}

reto_00_2() {
    definir_reto \
        "0.2" \
        "OBJETIVO
Escribe el contenido de comillas.sh para que imprima exactamente
esta línea, con TRES espacios entre «Hola,» y «mundo»:

Hola,   mundo
     ^^^ tres espacios, no uno

Usa comillas dobles alrededor del texto. Las comillas no se imprimen:
solo agrupan el texto para que bash conserve los espacios." \
        "echo \"Hola,   mundo\"
Las comillas dobles conservan los espacios. Sin comillas, bash separa
el texto por espacios y los convierte en uno solo.
La salida debe ser Hola,   mundo (sin comillas alrededor)." \
        'echo "Hola,   mundo"' \
        'echo Hola,   mundo' \
        '' 5 \
        "|Hola,   mundo|0"
    R_ARCHIVO="comillas.sh"
    R_NOTA="CÓMO SE EJECUTA
El curso guarda tu texto como comillas.sh y lo ejecuta con bash.
No necesitas shebang ni chmod; aquí lo importante es la línea de echo."
    R_LOGRO="Has usado comillas para conservar los espacios."
}

reto_00_3() {
    definir_reto \
        "0.3" \
        "OBJETIVO
Crea un archivo llamado saludo.txt en el directorio actual.
Su contenido debe ser exactamente esta línea:

Hola, bash

Usa una redirección > para enviar el texto al archivo.
No imprimas nada por pantalla: el texto debe quedar dentro." \
        "echo \"Hola, bash\" > saludo.txt
El símbolo > escribe la salida en un archivo en vez de en la pantalla." \
        'echo "Hola, bash" > saludo.txt' \
        'echo "Hola, bash" > saludo.txt.bak' \
        '' 5 \
        "||0"
    R_CHEQUEO='[[ -f saludo.txt ]] && [[ "$(cat saludo.txt)" == "Hola, bash" ]]'
    R_NOTA="CÓMO SE EJECUTA
El curso ejecuta tu código con bash; no necesitas shebang ni chmod.
Después comprueba que saludo.txt existe y contiene el texto."
    R_LOGRO="Has usado > para crear saludo.txt con el texto dentro."
}

RETOS_00=(reto_00_1 reto_00_2 reto_00_3)

paso_00_intro() {
    pantalla "Nivel 0 · ${TITULOS[0]}" "Vamos despacio, desde el principio.
No hace falta saber nada de programación.
Al final escribirás y ejecutarás tus propios archivos.

Atajos: Enter avanza · :atras vuelve · :inicio reinicia · :salir sale." "Enter para empezar"
}

paso_00_terminal() {
    pantalla "Nivel 0 · Parte 1" "La terminal y las carpetas" ""
    paginar "$(cat <<'TEXTO'
La terminal es una ventana donde escribes órdenes.
Bash es el programa que lee esas órdenes y las ejecuta.

Al abrir la terminal verás un prompt parecido a:
  arch@maquina:~$
El prompt no se escribe: solo indica que bash espera una orden.

Una orden tiene un comando y, a veces, argumentos:
  ls -l /home/arch
  │  │  └── argumento: qué quieres listar
  │  └───── argumento: cómo lo quieres listar
  └──────── comando: qué programa se ejecuta

El directorio actual es la carpeta donde estás.
  pwd          imprime el directorio actual (print working directory)
  ls           lista el contenido
  ls -l        lista con detalles: permisos, tamaño, fecha
  ls -A        incluye archivos ocultos (los que empiezan por .)
  cd carpeta   entra en una carpeta
  cd ..        sube a la carpeta padre
  cd           vuelve a tu carpeta personal
  cd -         vuelve a la carpeta anterior

Hay dos formas de escribir una ruta:
  /home/arch/notas.txt   absoluta: empieza por / y no depende de dónde estés
  notas.txt              relativa: se busca desde el directorio actual
  ./notas.txt            relativa explícita: «aquí mismo»
  ../notas.txt           relativa: en la carpeta padre

Truco: si un nombre lleva espacios, ponlo entre comillas.
  cd "Mis documentos"
TEXTO
)"
}

paso_00_archivos() {
    pantalla "Nivel 0 · Parte 2" "Archivos y extensiones" ""
    paginar "$(cat <<'TEXTO'
Un archivo guarda texto o datos. Su nombre suele terminar en una
extensión: la parte que va después del último punto.

  hola.sh     .sh   convención para scripts de shell
  saludo.txt  .txt  convención para texto plano
  datos.csv   .csv  convención para datos separados por comas
  foto.png    .png  convención para imágenes

La extensión NO cambia el contenido ni lo que bash puede hacer.
Bash no mira la extensión: `bash archivo.txt` también ejecuta su texto.
La extensión es una convención para que las personas y los editores
sepáis qué esperar. Por eso:
  - un script se llama .sh
  - una nota o un dato de texto se llama .txt

Crear texto en pantalla:
  echo "Hola"             imprime Hola y un salto de línea
TEXTO
)"
}

paso_00_comillas() {
    pantalla "Nivel 0 · Parte 3" "Comillas y argumentos" ""
    paginar "$(cat <<'TEXTO'
Las comillas agrupan el texto en un solo argumento y no se imprimen.
Sin comillas, bash parte la línea por los espacios:

  echo Hola,   mundo     → Hola, mundo
  echo "Hola,   mundo"   → Hola,   mundo
  echo 'Hola,   mundo'   → Hola,   mundo

No es echo quien borra los espacios: bash ya los usó como separadores
antes de ejecutarlo. Con comillas, el texto llega entero.

  "..."  comillas dobles: conservan espacios y expanden $variables
  '...'  comillas simples: conservan espacios y todo es literal

  echo "Vivo en $HOME"   → Vivo en /home/arch
  echo 'Vivo en $HOME'   → Vivo en $HOME

La barra invertida \ escapa un carácter especial dentro de comillas
dobles: \" imprime una comilla y \$ un dólar literal.
  echo "Él dijo \"hola\""  → Él dijo "hola"
  echo "Cuesta \$5"        → Cuesta $5
Dentro de comillas simples no hace falta escapar: todo es literal.

Las comillas tampoco forman parte de la salida:
  echo "Hola"     → Hola
  echo '"Hola"'   → "Hola"

Regla práctica: si el texto lleva espacios, ponlo entre comillas.
Usa dobles por defecto; simples si quieres que $ y \ sean literales.
Usa comillas rectas ' y ", no las curvas “ ”.
TEXTO
)"
}

paso_00_demo_comillas() {
    pantalla "Nivel 0 · Demo de comillas" "Mira la diferencia entre usar comillas y no usarlas.
No tienes que escribir nada: solo observa y pulsa Enter." ""
    demo_00_comillas
}

paso_00_redirigir() {
    pantalla "Nivel 0 · Parte 4" "Redirigir la salida a un archivo" ""
    paginar "$(cat <<'TEXTO'
La salida normal de un comando se llama stdout y va a la pantalla.
Puedes redirigirla a un archivo con >:

  echo "Hola" > saludo.txt

Eso crea saludo.txt (o lo sobrescribe si ya existía) y no imprime
nada en pantalla. Para añadir sin borrar lo anterior:

  echo "Adiós" >> saludo.txt

Para ver lo que quedó dentro:

  cat saludo.txt

También puedes crear carpetas:

  mkdir practica
  mkdir -p ruta/que/no/existe

> escribe; >> añade. El archivo se crea en el directorio actual
salvo que indiques una ruta:

  echo "Hola" > practica/saludo.txt
TEXTO
)"
}

paso_00_script() {
    pantalla "Nivel 0 · Parte 5" "Tu primer script" ""
    paginar "$(cat <<'TEXTO'
Un script es un archivo de texto con órdenes de bash, una por línea.

  #!/bin/bash
  echo "Hola, bash"

La primera línea es el shebang: empieza por #! e indica qué programa
debe interpretar el archivo. Al ejecutar ./script.sh, el sistema lee
esa línea y usa /bin/bash.
Si lo ejecutas con `bash script.sh`, el shebang no hace falta, pero
es buena costumbre ponerlo.

Las demás líneas que empiezan por # son comentarios: bash las ignora.
Sirven para explicar el código.

Formas de ejecutar:
  bash hola.sh        bash lee el archivo; no necesita permiso de ejecución
  chmod +x hola.sh    añade permiso de ejecución
  ./hola.sh           lo ejecuta directamente (usa el shebang)

Comprobar la sintaxis sin ejecutar:
  bash -n hola.sh

Un script no es magia: es texto. Puedes verlo con cat y editarlo.
TEXTO
)"
}

paso_00_demo_final() {
    pantalla "Nivel 0 · Demo final" "Ahora vemos archivos, redirecciones y scripts paso a paso.
No tienes que escribir nada todavía: solo mira y pulsa Enter." ""
    demo_00_resto
}

PASOS_00=(
    paso_00_intro
    paso_00_terminal
    paso_00_archivos
    paso_00_comillas
    paso_00_demo_comillas
    paso_00_redirigir
    paso_00_script
    paso_00_demo_final
)

leccion_00() {
    recorrer_pasos PASOS_00 || return 1

    if ejecutar_retos_de 0; then
        finalizar_leccion 0
        return 0
    fi

    pantalla "Nivel 0" "Aún quedan retos pendientes.
Los tienes guardados en el repaso adaptativo." "Enter para volver"
    pausa
    return 1
}

# ------------------------------------------------------------ nivel 1 --------

demo_01_variables() {
    local nombre="Ada"

    echo "→ asignación: sin espacios alrededor del ="
    echo "nombre=$nombre"

    echo "→ las comillas dobles expanden; las simples no"
    echo "dobles: hola $nombre"
    echo 'simples: hola $nombre'

    echo "→ las llaves separan el nombre del texto"
    echo "${nombre}ismo"
}

demo_01_aritmetica() {
    local a=7 b=3 edad

    echo "→ aritmética entera con \$(( ))"
    echo "a=$a  b=$b"
    echo "suma:            $((a + b))"
    echo "resta:           $((a - b))"
    echo "producto:        $((a * b))"
    echo "división entera: $((a / b))"
    echo "resto:           $((a % b))"

    edad=$((2026 - 1990))
    echo "edad en 2026: $edad"
}

demo_01_read_basico() {
    local nombre interactivo=0

    [[ $AUTOTEST -eq 0 && -t 0 ]] && interactivo=1

    echo "→ read sin -p: no imprime nada; espera a que escribas"
    if (( interactivo )); then
        echo "Escribe tu nombre y pulsa Enter:"
        read -r -e nombre || nombre=""
    else
        echo "  (demo automática: escribimos Ada por ti)"
        nombre="Ada"
    fi
    echo "Hola, $nombre"

    echo
    echo "Así se usa read en un script:"
    echo '  echo "Escribe tu nombre:"'
    echo '  read -r nombre'
    echo '  echo "Hola, $nombre"'
}

demo_01_read_p() {
    local ciudad interactivo=0

    [[ $AUTOTEST -eq 0 && -t 0 ]] && interactivo=1

    echo "→ read -p: mensaje y lectura en la misma orden"
    if (( interactivo )); then
        read -r -e -p "Escribe tu ciudad: " ciudad || ciudad=""
    else
        echo "Escribe tu ciudad: Madrid (demo)"
        ciudad="Madrid"
    fi
    echo "ciudad: $ciudad"

    echo
    echo "Forma habitual en un script:"
    echo '  read -r -p "Escribe tu ciudad: " ciudad'
    echo '  echo "ciudad: $ciudad"'
}

demo_01_read_r_ifs() {
    local ruta frase interactivo=0

    [[ $AUTOTEST -eq 0 && -t 0 ]] && interactivo=1

    echo "→ -r evita que se coman las barras invertidas"
    echo 'C:\Users\arch' | {
        read ruta
        echo "read:     $ruta"
    }
    echo 'C:\Users\arch' | {
        read -r ruta
        echo "read -r:  $ruta"
    }

    echo
    echo "→ IFS= read -r copia la línea entera, con sus espacios"
    echo '  hola   mundo  ' | {
        read frase
        echo "read:       [$frase]"
    }
    echo '  hola   mundo  ' | {
        IFS= read -r frase
        echo "IFS= read:  [$frase]"
    }

    if (( interactivo )); then
        echo
        echo "Prueba tú: escribe una frase con espacios al principio o al final."
        IFS= read -r -e -p "Frase: " frase || frase=""
        echo "frase: [$frase]"
    fi
}

# El self-test ejecuta demo_01; el nivel 1 llama a cada demo por separado.
demo_01() {
    demo_01_variables
    demo_01_aritmetica
    demo_01_read_basico
    demo_01_read_p
    demo_01_read_r_ifs
}

reto_01_1() {
    definir_reto \
        "1.1" \
        "OBJETIVO
Pide dos números y muestra su suma y su producto.
Es el uso habitual de read: preguntar, leer y responder.

ENTRADA: dos números, uno por línea.
SALIDA ESPERADA:
suma: N
producto: M
EJEMPLO: 3 y 4 → suma: 7 · producto: 12

Puedes usar read -r -p; su mensaje no cuenta como salida." \
        "Lee cada número con read -r o read -r -p y calcula con \$(( ))." \
        'read -r -p "Primer número: " a
read -r -p "Segundo número: " b
echo "suma: $((a + b))"
echo "producto: $((a * b))"' \
        'read -r a
read -r b
echo "suma: $a"
echo "producto: $b"' \
        '' 5 \
        "3
4|suma: 7
producto: 12|0" \
        "0
5|suma: 5
producto: 0|0" \
        "-2
3|suma: 1
producto: -6|0"
    R_LOGRO="Has leído dos números con read y has calculado con \$(( ))."
}

reto_01_2() {
    definir_reto \
        "1.2" \
        "OBJETIVO
Lee una frase completa y conserva sus espacios.
Es lo que harías para leer una dirección o un comentario.

ENTRADA: una frase con espacios al principio, al final o en medio.
SALIDA ESPERADA:
Frase: <frase>
EJEMPLO:
  entrada: «  hola   mundo»
  salida:  «Frase:   hola   mundo»

Usa IFS= read -r -p \"Frase: \" frase: el IFS vacío evita que read
recorte los espacios de los extremos." \
        "Usa IFS= read -r -p \"Frase: \" frase y rodea \$frase con comillas dobles." \
        'IFS= read -r -p "Frase: " frase
echo "Frase: $frase"' \
        'read frase
echo Frase: $frase' \
        '' 5 \
        "  hola   mundo|Frase:   hola   mundo|0"
    R_NOTA="CÓMO SE EJECUTA
El curso ejecuta tu código con bash; no necesitas shebang ni chmod.
La frase de prueba la pone el curso: no la escribas en el editor.
read -p no muestra el mensaje al corregir porque la entrada llega
por una tubería; en la demo sí se ve porque hay teclado."
    R_LOGRO="Has conservado los espacios con IFS= read -r."
}

RETOS_01=(reto_01_1 reto_01_2)

paso_01_intro() {
    pantalla "Nivel 1 · ${TITULOS[1]}" "Vamos a guardar datos en variables, hacer cuentas
y leer lo que escribe el usuario.

Atajos: Enter avanza · :atras vuelve · :inicio reinicia · :salir sale." "Enter para empezar"
}

paso_01_variables() {
    pantalla "Nivel 1 · Parte 1" "Variables y comillas" ""
    paginar "$(cat <<'TEXTO'
Una variable guarda un valor con un nombre. Se asigna así:
  nombre=Ada

No pongas espacios alrededor del =:
  nombre = Ada    ← error

Para usar el valor, pon $ delante:
  echo "Hola, $nombre"     → Hola, Ada
  echo 'Hola, $nombre'     → Hola, $nombre

Las comillas dobles expanden la variable; las simples la dejan literal.
Si el valor lleva espacios, ponlo entre comillas al asignarlo:
  frase="hola mundo"

Las llaves separan el nombre del texto que va detrás:
  echo "${nombre}ismo"     → Adaismo
TEXTO
)"
}

paso_01_demo_variables() {
    pantalla "Nivel 1 · Demo de variables" "Mira cómo se asigna y se usa una variable." ""
    demo_01_variables
}

paso_01_aritmetica() {
    pantalla "Nivel 1 · Parte 2" "Aritmética entera" ""
    paginar "$(cat <<'TEXTO'
Bash hace aritmética entera, sin decimales, con $(( )):
  a=7
  b=3

  echo $((a + b))    → 10
  echo $((a - b))    → 4
  echo $((a * b))    → 21
  echo $((a / b))    → 2    división entera
  echo $((a % b))    → 1    resto

El resultado se puede guardar en una variable:
  edad=$((2026 - 1990))
  echo "Edad: $edad"

Dentro de $(( )) las variables van sin $:
  $((a + b)) es lo mismo que $(($a + $b)), pero más claro.
TEXTO
)"
}

paso_01_demo_aritmetica() {
    pantalla "Nivel 1 · Demo de aritmética" "Mira las operaciones y cómo se guarda el resultado." ""
    demo_01_aritmetica
}

paso_01_read_basico() {
    pantalla "Nivel 1 · Parte 3" "Leer datos con read" ""
    paginar "$(cat <<'TEXTO'
read lee una línea de la entrada y la guarda en una variable.
Por sí solo no imprime nada: espera a que escribas y pulses Enter.

Forma completa, con el mensaje aparte:
  echo "¿Cómo te llamas?"
  read -r nombre
  echo "Hola, $nombre"

En pantalla:
  ¿Cómo te llamas?
  Ada
  Hola, Ada

En un script normal, read sin -p se usa después de un echo.
TEXTO
)"
}

paso_01_demo_read_basico() {
    pantalla "Nivel 1 · Demo de read" "Vamos a pedirte el nombre con read normal." ""
    demo_01_read_basico
}

paso_01_read_p() {
    pantalla "Nivel 1 · Parte 3" "read -p y -r" ""
    paginar "$(cat <<'TEXTO'
read -p muestra el mensaje y lee en la misma orden:
  read -r -p "¿Cómo te llamas? " nombre
  echo "Hola, $nombre"

El espacio final del mensaje separa el texto de lo que escribes.
Esta es la forma más habitual dentro de un script.

-r significa «raw»: no interpreta las barras invertidas.
  read -r ruta     guarda C:\Users\arch tal cual
  read ruta        se come las barras: C:Usersarch
Usa -r casi siempre.

En un reto no hace falta -p: la entrada ya llega por la tubería.
TEXTO
)"
}

paso_01_demo_read_p() {
    pantalla "Nivel 1 · Demo de read -p" "Ahora el mensaje va dentro de read." ""
    demo_01_read_p
}

paso_01_read_ifs() {
    pantalla "Nivel 1 · Parte 3" "IFS y espacios" ""
    paginar "$(cat <<'TEXTO'
IFS contiene los separadores que usa read: espacio, tabulador y salto
de línea. Por eso read recorta los espacios de los extremos.

Para copiar la línea entera, incluidos esos espacios, vacía IFS solo
para esa orden:
  IFS= read -r frase
  echo "[$frase]"

Con la entrada «  hola   mundo  »:
  read frase           → [hola   mundo]
  IFS= read -r frase   → [  hola   mundo  ]

El IFS= de delante solo afecta a esa orden; no cambia IFS para siempre.
TEXTO
)"
}

paso_01_demo_read_ifs() {
    pantalla "Nivel 1 · Demo de -r e IFS=" "Mira las barras y los espacios. Al final puedes probar una frase." ""
    demo_01_read_r_ifs
}

paso_01_como_probar() {
    pantalla "Nivel 1 · Cómo se prueban los retos" "En un reto no escribes la entrada: escribes tu código y terminas
con una línea que sea solo #fin.

Después el curso ejecuta tu código y le pasa los datos de prueba
automáticamente. Compara la salida y el código de salida.

read -p funciona en un script normal, pero en la corrección no se ve
su mensaje: la entrada llega por una tubería, no por un teclado.
En las demos sí lo ves porque estás escribiendo tú." "Enter para empezar los retos"
}

PASOS_01=(
    paso_01_intro
    paso_01_variables
    paso_01_demo_variables
    paso_01_aritmetica
    paso_01_demo_aritmetica
    paso_01_read_basico
    paso_01_demo_read_basico
    paso_01_read_p
    paso_01_demo_read_p
    paso_01_read_ifs
    paso_01_demo_read_ifs
    paso_01_como_probar
)

leccion_01() {
    recorrer_pasos PASOS_01 || return 1

    if ejecutar_retos_de 1; then
        finalizar_leccion 1
        return 0
    fi

    pantalla "Nivel 1" "Aún quedan retos pendientes.
Los tienes guardados en el repaso adaptativo." "Enter para volver"
    pausa
    return 1
}

# ------------------------------------------------------------ nivel 2 --------

demo_02() {
    printf '%s\n' "→ printf con formato"
    printf 'Hola, %s. Tu número favorito es %03d.\n' "Ada" 7

    printf '%s\n' "→ códigos de salida: 0 es éxito"
    true
    printf 'true  -> $? = %s\n' "$?"
    false
    printf 'false -> $? = %s\n' "$?"

    printf '%s\n' "→ && y ||"
    true && printf '%s\n' "esto se imprime (&&)"
    false || printf '%s\n' "esto también (||)"

    printf '%s\n' "→ echo -e no es portable; printf sí"
    printf 'linea1\nlinea2\n'
}

reto_02_1() {
    definir_reto \
        "2.1" \
        "OBJETIVO
Lee un número y clasifícalo.

ENTRADA
Un número por la entrada estándar.

SALIDA ESPERADA
Si está entre 1 y 10 (incluidos):
  ok
En cualquier otro caso:
  fuera de rango

CÓDIGO DE SALIDA
0 si está dentro del rango; 1 si está fuera.

Un valor no numérico (por ejemplo, abc), el cero y los negativos
también cuentan como fuera de rango." \
        "Usa read -r para leer, [[ \$n =~ ^[0-9]+\$ ]] o (( )) para comprobar, y exit 1 en la rama de error." \
        'read -r n
if [[ $n =~ ^[0-9]+$ ]] && (( n >= 1 && n <= 10 )); then
  echo ok
else
  echo "fuera de rango"
  exit 1
fi' \
        'read -r n
echo ok' \
        '' 5 \
        "5|ok|0" \
        "42|fuera de rango|1" \
        "abc|fuera de rango|1" \
        "0|fuera de rango|1"
    R_LOGRO="Has leído un número, lo has comprobado y has devuelto el código correcto."
}

RETOS_02=(reto_02_1)

paso_02_intro() {
    pantalla "Nivel 2 · ${TITULOS[2]}" "Un script lee datos, produce salida y dice si salió bien.

Atajos: Enter avanza · :atras vuelve · :inicio reinicia · :salir sale." "Enter para empezar"
}

paso_02_teoria() {
    pantalla "Nivel 2 · Teoría" "Entrada, salida y códigos de estado" ""
    paginar "Un script hace tres cosas: leer datos, producir salida y decir si salió bien.

• read -r variable   lee una línea de la entrada estándar.
• printf '%s\\n' ...  imprime con formato predecible.
• echo ...           atajo cómodo, pero -e y -n varían entre sistemas.
• \$?                 código de salida del último comando (0 = éxito).
• exit N             termina el script con el código N.
• cmd1 && cmd2       ejecuta cmd2 solo si cmd1 salió bien.
• cmd1 || cmd2       ejecuta cmd2 solo si cmd1 falló.

Regla de oro: un script debe devolver 0 cuando hizo su trabajo,
y un código distinto de 0 cuando no pudo hacerlo.

En el reto, ojo al detalle: la salida debe ser exactamente la pedida."
}

paso_02_demo() {
    pantalla "Nivel 2 · Demo" "Mira printf, los códigos de salida y && / ||." ""
    demo_02
}

PASOS_02=(
    paso_02_intro
    paso_02_teoria
    paso_02_demo
)

leccion_02() {
    recorrer_pasos PASOS_02 || return 1

    if ejecutar_retos_de 2; then
        finalizar_leccion 2
        return 0
    fi

    pantalla "Nivel 2" "Aún quedan retos pendientes.
Los tienes guardados en el repaso adaptativo." "Enter para volver"
    pausa
    return 1
}

# ------------------------------------------------------------ nivel 4 --------

demo_04() {
    printf '%s\n' "→ for sobre una lista"
    local fruta
    for fruta in manzana pera; do
        printf '  %s\n' "$fruta"
    done

    printf '%s\n' "→ for sobre un rango"
    local i
    for i in {1..3}; do
        printf '  %s\n' "$i"
    done

    printf '%s\n' "→ while con contador"
    local n=0
    while (( n < 3 )); do
        n=$((n + 1))
        printf '  vuelta %s\n' "$n"
    done

    printf '%s\n' "→ until (hasta que se cumpla)"
    n=0
    until (( n >= 2 )); do
        n=$((n + 1))
        printf '  hasta %s\n' "$n"
    done

    printf '%s\n' "→ read en bucle"
    local linea
    while IFS= read -r linea; do
        printf '  leído: %s\n' "$linea"
    done <<'EOF'
uno
dos
EOF

    printf '%s\n' "→ case"
    local opcion=2
    case $opcion in
        1) printf '  uno\n' ;;
        2) printf '  dos\n' ;;
        *) printf '  otro\n' ;;
    esac
}

reto_04_1() {
    definir_reto \
        "4.1" \
        "OBJETIVO
Repite una acción con un bucle for.
Imprime los números del 1 al 5, uno por línea, en orden ascendente.

SALIDA ESPERADA
1
2
3
4
5" \
        "Un for con {1..5} y echo dentro del bucle." \
        'for i in {1..5}; do
  echo "$i"
done' \
        'echo 1 2 3 4 5' \
        '' 5 \
        "|1
2
3
4
5|0"
    R_LOGRO="Has recorrido un rango con for."
}

reto_04_2() {
    definir_reto \
        "4.2" \
        "OBJETIVO
Escribe un menú que se repita hasta que se elija la opción 3.
Es la forma habitual de usar read dentro de un bucle.

En cada vuelta debe imprimir:
1) saludar
2) despedir
3) salir

Después lee la opción con read -r y actúa así:
  1 → imprime: hola
  2 → imprime: adios
  3 → imprime: fin  y termina con código 0
  otra → imprime: opcion invalida

Si la entrada se acaba (EOF), termina también con código 0." \
        "while true; do ... case \$opcion in ... 3) break ;; esac; done
Recuerda: read devuelve error en EOF; añade || break." \
        'while true; do
  echo "1) saludar"
  echo "2) despedir"
  echo "3) salir"
  read -r opcion || break
  case $opcion in
    1) echo "hola" ;;
    2) echo "adios" ;;
    3) echo "fin"; break ;;
    *) echo "opcion invalida" ;;
  esac
done' \
        'echo "1) saludar"
echo "2) despedir"
echo "3) salir"
read -r opcion
case $opcion in
  1) echo "hola" ;;
  2) echo "adios" ;;
  3) echo "fin" ;;
esac' \
        '' 5 \
        "1
2
3|1) saludar
2) despedir
3) salir
hola
1) saludar
2) despedir
3) salir
adios
1) saludar
2) despedir
3) salir
fin|0" \
        "9
3|1) saludar
2) despedir
3) salir
opcion invalida
1) saludar
2) despedir
3) salir
fin|0"
    R_LOGRO="Has usado read dentro de un bucle para construir un menú."
}

RETOS_04=(reto_04_1 reto_04_2)

paso_04_intro() {
    pantalla "Nivel 4 · ${TITULOS[4]}" "Los bucles repiten trabajo y case elige entre opciones.

Atajos: Enter avanza · :atras vuelve · :inicio reinicia · :salir sale." "Enter para empezar"
}

paso_04_teoria() {
    pantalla "Nivel 4 · Teoría" "Bucles y menús" ""
    paginar "Los bucles repiten trabajo y case elige entre opciones.

• for x in lista; do ...; done        recorre elementos.
• for i in {1..5}; do ...; done       recorre un rango.
• while condicion; do ...; done       repite mientras sea cierta.
• until condicion; do ...; done       repite hasta que sea cierta.
• break / continue                    sale del bucle / salta a la siguiente vuelta.
• case \$x in patron) ... ;; esac      elige una rama, como un if múltiple.

Un menú es un while true que solo termina con break.
Cuidado: si la entrada se acaba (EOF), read falla y el bucle puede girar sin fin.
En un menú real, comprueba el resultado de read."
}

paso_04_demo() {
    pantalla "Nivel 4 · Demo" "Mira for, while, until, read en bucle y case." ""
    demo_04
}

PASOS_04=(
    paso_04_intro
    paso_04_teoria
    paso_04_demo
)

leccion_04() {
    recorrer_pasos PASOS_04 || return 1

    if ejecutar_retos_de 4; then
        finalizar_leccion 4
        return 0
    fi

    pantalla "Nivel 4" "Aún quedan retos pendientes.
Los tienes guardados en el repaso adaptativo." "Enter para volver"
    pausa
    return 1
}

# =================================================================== repaso ===

repaso_adaptativo() {
    local total
    total=$(contar_lista "$EST_PENDIENTES")
    if (( total == 0 )); then
        pantalla "Repaso" "No tienes retos pendientes. ¡Buen trabajo!" "Enter para volver"
        pausa
        return 0
    fi

    local -a ids=()
    dividir_lista "$EST_PENDIENTES"
    if (( ${#LISTA[@]} > 0 )); then
        ids=("${LISTA[@]}")
    fi

    local id fn hechos=0
    for id in "${ids[@]}"; do
        (( hechos >= 3 )) && break
        fn=$(funcion_reto_por_id "$id")
        declare -F "$fn" >/dev/null 2>&1 || continue
        "$fn"
        bucle_reto 5
        hechos=$((hechos + 1))
    done

    pantalla "Repaso terminado" "Pendientes restantes: $(contar_lista "$EST_PENDIENTES")" "Enter para volver"
    pausa
}

# =================================================================== menú =====

contar_pendientes() {
    contar_lista "$EST_PENDIENTES"
}

listado_menu() {
    local n fn estado
    for (( n = 0; n <= 12; n++ )); do
        fn=$(funcion_leccion "$n")
        if ! declare -F "$fn" >/dev/null 2>&1; then
            estado="${C_GRIS}· en construcción${C_RESET}"
        elif lista_contiene "$EST_COMPLETADAS" "$n"; then
            estado="${C_OK}✔ superado${C_RESET}"
        else
            estado="${C_AVISO}○ disponible${C_RESET}"
        fi
        printf '  %2d  %-42s %s\n' "$n" "${TITULOS[$n]}" "$estado"
    done
}

menu_principal() {
    local opcion
    while true; do
        pantalla "bash4u · elige un nivel" "$(listado_menu)

${C_GRIS}r) repaso adaptativo ($(contar_pendientes) pendientes)   c) chuletas   q) salir
Dentro de una lección: Enter avanza · :atras vuelve · :inicio reinicia · :salir sale.${C_RESET}" "Los niveles 2 y 4 son los pilotos de la Fase 1."

        printf '%s' "${C_PROMPT}Opción: ${C_RESET}"
        if ! IFS= read -r opcion; then
            printf '\n'
            return 0
        fi

        if [[ $opcion =~ ^([0-9]|1[0-2])$ ]]; then
            ejecutar_leccion "$opcion"
            continue
        fi

        case $opcion in
            r|R) repaso_adaptativo ;;
            c|C) lista_chuletas ;;
            q|Q|salir) printf '%s\n' "¡Hasta luego!"; return 0 ;;
            "") ;;
            *) printf '%s\n' "${C_ERR}Opción no válida.${C_RESET}" ; pausa ;;
        esac
    done
}

lista_chuletas() {
    pantalla "Chuletas" "Disponible al superar cada nivel. Aún en construcción." "Enter para volver"
    pausa
}

modo_lineal() {
    local num
    while true; do
        num=$(siguiente_leccion)

        if [[ -z $num ]]; then
            pantalla "Todo hecho" "No quedan niveles disponibles en esta versión.
El siguiente hito es el menú: se desbloquea al superar el nivel 4." "Enter para salir"
            pausa
            return 0
        fi

        if ! ejecutar_leccion "$num"; then
            pantalla "Nivel ${num}" "Vuelve cuando quieras; tu progreso está guardado." "Enter para salir"
            pausa
            return 0
        fi

        if tiene_cap menu; then
            menu_principal
            return 0
        fi
    done
}

# ================================================================ self-test ===

ok() { printf '  ✔ %s\n' "$1"; }
mal() { printf '  ✘ %s\n' "$1"; }

probar_etapas() {
    local s
    for s in 0 1 2 3 4 5; do
        CAPS_OVERRIDE=$(caps_etapa "$s")
        CAPS_OVERRIDE_ACTIVO=1
        local fallo=0
        case $s in
            0) tiene_cap colores && fallo=1 ;;
            1) tiene_cap colores || fallo=1 ;;
            2) tiene_cap menu || fallo=1 ;;
            3) tiene_cap editor || fallo=1 ;;
            4) tiene_cap fzf || fallo=1 ;;
            5) tiene_cap stats || fallo=1 ;;
        esac
        if (( fallo )); then
            CAPS_OVERRIDE=""
            CAPS_OVERRIDE_ACTIVO=0
            return 1
        fi
    done
    CAPS_OVERRIDE=""
    CAPS_OVERRIDE_ACTIVO=0
    return 0
}

probar_resets() {
    local fallos=0
    local raiz datos practicas
    raiz=$(mktemp -d) || return 1
    datos="$raiz/datos"
    practicas="$raiz/practicas"
    mkdir -p "$datos" "$practicas"

    local o_datos=$DIR_DATOS o_arch=$ARCH_ESTADO o_prac=$DIR_PRACTICAS
    local o_plano=$MODO_PLANO o_forzar=$FORZAR

    DIR_DATOS=$datos
    ARCH_ESTADO="$datos/estado"
    DIR_PRACTICAS=$practicas
    MODO_PLANO=1
    FORZAR=1

    # Estado de mentira: niveles 0 y 2 superados, un reto pendiente.
    estado_defecto
    EST_COMPLETADAS="0,2"
    EST_RETOS="0.1,0.2,2.1"
    EST_PENDIENTES="2.2"
    EST_XP=70
    EST_DESBLOQUEOS="colores"
    EST_LECCION=2
    guardar_estado

    reset_nivel 2 >/dev/null 2>&1
    cargar_estado
    if [[ $EST_COMPLETADAS == "0" ]]; then
        ok "reset de nivel · quita el nivel de «superado»"
    else
        mal "reset de nivel · quita el nivel de «superado» ($EST_COMPLETADAS)"
        fallos=$((fallos + 1))
    fi
    if [[ $EST_RETOS == "0.1,0.2" ]]; then
        ok "reset de nivel · deja los retos de los otros niveles"
    else
        mal "reset de nivel · deja los retos de los otros niveles ($EST_RETOS)"
        fallos=$((fallos + 1))
    fi
    if [[ -z $EST_PENDIENTES ]]; then
        ok "reset de nivel · limpia los pendientes del nivel"
    else
        mal "reset de nivel · limpia los pendientes del nivel ($EST_PENDIENTES)"
        fallos=$((fallos + 1))
    fi
    if (( EST_XP == 40 )); then
        ok "reset de nivel · descuenta el XP del nivel (70 - 30)"
    else
        mal "reset de nivel · descuenta el XP del nivel (quedan $EST_XP, esperaba 40)"
        fallos=$((fallos + 1))
    fi
    if [[ $EST_DESBLOQUEOS == "colores" ]]; then
        ok "reset de nivel · conserva los desbloqueos"
    else
        mal "reset de nivel · conserva los desbloqueos ($EST_DESBLOQUEOS)"
        fallos=$((fallos + 1))
    fi
    if [[ $EST_LECCION != "2" ]]; then
        ok "reset de nivel · suelta el nivel actual"
    else
        mal "reset de nivel · suelta el nivel actual"
        fallos=$((fallos + 1))
    fi

    estado_defecto
    cargar_estado
    if [[ $EST_RETOS == "0.1,0.2" ]] && (( EST_XP == 40 )); then
        ok "reset de nivel · el cambio queda guardado en disco"
    else
        mal "reset de nivel · el cambio queda guardado en disco"
        fallos=$((fallos + 1))
    fi

    # Reinicio del progreso: borra el estado y conserva los scripts.
    printf 'hola\n' > "$practicas/hola.sh"
    reset_progreso >/dev/null 2>&1
    if [[ ! -f $ARCH_ESTADO ]]; then
        ok "reset de progreso · borra el estado"
    else
        mal "reset de progreso · borra el estado"
        fallos=$((fallos + 1))
    fi
    if [[ -f $practicas/hola.sh ]]; then
        ok "reset de progreso · conserva los scripts"
    else
        mal "reset de progreso · conserva los scripts"
        fallos=$((fallos + 1))
    fi

    # Reinicio total: borra también los scripts.
    estado_defecto
    EST_XP=10
    guardar_estado
    reset_total >/dev/null 2>&1
    if [[ ! -f $ARCH_ESTADO ]]; then
        ok "reset total · borra el estado"
    else
        mal "reset total · borra el estado"
        fallos=$((fallos + 1))
    fi
    if [[ ! -f $practicas/hola.sh ]]; then
        ok "reset total · borra los scripts de prácticas"
    else
        mal "reset total · borra los scripts de prácticas"
        fallos=$((fallos + 1))
    fi
    if [[ -d $practicas ]]; then
        ok "reset total · mantiene la carpeta de prácticas"
    else
        mal "reset total · mantiene la carpeta de prácticas"
        fallos=$((fallos + 1))
    fi

    # Restaurar el entorno real.
    DIR_DATOS=$o_datos
    ARCH_ESTADO=$o_arch
    DIR_PRACTICAS=$o_prac
    MODO_PLANO=$o_plano
    FORZAR=$o_forzar
    estado_defecto
    cargar_estado
    rm -rf "$raiz"

    (( fallos == 0 ))
}

self_test() {
    local fallos=0 total=0
    printf 'bash4u %s · self-test\n\n' "$VERSION"

    total=$((total + 1))
    if bash -n "$0"; then ok "sintaxis (bash -n)"; else mal "sintaxis (bash -n)"; fallos=$((fallos + 1)); fi

    total=$((total + 1))
    if probar_etapas; then ok "etapas 0-5"; else mal "etapas 0-5"; fallos=$((fallos + 1)); fi

    total=$((total + 1))
    if probar_resets; then ok "reinicios (progreso, nivel y total)"; else mal "reinicios (progreso, nivel y total)"; fallos=$((fallos + 1)); fi

    local entrada num titulo fn demo retos_nombre resto
    for entrada in "${LECCIONES[@]}"; do
        # Formato "N|título|función": se parte por el primer y el último «|».
        num=${entrada%%|*}
        resto=${entrada#*|}
        fn=${resto##*|}
        titulo=${resto%|*}
        declare -F "$fn" >/dev/null 2>&1 || continue
        printf '\nNivel %s · %s\n' "$num" "$titulo"

        demo=$(printf 'demo_%02d' "$num")
        total=$((total + 1))
        if declare -F "$demo" >/dev/null 2>&1 && (AUTOTEST=1 "$demo") >/dev/null 2>&1; then
            ok "demo"
        else
            mal "demo"
            fallos=$((fallos + 1))
        fi

        retos_nombre=$(printf 'RETOS_%02d' "$num")
        if declare -p "$retos_nombre" >/dev/null 2>&1; then
            local -n retos="$retos_nombre"
            local r
            for r in "${retos[@]}"; do
                "$r"

                total=$((total + 1))
                if ejecutar_codigo "$R_SOLUCION"; then
                    ok "reto $R_ID · solución de referencia"
                else
                    mal "reto $R_ID · solución de referencia ($DETALLE_FALLO)"
                    fallos=$((fallos + 1))
                fi

                total=$((total + 1))
                if ejecutar_codigo "$R_MALA"; then
                    mal "reto $R_ID · acepta una solución incorrecta"
                    fallos=$((fallos + 1))
                else
                    ok "reto $R_ID · rechaza solución incorrecta"
                fi
            done
            unset -n retos
        fi
    done

    printf '\n%s pruebas · %s fallos\n' "$total" "$fallos"
    if (( fallos == 0 )); then
        printf '%s\n' "Todo en orden."
        return 0
    fi
    return 1
}

# ================================================================== resets ====
#
# Reiniciar el progreso tiene tres fuerzas distintas:
#   --reset-progress   borra el estado (tu curso) y conserva tus scripts
#   --reset-nivel N    pone a cero un solo nivel
#   --reset-all        borra el estado y los scripts de prácticas
#
# Todos explican primero qué van a tocar y después piden confirmación.

# Muestra el estado guardado tal cual: una línea por dato (clave=valor).
mostrar_estado_actual() {
    printf '  completadas=%s\n' "$EST_COMPLETADAS"
    printf '  retos=%s\n' "$EST_RETOS"
    printf '  pendientes=%s\n' "$EST_PENDIENTES"
    printf '  xp=%s\n' "$EST_XP"
    printf '  desbloqueos=%s\n' "$EST_DESBLOQUEOS"
    printf '  leccion=%s\n' "$EST_LECCION"
}

# Cuenta en una lista (a,b,c) los elementos que empiezan por un prefijo.
contar_prefijo() {
    local lista=${1:-} prefijo=$2 n=0 x
    [[ -z $lista ]] && { printf '0'; return 0; }
    dividir_lista "$lista"
    for x in "${LISTA[@]}"; do
        [[ $x == "$prefijo"* ]] && n=$((n + 1))
    done
    printf '%s' "$n"
}

# Quita de una lista (a,b,c) los elementos que empiezan por un prefijo.
quitar_prefijo() {
    local lista=${1:-} prefijo=$2 salida="" x
    [[ -z $lista ]] && { printf ''; return 0; }
    dividir_lista "$lista"
    for x in "${LISTA[@]}"; do
        [[ $x == "$prefijo"* ]] && continue
        salida=${salida:+$salida,}$x
    done
    printf '%s' "$salida"
}

# Cuántos retos declara un nivel (0 si ese nivel todavía no existe).
retos_de_nivel() {
    local num=$1 nombre
    nombre=$(printf 'RETOS_%02d' "$num")
    if ! declare -p "$nombre" >/dev/null 2>&1; then
        printf '0'
        return 0
    fi
    local -n retos="$nombre"
    printf '%s' "${#retos[@]}"
    unset -n retos
}

# Lista el contenido de la carpeta de prácticas (para explicarla antes de borrar).
listado_practicas() {
    if [[ ! -d $DIR_PRACTICAS ]]; then
        printf '     (todavía no existe)'
        return 0
    fi

    local -a entradas=()
    local g1 g2
    g1=$(shopt -p dotglob); g2=$(shopt -p nullglob)
    shopt -s dotglob nullglob
    entradas=("$DIR_PRACTICAS"/*)
    eval "$g1"; eval "$g2"

    if (( ${#entradas[@]} == 0 )); then
        printf '     (vacía)'
        return 0
    fi

    local f
    for f in "${entradas[@]}"; do
        printf '     %s\n' "${f##*/}"
    done
}

# Borra el contenido de una carpeta (sin borrarla) y dice cuántos eran.
borrar_contenido() {
    local dir=$1 n=0
    [[ -d $dir ]] || { printf '0'; return 0; }

    local -a entradas=()
    local g1 g2
    g1=$(shopt -p dotglob); g2=$(shopt -p nullglob)
    shopt -s dotglob nullglob
    entradas=("$dir"/*)
    eval "$g1"; eval "$g2"

    local f
    for f in "${entradas[@]}"; do
        rm -rf -- "$f" && n=$((n + 1))
    done
    printf '%s' "$n"
}

# Pregunta antes de hacer algo que no se puede deshacer.
confirmar_reset() {
    local pregunta=$1 respuesta=""

    [[ $FORZAR -eq 1 ]] && return 0
    [[ $AUTOTEST -eq 1 ]] && return 0

    if [[ ! -t 0 ]]; then
        printf '\n%s\n' "(sin teclado: se ejecuta sin preguntar; añade --si si lo pones en un script)"
        return 0
    fi

    printf '\n%s' "${C_PROMPT}${pregunta} ${C_RESET}"
    if ! IFS= read -r -e respuesta; then
        printf '\n'
        return 1
    fi
    [[ $respuesta =~ ^[sSyY]$ ]]
}

# Explicación (con la línea del curso) de lo que va a pasar, antes de hacerlo.
explicar_reset() {
    local modo=$1 arg=${2:-}
    local titulo="" cuerpo="" pie=""
    local num=$arg total resueltos completado descuento estado_texto fn

    case $modo in
    progreso)
        titulo="Reiniciar tu progreso"
        cuerpo="Tu progreso no vive dentro del curso: vive en un archivo aparte.

  ${ARCH_ESTADO}

Y ahora mismo ese archivo dice:

$(mostrar_estado_actual)

Una línea por dato, con el formato clave=valor.

Tus scripts se guardan en otra carpeta:

  ${DIR_PRACTICAS}

Reiniciar el progreso es borrar ese archivo y nada más. Es como tirar
la libreta y empezar el temario otra vez: vuelves al nivel 0, con 0 XP
y sin habilidades desbloqueadas.

El curso no se toca: bash4u.sh sigue exactamente igual."
        pie="Se borra solo el estado; tus scripts de prácticas se conservan."
        ;;
    nivel)
        num=$arg
        total=$(retos_de_nivel "$num")
        resueltos=$(contar_prefijo "$EST_RETOS" "$num.")
        completado=0
        lista_contiene "$EST_COMPLETADAS" "$num" && completado=1
        descuento=$(( completado * 20 + resueltos * 10 ))
        if (( completado )); then
            estado_texto="lo tienes superado"
        else
            estado_texto="no lo has superado todavía"
        fi

        titulo="Reiniciar el nivel ${num} · ${TITULOS[$num]}"
        cuerpo="Vas a poner a cero un solo nivel, sin tocar el resto del curso.

  Nivel ${num}: ${TITULOS[$num]}
  Retos del nivel: ${total}
  Resueltos por ti: ${resueltos}
  Ahora mismo: ${estado_texto}

Al reiniciarlo:
  · el nivel deja de contar como «superado»
  · sus retos vuelven a la lista de pendientes: puedes repetirlos y
    sacar el XP otra vez (10 XP por reto)
  · se descuentan ${descuento} XP del total (20 por el nivel + 10 por
    cada reto que habías resuelto)
  · los demás niveles, tus habilidades desbloqueadas y tus scripts de
    prácticas se quedan como están

Los 5 XP extra del repaso adaptativo no se tocan: no se puede saber a
qué nivel pertenecían."
        pie="Solo afecta al nivel ${num}."
        ;;
    total)
        titulo="Reiniciar todo: progreso y scripts"
        cuerpo="Vas a borrar las dos cosas: tu progreso y tus scripts.

  1. El estado
     ${ARCH_ESTADO}

  2. Tus scripts de prácticas
     ${DIR_PRACTICAS}
$(listado_practicas)

Esto no se puede deshacer: los archivos se borran de verdad.
El curso (bash4u.sh) tampoco se toca."
        pie="Sin marcha atrás: esto es empezar de cero de verdad."
        ;;
    *)
        error "modo de reinicio desconocido: $modo"
        return 2
        ;;
    esac

    pantalla "$titulo" "$cuerpo" "$pie"
}

# Reinicio del progreso: borra el estado y conserva los scripts.
reset_progreso() {
    explicar_reset progreso

    if ! confirmar_reset "¿Borrar tu progreso y empezar de cero? (s/N)"; then
        printf '\n%s\n' "Cancelado: no se ha tocado nada."
        return 1
    fi

    rm -f "$ARCH_ESTADO"
    printf '\n%s\n' "Progreso borrado. Empiezas de cero: nivel 0, 0 XP."
    return 0
}

# Reinicio de un nivel: pone a cero ese nivel y nada más.
reset_nivel() {
    local num=$1

    if [[ ! $num =~ ^([0-9]|1[0-2])$ ]]; then
        error "Nivel inválido: $num (usa 0-12)"
        return 2
    fi

    local fn
    fn=$(funcion_leccion "$num")
    if ! declare -F "$fn" >/dev/null 2>&1; then
        printf '%s\n' "Aviso: el nivel $num todavía no está implementado; el reinicio no tendrá efecto."
    fi

    explicar_reset nivel "$num"

    if ! confirmar_reset "¿Reiniciar el nivel ${num}? (s/N)"; then
        printf '\n%s\n' "Cancelado: no se ha tocado nada."
        return 1
    fi

    local resueltos completado descuento
    resueltos=$(contar_prefijo "$EST_RETOS" "$num.")
    completado=0
    lista_contiene "$EST_COMPLETADAS" "$num" && completado=1
    descuento=$(( completado * 20 + resueltos * 10 ))

    EST_COMPLETADAS=$(quitar_lista "$EST_COMPLETADAS" "$num")
    EST_RETOS=$(quitar_prefijo "$EST_RETOS" "$num.")
    EST_PENDIENTES=$(quitar_prefijo "$EST_PENDIENTES" "$num.")
    if [[ $EST_LECCION == "$num" ]]; then
        EST_LECCION=""
    fi
    EST_XP=$((EST_XP - descuento))
    (( EST_XP < 0 )) && EST_XP=0
    guardar_estado

    printf '\n%s\n' "Nivel ${num} reiniciado."
    printf '  · %s retos vuelven a empezar\n' "$resueltos"
    printf '  · %s XP descontados (quedan %s XP · %s)\n' "$descuento" "$EST_XP" "$(rango_actual)"
    return 0
}

# Reinicio total: borra el estado y los scripts de prácticas.
reset_total() {
    if [[ -z $DIR_PRACTICAS || $DIR_PRACTICAS == "/" || $DIR_PRACTICAS == "$HOME" ]]; then
        error "directorio de prácticas no seguro: ${DIR_PRACTICAS}"
        return 2
    fi

    explicar_reset total

    if ! confirmar_reset "¿Borrar el progreso y tus scripts de prácticas? (s/N)"; then
        printf '\n%s\n' "Cancelado: no se ha tocado nada."
        return 1
    fi

    rm -f "$ARCH_ESTADO"
    local borrados
    borrados=$(borrar_contenido "$DIR_PRACTICAS")

    printf '\n%s\n' "Todo borrado: progreso y scripts de prácticas."
    printf '  · %s archivos eliminados de %s\n' "$borrados" "$DIR_PRACTICAS"
    printf '  · empiezas de cero: nivel 0, 0 XP\n'
    return 0
}

# ==================================================================== CLI =====

mostrar_lista() {
    local n fn estado
    printf 'bash4u %s · niveles\n\n' "$VERSION"
    for (( n = 0; n <= 12; n++ )); do
        fn=$(funcion_leccion "$n")
        if ! declare -F "$fn" >/dev/null 2>&1; then
            estado="en construcción"
        elif lista_contiene "$EST_COMPLETADAS" "$n"; then
            estado="superado"
        else
            estado="disponible"
        fi
        printf '  %2d  %-42s %s\n' "$n" "${TITULOS[$n]}" "$estado"
    done
}

mostrar_soluciones() {
    local num=$1 nombre
    nombre=$(printf 'RETOS_%02d' "$num")
    if ! declare -p "$nombre" >/dev/null 2>&1; then
        error "No hay retos para el nivel $num"
        return 1
    fi
    local -n retos="$nombre"
    local r
    for r in "${retos[@]}"; do
        "$r"
        printf '\n%s\n%s\n' "$R_ID" "$R_SOLUCION"
    done
    unset -n retos
}

ayuda() {
    cat <<EOF
bash4u ${VERSION} — curso interactivo de Bash scripting

Uso:
  bash bash4u.sh                 empezar o continuar
  bash bash4u.sh --lista         estado de los niveles
  bash bash4u.sh --leccion N     jugar un nivel concreto
  bash bash4u.sh --solucion N    ver las soluciones de un nivel
  bash bash4u.sh --self-test     verificar el propio curso
  bash bash4u.sh --stage N       previsualizar una etapa (0-5)
  bash bash4u.sh --reset-progress borrar el progreso (conserva tus scripts)
  bash bash4u.sh --reset-nivel N reiniciar un solo nivel
  bash bash4u.sh --reset-all     borrar el progreso y los scripts de prácticas
  bash bash4u.sh --plano         sin colores ni pantalla completa
  bash bash4u.sh --rapido        sin animaciones
  bash bash4u.sh --si            no pedir confirmación (para scripts)
  bash bash4u.sh --help          esta ayuda

Dentro de una lección:
  Enter      avanzar
  :atras     volver a la pantalla o parte anterior
  :inicio    empezar la lección desde el principio
  :salir     volver al menú sin cerrar el programa
  Ctrl+C     salir del programa (emergencia)

Reinicios:
  --reset-progress  borra el estado y empieza de cero; tus scripts se quedan
  --reset-nivel N   pone a cero el nivel N (retos, XP y estado de «superado»)
  --reset-all       borra además los scripts de la carpeta de prácticas
  Todos explican antes qué van a borrar y piden confirmación.

Progreso: ${ARCH_ESTADO}
Prácticas: ${DIR_PRACTICAS}
EOF
}

main() {
    local accion="" arg=""

    while (( $# )); do
        case $1 in
            --leccion|--lesson|-l)
                accion=leccion; arg=${2:-}; shift 2 || shift ;;
            --lista|--list)
                accion=lista; shift ;;
            --self-test)
                accion=selftest; shift ;;
            --reset|--reset-progress)
                accion=reset; shift ;;
            --reset-nivel|--reset-level)
                accion=reset_nivel; arg=${2:-}; shift 2 || shift ;;
            --reset-all|--reset-todo)
                accion=reset_all; shift ;;
            --si|--force|-f|-y)
                FORZAR=1; shift ;;
            --stage)
                accion=stage; arg=${2:-}; shift 2 || shift ;;
            --solucion|--solution)
                accion=solucion; arg=${2:-}; shift 2 || shift ;;
            --plano)
                MODO_PLANO=1; shift ;;
            --rapido)
                MODO_RAPIDO=1; shift ;;
            --ayuda|--help|-h)
                accion=ayuda; shift ;;
            --version)
                printf 'bash4u %s\n' "$VERSION"; return 0 ;;
            *)
                error "opción desconocida: $1"
                ayuda
                return 2 ;;
        esac
    done

    mkdir -p "$DIR_DATOS" "$DIR_PRACTICAS" 2>/dev/null
    cargar_estado
    configurar_colores

    case $accion in
        reset)       reset_progreso; return $? ;;
        reset_nivel) reset_nivel "$arg"; return $? ;;
        reset_all)   reset_total; return $? ;;
    esac

    if [[ $accion == stage ]]; then
        if [[ ! $arg =~ ^[0-5]$ ]]; then
            error "etapa inválida: $arg (usa 0-5)"
            return 2
        fi
        CAPS_OVERRIDE=$(caps_etapa "$arg")
        CAPS_OVERRIDE_ACTIVO=1
        configurar_colores
    fi

    case $accion in
        selftest) self_test; return $? ;;
        lista)    mostrar_lista; return 0 ;;
        ayuda)    ayuda; return 0 ;;
        leccion)  configurar_terminal; ejecutar_leccion "$arg"; return $? ;;
        solucion) mostrar_soluciones "$arg"; return $? ;;
    esac

    configurar_terminal
    if tiene_cap menu; then
        menu_principal
    else
        modo_lineal
    fi
}

if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3) )); then
    error "se requiere Bash 4.3 o superior"
    exit 1
fi

main "$@"
