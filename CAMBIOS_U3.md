# Sistema de ventas e inventario – Unidad 3 (Modularización)

**Alumno:** Ernie Osuna Soto · **Materia:** Lenguajes de Interfaz · **Horario:** 8:00 – 9:00
**Docente:** Dr. José Luis Medina Jiménez

Esta es la versión de la Unidad 2 (`original_U2.asm`) reorganizada con **procedimientos**, **macros** y **USES** (`main.asm`). Está hecha en MASM x86 de 32 bits con Irvine32.

Conserva lo mismo que el original:

- **Menús y funciones:** registrar, mostrar, buscar, recibir mercancía, vender, resumen, guardar y cargar `inventario.txt`, y salir con aviso de cambios sin guardar.
- **Validaciones:** código `ABC-123` sin repetir, nombre de 1 a 25 caracteres, precio de 0.01 a 9999.99 con 0, 1 o 2 decimales, existencia de 0 a 100, cantidad de 1 a 100, tope de 100 unidades, desbordamiento de importes, y archivo con formato inválido.
- **Mensajes:** son exactamente los mismos.
- **Regla del negocio:** alerta cuando un producto queda con menos de 5 unidades. Aparece después de una venta y en la opción 6.

---

## 1. Problema del código original

En la Unidad 2 todo estaba en `main`, unido con `JMP`. Para "regresar" a distintos puntos se usaban variables bandera:

- `accion`
- `regresoDinero` (1 = tabla, 2 = venta, 3 = valor, 4 = ingresos)
- `numeroMostrado`
- `retornoNumero`

Funcionaba como un `CALL`/`RET` hecho a mano. Para seguir el flujo había que revisar qué valor tenía cada bandera.

En la nueva versión, cada tarea es un procedimiento. `CALL` guarda la dirección de retorno y `RET` regresa solo, así que esas banderas desaparecieron. También se quitaron `direccionRegistro`, `cantidadVenta`, `registrosPendientes`, `centavosMostrados` y las constantes `ACCION_*`.

`main` quedó en unas 15 líneas y solo expresa la secuencia general del programa (diapositiva 8).

---

## 2. Procedimientos

En cada procedimiento, el código lleva un encabezado con **Recibe / Devuelve / Conserva (o Modifica)**.

Para los procedimientos que pueden fallar se usó una sola convención: devuelven **CF = 0 si todo salió bien y CF = 1 si hubo error**. El llamador revisa el resultado con `JC`/`JNC` (diapositiva 26).

| Procedimiento | Recibe | Devuelve | Qué reemplaza del original |
|---|---|---|---|
| `LeerOpcion` | EDX = menú, BL = opción máxima | AL = opción válida | La lectura y validación del menú, repetida en los 3 menús |
| `ConfirmarSalida` | – | CF = 1 si se queda | Bloque `salir` |
| `ParsearNumero` | ESI = texto, ECX = máx. dígitos | EAX = número, ECX = dígitos, ESI = siguiente carácter, CF | 6 ciclos casi iguales de "resultado × 10 + dígito" (precio, existencia, cantidad, carga de precio y de existencia) |
| `LeerEntero` | – | EAX, CF | Captura de existencia y de cantidad |
| `LeerPrecio` | – | EAX = centavos, CF | Conversión de "185.50" a centavos (ahora usa `ParsearNumero` dos veces) |
| `LeerCodigo` | – | CF | Validación del formato ABC-123 |
| `PedirCantidad` | – | EAX, CF | Captura de cantidad compartida por recibir y vender |
| `BuscarCodigo` | EDX = código | ESI = registro, CF = 1 si no existe | Búsqueda lineal en el catálogo |
| `PedirProductoExistente` | – | ESI, CF | Pedir código + validar + buscar + mensajes de error (buscar, recibir, vender) |
| `NumeroABuffer` | EAX = número, EDI = destino | EDI avanzado | Conversión de número a texto con la pila |
| `EscribirNumero` | EAX | – | El `convertirNumero` original, que estaba duplicado con `numeroAMemoria` |
| `EscribirDinero` | EAX = centavos | – | Formato `$PESOS.CC MXN` |
| `MostrarFila` / `MostrarTabla` | ESI, ECX, EBX = filtro | – | Tabla de inventario, búsqueda, venta y regla del negocio |
| `CopiarCampo` | ESI, EDI, ECX = máximo | ECX = copiados, ESI, CF | Lectura del código y del nombre desde el archivo |
| `RegistrarJuego`, `MostrarInventario`, `BuscarPorCodigo`, `RecibirMercancia`, `VenderJuego`, `MostrarResumen`, `ReglaAlertas`, `GuardarCatalogo`, `CargarCatalogo`, `MenuRegistrar`, `MenuArchivo` | – | – | Una opción del menú cada uno |

