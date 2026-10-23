# bash4u

Curso interactivo de Bash scripting **de cero a experto**, con formato de videojuego:
pantallas, XP, desbloqueos y retos que se validan solos.

> **Estado:** Fase 1 completada (motor) y pilotos jugables de los niveles 0, 1, 2, 3 y 4.
> El resto del temario está en construcción.
>
> El nivel 0 está pensado para empezar sin saber nada: terminal y carpetas, extensiones
> (`.sh` y `.txt`), comillas, redirecciones y tu primer script.

## Requisitos

- Bash 4 o superior (Linux, macOS o WSL).
- Nada más: el curso no instala dependencias.

## Uso

```bash
./bash4u.sh                   # empezar o continuar
./bash4u.sh --lista           # ver el estado de los niveles
./bash4u.sh --leccion 2       # empezar en un nivel
./bash4u.sh --solucion 2      # ver la solución de referencia
./bash4u.sh --self-test       # verificar que el propio curso funciona
./bash4u.sh --reset-nivel 2   # reiniciar el progreso de un nivel
```

También funciona con `bash bash4u.sh ...`. Opciones útiles: `--plano` (sin colores ni
pantalla completa), `--rapido` (sin animaciones) y `--stage N` (previsualizar una etapa de
la interfaz).

Al terminar un nivel con `--leccion`, el curso ofrece continuar con el siguiente. Si entras
sin opciones, el modo normal ya enlaza los niveles automáticamente.

## Atajos dentro de una lección

En cada pausa y al final de cada página puedes escribir:

| Atajo | Qué hace |
|---|---|
| `Enter` | avanzar |
| `:atras` | volver a la página o parte anterior |
| `:inicio` | empezar la lección desde el principio |
| `:salir` | volver al menú sin cerrar el programa |
| `Ctrl+C` | salir del programa (solo como emergencia) |

Con `:atras` puedes repasar la teoría y las demos sin perder el progreso. Los atajos
aparecen en la propia línea de la pausa.

## Reiniciar el progreso

El progreso del curso no vive dentro del script: vive en un archivo aparte, con líneas
`clave=valor`, en `${XDG_DATA_HOME:-$HOME/.local/share}/bash4u/estado`. Tus scripts se
guardan en otra carpeta: `${BASH4U_PRACTICAS:-$HOME/bash4u-practicas}`.

Hay tres reinicios, de menor a mayor fuerza. **Todos explican primero qué van a borrar y
después piden confirmación** (`s` para confirmar, cualquier otra cosa cancela):

| Comando | Qué borra | Qué conserva |
|---|---|---|
| `--reset-progress` | el estado (niveles, retos, XP, desbloqueos) | tus scripts de prácticas |
| `--reset-nivel N` | solo el nivel `N`: sus retos, su XP y su marca de «superado» | el resto de niveles, los desbloqueos y tus scripts |
| `--reset-all` | el estado **y** los archivos de tu carpeta de prácticas | nada (la carpeta se queda, vacía) |

```bash
./bash4u.sh --reset-progress      # empezar de cero, conservando tus scripts
./bash4u.sh --reset-nivel 2       # repetir solo el nivel 2 (y volver a sacar su XP)
./bash4u.sh --reset-all           # borrar también los scripts que escribiste
```

En un script o en una tubería no hay teclado: la confirmación se salta sola. Si quieres que
sea explícito, añade `--si`:

```bash
./bash4u.sh --reset-all --si
```

`--reset-nivel` funciona con cualquier nivel del 0 al 12, incluidos los que todavía no
están implementados (en ese caso avisa y no hace nada). Es el mecanismo que seguirá
funcionando cuando se añadan niveles nuevos: cada nivel guarda sus retos con su propio
identificador (`N.M`), así que reiniciar uno nunca toca los demás.

### Reiniciar en las pruebas

Para probar sin tocar tu progreso real, apunta las dos rutas a un directorio de usar y tirar:

```bash
export XDG_DATA_HOME=/tmp/opencode/xdg-b4u
export BASH4U_PRACTICAS=/tmp/opencode/prac-b4u

./bash4u.sh --reset-all --si   # deja el entorno de pruebas como nuevo
./bash4u.sh --self-test        # el self-test no escribe estado ni abre la interfaz
```

## Cómo funciona

Cada nivel enseña un concepto, lo demuestra con código real y propone retos. El alumno
escribe su solución dentro del propio script (termina con `# fin`) y el curso la ejecuta
en un directorio temporal con `timeout`, comparando la salida y el código de salida.

En los retos no se teclea la entrada: el curso la pasa automáticamente al probar el
código. Por eso `read -p` no muestra su mensaje durante la corrección (la entrada llega
por una tubería); en las demos sí se ve, porque hay teclado.

Al superar ciertos niveles se desbloquean mejoras de la interfaz: nivel 2 → colores;
nivel 4 → menú; nivel 8 → estadísticas. El script no se modifica a sí mismo: el progreso
guardado decide qué etapa se muestra.

## Estructura

```
bash4u.sh      # motor + niveles + anexos
borradores/    # primeros borradores, conservados como referencia
```

## Licencia

MIT. Ver [LICENSE](LICENSE).
