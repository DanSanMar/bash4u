# bash4u

Curso interactivo de Bash scripting **de cero a experto**, con formato de videojuego:
pantallas, XP, desbloqueos y retos que se validan solos.

> **Estado:** en construcción. Fase 1 (motor) en desarrollo; los niveles 2 y 4 son los
> primeros pilotos jugables.

## Requisitos

- Bash 4 o superior (Linux, macOS o WSL).
- Nada más: el curso no instala dependencias.

## Uso

```bash
bash bash4u.sh              # empezar o continuar
bash bash4u.sh --lista      # ver el estado de los niveles
bash bash4u.sh --leccion 2  # ir directo a un nivel
bash bash4u.sh --self-test  # verificar que el propio curso funciona
```

Opciones útiles: `--plano` (sin colores ni pantalla completa), `--rapido` (sin animaciones),
`--stage N` (previsualizar una etapa de la interfaz) y `--reset-progress`.

## Cómo funciona

Cada nivel enseña un concepto, lo demuestra con código real y propone retos. El alumno
escribe su solución dentro del propio script (termina con `# fin`) y el curso la ejecuta
en un directorio temporal con `timeout`, comparando la salida y el código de salida.

Al superar ciertos niveles se desbloquean mejoras de la interfaz: colores, menú, editor,
fzf y estadísticas. El script no se modifica a sí mismo: el progreso guardado decide qué
etapa se muestra.

## Estructura

```
bash4u.sh      # motor + niveles + anexos
borradores/    # primeros borradores, conservados como referencia
```

## Licencia

MIT. Ver [LICENSE](LICENSE).