### Por qué se eligió un procedimiento en los cambios principales

- **`ParsearNumero`, `LeerPrecio`, `BuscarCodigo`, `EscribirDinero`:** son tareas largas con ciclos y se usan desde varios lugares. Como procedimiento, el código existe **una sola vez** en el programa ensamblado. Si fueran macros, MASM copiaría todas esas instrucciones en cada punto de uso.
- **`EscribirNumero` sobre `NumeroABuffer`:** el original tenía dos copias del algoritmo de "dividir entre 10 y usar la pila", una para la pantalla y otra para el archivo. Ahora solo hay una. `EscribirNumero` convierte el número a un buffer y lo muestra con `WriteString`.
- **`PedirProductoExistente`:** recibir, vender y buscar hacían la misma secuencia. Antes se distinguían con la bandera `accion`. Ahora los tres llaman al mismo procedimiento.

---

## 3. Macros

| Macro | Parámetros | Usos | Por qué macro |
|---|---|---|---|
| `mEscribir` | `mensaje` | 42 | Son 2 instrucciones (`mov edx, OFFSET` + `call WriteString`). Un procedimiento solo agregaría otro `CALL` y no ahorraría nada. |
| `mLeerCadena` | `buffer` | 6 | Son 3 instrucciones. Usa `SIZEOF buffer - 1` en vez del 79 fijo. |
| `mFueraDeRango` | `valor, minimo, maximo, destino` | 9 | Es el patrón `cmp/jb/cmp/ja` repetido. Necesita saltar a una **etiqueta del llamador**, y eso no se puede hacer desde un procedimiento. |
| `mDireccionRegistro` | `indice, base` | 2 | Son 3 instrucciones con parámetros (`catalogo` o `catalogoNuevo`). |
| `mAgregarByte` | `valor` | 5 | Son 2 instrucciones para escribir en el buffer del archivo (`'\|'`, `0Dh`, `0Ah`). |
| `mCopiarTexto` | `origen, destino` | 4 | Es un ciclo corto que copia hasta el 00h con los registros que se le indiquen. Tiene etiquetas internas, por eso usa **LOCAL**. |
| `mOpcion` | `caracter, procedimiento, regreso` | 11 | Es el `cmp al, x / jne / call / jmp menu` de los 3 menús. Usa **LOCAL** porque se expande 11 veces. |
| `mSalirSiVacio` | – | 4 | Revisa si el inventario está vacío y, si lo está, muestra el aviso y hace `RET`. Usa **LOCAL**. Tiene que ser macro porque el `RET` debe salir del procedimiento que la usa. |

Sin `LOCAL`, la segunda expansión de `mOpcion`, `mCopiarTexto` o `mSalirSiVacio` daría error de **símbolo redefinido**. Con `LOCAL`, MASM genera nombres únicos (`??0000`, `??0001`, …) en cada expansión.

---

## 4. USES y equilibrio de la pila

