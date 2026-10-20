#!/bin/bash
# bash4u.sh — curso interactivo de Bash scripting de cero a experto.
#
# Fase 1: motor (pantallas, estado, etapas, validación, XP) + niveles piloto 2 y 4.
# Todo el curso vive en este archivo; ver README.md para el uso.
#
# Convenciones internas:
#   - Textos y mensajes en español.
#   - Sin dependencias externas (solo bash 4.3+ y coreutils).
#   - Cada nivel declara demo_0N y RETOS_0N; cada reto define R_* con definir_reto.
#   - El estado se guarda en ${XDG_DATA_HOME:-$HOME/.local/share}/bash4u/estado.

set -uo pipefail

VERSION="0.1.1"
DIR_DATOS="${XDG_DATA_HOME:-$HOME/.local/share}/bash4u"
ARCH_ESTADO="$DIR_DATOS/estado"
DIR_PRACTICAS="${BASH4U_PRACTICAS:-$HOME/bash4u-practicas}"

# ---------------------------------------------------------------- opciones ---
MODO_PLANO=0
MODO_RAPIDO=0
AUTOTEST=0
CAPS_OVERRIDE=""
CAPS_OVERRIDE_ACTIVO=0

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
DETALLE_FALLO=""
STTY_ORIG=""

# =============================================================== utilidades ===

error() { printf '%s\n' "bash4u: $*" >&2; }

lista_contiene() {
    [[ ",${1:-}," == *",${2},"* ]]
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
    local -a partes=()
    IFS=',' read -ra partes <<< "$lista"
    for x in "${partes[@]}"; do
        [[ $x == "$item" ]] && continue
        salida=${salida:+$salida,}$x
    done
    printf '%s' "$salida"
}

