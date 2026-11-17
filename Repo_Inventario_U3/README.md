# Tienda de videojuegos: ventas e inventario (MASM x86 + Irvine32)

**Alumno:** Ernie Osuna Soto · **Materia:** Lenguajes de Interfaz · **Horario:** 8:00 – 9:00
**Instituto Tecnológico de Culiacán** · Ingeniería en Sistemas Computacionales

Sistema de ventas e inventario en ensamblador MASM x86 de 32 bits con la biblioteca Irvine32.
Esta es la **versión de la Unidad 3**: el proyecto de la Unidad 2 reorganizado con **procedimientos, macros y USES**. Conserva las mismas funciones, validaciones y la regla del negocio (alerta de existencia mínima).

## Funciones

| Opción | Función | Qué hace |
|---|---|---|
| 1 | Registrar y consultar | Submenú: registrar, mostrar inventario o buscar por código |
| 2 | Recibir mercancía | Suma unidades a un producto sin pasar de 100 |
| 3 | Vender | Descuenta unidades, calcula el importe y acumula los ingresos |
| 4 | Mostrar resumen | Unidades, valor del inventario e ingresos de la sesión |
| 5 | Guardar y cargar | Guarda o recupera el catálogo en `inventario.txt` |
| 6 | Regla del negocio | Muestra los productos con menos de 5 unidades |
| 0 | Salir | Avisa si hay cambios sin guardar |

## Contenido del repositorio

```
├── ProyectoInventario/          Proyecto de Visual Studio
│   ├── *.sln / *.vcxproj        Solución y proyecto
│   ├── main.asm                 Código fuente (versión Unidad 3)
│   └── inventario.txt           Inventario de prueba (4 productos)
├── version_U2/
│   └── original_U2.asm          Versión de la Unidad 2, para comparar
├── docs/
│   ├── Proyecto_Unidad_3.docx   Reporte actualizado con la tabla de pruebas
│   └── CAMBIOS_U3.md            Procedimientos, macros, USES y comparación de líneas
└── README.md
```

## Requisitos

- **Visual Studio 2022** (o 2019) con la carga de trabajo **Desarrollo para el escritorio con C++**, que incluye MASM.
- **Biblioteca Irvine32** de Kip Irvine, instalada en `C:\Irvine`.

## Instrucciones de compilación

### Opción A: abrir la solución incluida

1. Clonar o descargar el repositorio.
2. Abrir el archivo `.sln` de la carpeta `ProyectoInventario` con Visual Studio.
3. En la barra superior, elegir **Debug** y **x86**. Irvine32 es de 32 bits, así que no funciona en x64.
4. Compilar con **Compilar → Compilar solución** (Ctrl + Shift + B).
5. Ejecutar con **Depurar → Iniciar sin depurar** (Ctrl + F5).

Si Irvine32 está en otra carpeta, cambia `C:\Irvine` por esa ruta en los pasos 4 y 5 de la opción B.

### Opción B: crear el proyecto desde cero

1. Crear un **Proyecto vacío** de C++ y agregarle `main.asm`.
2. Clic derecho en el proyecto → **Dependencias de compilación → Personalizaciones de compilación** → marcar **masm**.
3. En **Propiedades** del proyecto, con la configuración **Todas las configuraciones** y la plataforma **Win32**:
4. **Microsoft Macro Assembler → General → Include Paths:** `C:\Irvine`
5. **Vinculador → General → Directorios de bibliotecas adicionales:** `C:\Irvine`
6. **Vinculador → Entrada → Dependencias adicionales:** agregar `irvine32.lib;`
7. **Vinculador → Sistema → Subsistema:** `Consola (/SUBSYSTEM:CONSOLE)`
8. Compilar en **x86** y ejecutar con Ctrl + F5.

## Archivo de inventario de prueba

`ProyectoInventario/inventario.txt` tiene una línea por producto con este formato:

```
CODIGO|NOMBRE|PRECIO_EN_CENTAVOS|EXISTENCIA
```

Trae el catálogo como quedó al terminar las pruebas (4 productos):

```
ZEL-001|Zelda: TOTK|129999|28
MAR-002|Marvel Rivals|9950|4
POK-003|POKER: El Juego|24999|4
ABC-123|Halo Infinite|89950|20
```

Al ejecutar con Ctrl + F5, Visual Studio usa la carpeta del proyecto como directorio de trabajo, así que el programa busca `inventario.txt` ahí mismo. Para cargarlo, entra a la opción **5 → 2**.

### Repetir la tabla de pruebas desde el inicio

La tabla de pruebas del reporte empieza con estos 3 productos. Reemplaza el contenido de `inventario.txt` con esto antes de correrla:

```
ZEL-001|Zelda: TOTK|129999|20
MAR-002|Marvel Rivals|9950|10
POK-003|POKER: El Juego|24999|4
```

> **Nota:** la opción *Guardar* sobrescribe `inventario.txt`.

## Pruebas

La tabla de pruebas, con entrada, resultado esperado y capturas del resultado obtenido, está en el reporte `docs/Proyecto_Unidad_3.docx`.

Las pruebas se corren en el orden de la tabla partiendo del `inventario.txt` de prueba, porque el resumen depende de las ventas anteriores.