- Cada procedimiento declara en `USES` los registros que modifica y cuyo valor original debe conservarse. MASM genera los `PUSH` al inicio y los `POP` en orden inverso **antes de cada `RET`**, aunque el procedimiento tenga varias salidas.
- **Los registros de salida no van en USES:**
  - EAX en `LeerEntero`, `LeerPrecio`, `PedirCantidad`, `ParsearNumero` y `LeerOpcion`.
  - ESI en `BuscarCodigo` y `PedirProductoExistente`.
  - ECX y ESI en `ParsearNumero` y `CopiarCampo`.
  - EDI en `NumeroABuffer` y `CopiarCampo`.

  Si estuvieran en USES, el `POP` final borraría el resultado.
- CF sobrevive a USES porque `POP` y `RET` no modifican las banderas.
- La pila queda equilibrada en todos los procedimientos:
  - `NumeroABuffer` hace un `PUSH` por cada dígito y el mismo número de `POP`, controlado por ECX, antes de `RET`.
  - `EscribirDinero` hace `push eax` / `pop eax` alrededor de `WriteChar`.
  - Ningún procedimiento sale con datos temporales en la cima, así que `RET` siempre encuentra su dirección de retorno.

---

## 5. Comparación de líneas

**Criterio:** se cuentan las líneas de código fuente y se excluyen las líneas en blanco y las que son solo comentario. Las líneas con instrucción y comentario al lado cuentan. Se aplicó igual a los dos archivos.

| | Unidad 2 (`original_U2.asm`) | Unidad 3 (`main.asm`) | Diferencia |
|---|---|---|---|
| Líneas de código (todo el archivo) | 948 | 806 | −142 (−15 %) |
| Líneas de código de la sección `.code` | 850 | 671 | −179 (−21 %) |
| Líneas totales (con comentarios y blancos) | 1189 | 1255 | +66 |

El total de líneas sube porque cada procedimiento y cada macro lleva su documentación (Recibe / Devuelve / Conserva). El código como tal baja.

Las macros reducen la repetición **en el archivo .asm**, pero no en el ejecutable. MASM expande sus instrucciones en cada punto de uso; por ejemplo, las 42 llamadas a `mEscribir` generan 84 instrucciones. La reducción en el programa ensamblado viene de los procedimientos.

---

## 6. Pruebas

Correr el programa en Visual Studio y verificar que cada caso se comporte igual que la versión de la Unidad 2:

1. **Menús:** escribir `7`, `a` o `12` debe mostrar "Opción inválida" en los tres menús.
2. **Registrar:**
   - `abc-123`, `AB-1234` y un código repetido deben rechazarse.
   - Un nombre vacío o de 26 caracteres debe rechazarse.
   - Los precios `.50`, `12.`, `12.345`, `10000` y `0` deben rechazarse; `185`, `185.5` y `185.50` deben aceptarse.
   - Una existencia de `101` debe rechazarse.
   - Con 10 productos registrados debe aparecer el aviso de catálogo lleno.
3. **Mostrar y buscar:** la tabla debe mostrar el formato `$185.50 MXN` y `$5.05 MXN`, y buscar un código que no existe debe dar el mensaje correspondiente.
4. **Recibir:** si la existencia más la cantidad pasa de 100, debe rechazarse y no cambiar nada.
5. **Vender:** pedir más de la existencia debe rechazarse. Si la venta deja menos de 5 unidades, debe aparecer la **ALERTA**.
6. **Resumen:** las unidades, el valor del inventario y los ingresos deben coincidir con las ventas hechas.
7. **Regla (opción 6):** solo deben listarse los productos con menos de 5 unidades; si no hay, debe aparecer "Ningún producto tiene existencia baja".
8. **Archivo:**
   - Guardar y luego cargar debe regresar el mismo catálogo.
   - Editar `inventario.txt` con un campo mal escrito debe dar "archivo dañado" sin cambiar el catálogo.
   - Si el archivo no existe, debe aparecer el mensaje correspondiente.
9. **Salir:** con cambios sin guardar debe preguntar `(S/N)`.