contar_lista() {
    local lista=${1:-}
    [[ -z $lista ]] && { printf '0'; return 0; }
    local -a partes=()
    IFS=',' read -ra partes <<< "$lista"
    printf '%s' "${#partes[@]}"
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
    printf '%s' "${C_GRIS}(Enter para continuar)${C_RESET} "
    IFS= read -r _ || return 1
    return 0
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
    mapfile -t lineas <<< "$texto"
    local total=${#lineas[@]} i=0 por_pagina=18 fin

    if [[ $MODO_PLANO -eq 0 && -t 1 ]] && command -v tput >/dev/null 2>&1; then
        por_pagina=$(($(tput lines 2>/dev/null || printf '24') - 9))
    fi
    (( por_pagina < 6 )) && por_pagina=6

    while (( i < total )); do
        fin=$((i + por_pagina))
        (( fin > total )) && fin=$total
        printf '%s\n' "${lineas[@]:i:fin-i}"
        i=$fin
        if (( i < total )); then
            [[ $AUTOTEST -eq 1 ]] && continue
            printf '%s' "${C_GRIS}-- Más -- (Enter)${C_RESET} "
            IFS= read -r _ || return 1
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
            DETALLE_FALLO="Esperaba:
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
    shift 7
    R_CASOS=("$@")
}

bucle_reto() {
    local xp=${1:-10}
    local intentos=0 max=3
    local -a lineas=()
    local linea codigo limpia

    while (( intentos < max )); do
        lineas=()
        pantalla "Reto ${R_ID}" "${R_ENUNCIADO}

Escribe tu solución, una línea por vez.
Cuando termines, escribe una línea con solo:   # fin
Si te atascas: :pista   ·   Ver tu código: :ver   ·   Empezar de nuevo: :borrar" "Pista: ${R_PISTA}"

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
            printf '%s\n' "No escribiste nada."
            continue
        fi

        codigo=$(printf '%s\n' "${lineas[@]}")
        if [[ -n $R_ARCHIVO ]]; then
            while [[ $codigo == $'\n'* ]]; do
                codigo=${codigo#$'\n'}
            done
        fi
        if ejecutar_codigo "$codigo"; then
            printf '%s\n' "${C_OK}✔ Correcto. +${xp} XP${C_RESET}"
            if [[ -n $R_ARCHIVO ]]; then
                if mkdir -p "$DIR_PRACTICAS" 2>/dev/null \
                    && printf '%s\n' "$codigo" > "$DIR_PRACTICAS/$R_ARCHIVO"; then
                    printf '%s\n' "Guardado en ${DIR_PRACTICAS}/${R_ARCHIVO}"
                fi
            fi
            EST_RETOS=$(agregar_lista "$EST_RETOS" "$R_ID")
            EST_PENDIENTES=$(quitar_lista "$EST_PENDIENTES" "$R_ID")
            sumar_xp "$xp"
            return 0
        fi

        intentos=$((intentos + 1))
        printf '%s\n' "${C_ERR}✘ Todavía no.${C_RESET} ${DETALLE_FALLO}"
        if (( intentos < max )); then
            printf '%s\n' "Intento ${intentos} de ${max}. Usa :pista si te atascas."
        fi
    done

    EST_PENDIENTES=$(agregar_lista "$EST_PENDIENTES" "$R_ID")
    guardar_estado
    printf '%s\n' "Se agotaron los intentos. Solución de referencia:"
    printf '%s\n' "$R_SOLUCION"
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
    for r in "${retos[@]}"; do
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

demo_00() {
    local tmp
    tmp=$(mktemp -d) || return 0
    (
        cd "$tmp" || exit 0

        printf '%s\n' "→ pwd muestra el directorio actual:"
        pwd

        printf '%s\n' "→ creamos hola.sh con una redirección"
        printf '%s\n' '#!/bin/bash' 'echo "Hola, bash"' > hola.sh

        printf '%s\n' "→ contenido del archivo:"
        cat hola.sh

        printf '%s\n' "→ se ejecuta con bash:"
        bash hola.sh

        printf '%s\n' "→ bash -n comprueba la sintaxis sin ejecutar:"
        bash -n hola.sh && printf '%s\n' "sintaxis ok"

        chmod +x hola.sh
        printf '%s\n' "→ con permiso de ejecución también funciona así:"
        ./hola.sh
    )
    rm -rf "$tmp"
}

reto_00_1() {
    definir_reto \
        "0.1" \
        "Escribe el contenido de tu primer script.

El curso lo guardará como hola.sh y lo ejecutará con bash.
Debe imprimir exactamente:
Hola, bash" \
        "Un script empieza con la línea #!/bin/bash y usa echo para imprimir.
No tienes que crear el archivo: escribe solo su contenido." \
        '#!/bin/bash
echo "Hola, bash"' \
        'echo "Adiós"' \
        '' 5 \
        "|Hola, bash|0"
    R_ARCHIVO="hola.sh"
}

reto_00_2() {
    definir_reto \
        "0.2" \
        "Crea un archivo llamado saludo.txt cuyo contenido sea exactamente
esta línea:

Hola, bash

Usa una redirección. No imprimas nada por pantalla: el texto debe
quedar dentro del archivo." \
        "printf '%s\\n' \"Hola, bash\" > saludo.txt
El símbolo > envía la salida a un archivo en vez de a la pantalla." \
        'printf "%s\n" "Hola, bash" > saludo.txt' \
        'printf "%s\n" "Hola, bash" > saludo.txt.bak' \
        '' 5 \
        "||0"
    R_CHEQUEO='[[ -f saludo.txt ]] && [[ "$(cat saludo.txt)" == "Hola, bash" ]]'
}

RETOS_00=(reto_00_1 reto_00_2)

leccion_00() {
    pantalla "Nivel 0 · ${TITULOS[0]}" "" "Escribe tu solución al final de la teoría."
    paginar "La terminal es una conversación con el sistema: cada línea que escribes
es un comando, y bash es el programa que los interpreta.

• pwd                 muestra el directorio actual.
• ls                  lista el contenido.
• cd carpeta          cambia de directorio; cd .. sube uno.
• /home/arch/...      ruta absoluta; hola.sh es relativa al directorio actual.
• echo texto          imprime; printf es más predecible con formatos.
• cmd > archivo       redirige la salida y sobrescribe el archivo.
• cmd >> archivo      añade al final sin borrar lo anterior.

Un script es un archivo de texto con comandos. Su primera línea,
#!/bin/bash, indica qué intérprete debe usarlo.

Se ejecuta con:
  bash script.sh
y, si tiene permiso de ejecución (chmod +x), también con:
  ./script.sh

Antes de ejecutar conviene comprobar la sintaxis con bash -n script.sh." \
        || return 1

    demo_00
    pausa || return 1

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

demo_01() {
    local nombre="Ada" edad=36

    printf '%s\n' "→ asignación: sin espacios alrededor del ="
    printf 'nombre=%s edad=%s\n' "$nombre" "$edad"

    printf '%s\n' "→ las comillas dobles expanden; las simples no"
    printf 'dobles: hola %s\n' "$nombre"
    printf 'simples: hola $nombre\n'

    printf '%s\n' "→ las llaves separan la variable del texto"
    printf '%s\n' "${nombre}ismo"

    printf '%s\n' "→ aritmética entera con \$(( ))"
    printf 'edad + 4 = %s\n' "$((edad + 4))"

    printf '%s\n' "→ read -r lee una línea (aquí desde una cadena)"
    local leido
    read -r leido <<< "Linus"
    printf 'leído: %s\n' "$leido"
}

reto_01_1() {
    definir_reto \
        "1.1" \
        "Lee dos números, uno por línea, y calcula su suma y su producto.

Imprime exactamente:
suma: N
producto: M

Ejemplo: si la entrada es 3 y 4, la salida debe ser:
suma: 7
producto: 12" \
        "read -r a y read -r b; después \$((a + b)) y \$((a * b))." \
        'read -r a
read -r b
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
}

reto_01_2() {
    definir_reto \
        "1.2" \
        "Lee una frase que puede tener espacios al principio y varios espacios
seguidos. Imprime exactamente:
Frase: <frase>

Conserva los espacios tal cual. Ejemplo: si la entrada es
«  hola   mundo», la salida debe ser «Frase:   hola   mundo»." \
        "Usa IFS= read -r frase y rodea \$frase con comillas dobles." \
        'IFS= read -r frase
echo "Frase: $frase"' \
        'read frase
echo Frase: $frase' \
        '' 5 \
        "  hola   mundo|Frase:   hola   mundo|0"
}

RETOS_01=(reto_01_1 reto_01_2)

leccion_01() {
    pantalla "Nivel 1 · ${TITULOS[1]}" "" "Escribe tu solución al final de la teoría."
    paginar "Una variable guarda un valor con un nombre. En bash se asigna así:

  nombre=Ada          (sin espacios alrededor del =)

Para usar el valor se pone \$ delante:

  echo \"\$nombre\"      → Ada
  echo '\$nombre'      → \$nombre   (las comillas simples son literales)

Las comillas dobles expanden variables; las simples no. Rodea SIEMPRE
las variables con comillas dobles para no perder espacios:
  echo \"\$frase\"       conserva los espacios
  echo \$frase         los colapsa

Las llaves sirven para separar el nombre del texto que va detrás:
  echo \"\${nombre}ismo\"

La aritmética entera va entre \$(( )):
  edad=\$((2026 - 1990))

Y read -r lee una línea. IFS= read -r conserva los espacios al principio
y al final de la línea." \
        || return 1

    demo_01
    pausa || return 1

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
        "Lee un número por la entrada estándar.

Si está entre 1 y 10 (incluidos), imprime exactamente:
  ok
y termina con código 0.

En cualquier otro caso (mayor, cero, negativo o no numérico), imprime exactamente:
  fuera de rango
y termina con código 1." \
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
}

RETOS_02=(reto_02_1)

leccion_02() {
    pantalla "Nivel 2 · ${TITULOS[2]}" "" "Escribe tu solución al final de la teoría."
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

En el reto, ojo al detalle: la salida debe ser exactamente la pedida." \
        || return 1

    demo_02
    pausa || return 1

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
        "Imprime los números del 1 al 5, uno por línea, en orden ascendente." \
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
}

reto_04_2() {
    definir_reto \
        "4.2" \
        "Escribe un menú que se repita hasta que se elija la opción 3.

Debe imprimir estas tres líneas al principio de cada vuelta:
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
}

RETOS_04=(reto_04_1 reto_04_2)

leccion_04() {
    pantalla "Nivel 4 · ${TITULOS[4]}" "" "Escribe tu solución al final de la teoría."
    paginar "Los bucles repiten trabajo y case elige entre opciones.

• for x in lista; do ...; done        recorre elementos.
• for i in {1..5}; do ...; done       recorre un rango.
• while condicion; do ...; done       repite mientras sea cierta.
• until condicion; do ...; done       repite hasta que sea cierta.
• break / continue                    sale del bucle / salta a la siguiente vuelta.
• case \$x in patron) ... ;; esac      elige una rama, como un if múltiple.

Un menú es un while true que solo termina con break.
Cuidado: si la entrada se acaba (EOF), read falla y el bucle puede girar sin fin.
En un menú real, comprueba el resultado de read." \
        || return 1

    demo_04
    pausa || return 1

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
    IFS=',' read -ra ids <<< "$EST_PENDIENTES"

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

${C_GRIS}r) repaso adaptativo ($(contar_pendientes) pendientes)   c) chuletas   q) salir${C_RESET}" "Los niveles 2 y 4 son los pilotos de la Fase 1."

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

self_test() {
    local fallos=0 total=0
    printf 'bash4u %s · self-test\n\n' "$VERSION"

    total=$((total + 1))
    if bash -n "$0"; then ok "sintaxis (bash -n)"; else mal "sintaxis (bash -n)"; fallos=$((fallos + 1)); fi

    total=$((total + 1))
    if probar_etapas; then ok "etapas 0-5"; else mal "etapas 0-5"; fallos=$((fallos + 1)); fi

    local entrada num titulo fn demo retos_nombre
    for entrada in "${LECCIONES[@]}"; do
        IFS='|' read -r num titulo fn <<< "$entrada"
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
  bash bash4u.sh --reset-progress borrar el progreso
  bash bash4u.sh --plano         sin colores ni pantalla completa
  bash bash4u.sh --rapido        sin animaciones
  bash bash4u.sh --help          esta ayuda

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

    if [[ $accion == reset ]]; then
        rm -f "$ARCH_ESTADO"
        printf '%s\n' "Progreso borrado."
        return 0
    fi

    mkdir -p "$DIR_DATOS" "$DIR_PRACTICAS" 2>/dev/null
    cargar_estado

    if [[ $accion == stage ]]; then
        if [[ ! $arg =~ ^[0-5]$ ]]; then
            error "etapa inválida: $arg (usa 0-5)"
            return 2
        fi
        CAPS_OVERRIDE=$(caps_etapa "$arg")
        CAPS_OVERRIDE_ACTIVO=1
    fi

    configurar_colores

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
