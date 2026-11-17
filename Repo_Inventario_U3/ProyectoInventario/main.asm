;NOMBRE: ERNIE OSUNA SOTO
;MATERIA: LENGUAJES DE INTERFAZ
;HORARIO: 8:00 - 9:00
;DOCENTE: DR. JOSE LUIS MEDINA JIMENEZ
;PRACTICA: UNIDAD 3. SISTEMA DE VENTAS E INVENTARIO (MODULARIZADO)

; Version de la Unidad 2 reorganizada con procedimientos, macros y USES.
; Conserva las mismas funciones, validaciones y la regla del negocio
; (alerta de existencia minima).
;
; Convencion usada en los procedimientos:
;   - El resultado numerico se entrega en EAX (por eso EAX no va en USES
;     cuando es salida).
;   - Los procedimientos que pueden fallar avisan con CF:
;     CF = 0 -> todo bien, CF = 1 -> dato invalido o no encontrado.
;     (POP y RET no cambian CF, asi que USES no altera el estado.)

INCLUDE Irvine32.inc

; ---------- Constantes ----------
MAX_PRODUCTOS   = 10
TAM_REGISTRO    = 44                ; 8 codigo + 28 nombre + 4 precio + 4 existencia
OFF_NOMBRE      = 8
OFF_PRECIO      = 36
OFF_EXISTENCIA  = 40

; Regla del negocio: alerta de existencia minima.
MIN_EXISTENCIA   = 5

; Archivo inventario.txt:
TAM_BUFFER_ARCHIVO = 512            ; espacio para el texto del archivo

; ======================================================================
; MACROS
; ======================================================================

;------------------------------------------------
; mEscribir: muestra una cadena terminada en 00h
; Parametro: mensaje = etiqueta de la cadena
; Modifica: EDX
;------------------------------------------------
mEscribir MACRO mensaje
    mov edx, OFFSET mensaje
    call WriteString
ENDM

;------------------------------------------------
; mLeerCadena: lee una linea del teclado en un buffer
; Parametro: buffer = etiqueta del buffer (deja 1 byte para el 00h)
; Devuelve: EAX = caracteres escritos
; Modifica: EAX, ECX, EDX
;------------------------------------------------
mLeerCadena MACRO buffer
    mov edx, OFFSET buffer
    mov ecx, SIZEOF buffer - 1
    call ReadString
ENDM

;------------------------------------------------
; mFueraDeRango: salta a destino si valor < minimo o valor > maximo
; Parametros: valor (registro o memoria), minimo, maximo, destino (etiqueta)
; Comparacion sin signo (JB / JA)
;------------------------------------------------
mFueraDeRango MACRO valor, minimo, maximo, destino
    cmp valor, minimo
    jb destino
    cmp valor, maximo
    ja destino
ENDM

;------------------------------------------------
; mDireccionRegistro: calcula la direccion de un registro
; Parametros: indice (numero de registro), base (arreglo de registros)
; Devuelve: EAX = base + indice * TAM_REGISTRO
;------------------------------------------------
mDireccionRegistro MACRO indice, base
    mov eax, indice
    imul eax, eax, TAM_REGISTRO
    add eax, OFFSET base
ENDM

;------------------------------------------------
; mAgregarByte: escribe un byte en [EDI] y avanza EDI
; Parametro: valor = caracter o byte a escribir
;------------------------------------------------
mAgregarByte MACRO valor
    mov BYTE PTR [edi], valor
    inc edi
ENDM

;------------------------------------------------
; mCopiarTexto: copia caracteres de [origen] a [destino] hasta el 00h
; (el 00h no se copia). Al terminar, origen apunta al 00h y destino
; a la posicion siguiente al ultimo caracter copiado.
; Parametros: origen, destino (registros)
; Modifica: AL, origen, destino
; LOCAL: se usa en varios puntos, cada expansion tiene sus etiquetas
;------------------------------------------------
mCopiarTexto MACRO origen, destino
    LOCAL ciclo, fin
ciclo:
    mov al, [origen]
    cmp al, 0
    je fin
    mov [destino], al
    inc origen
    inc destino
    jmp ciclo
fin:
ENDM

;------------------------------------------------
; mOpcion: si AL = caracter, llama al procedimiento y salta a regreso
; Parametros: caracter, procedimiento, regreso (etiqueta del menu)
; LOCAL: se usa 11 veces, cada expansion necesita su propia etiqueta
;------------------------------------------------
mOpcion MACRO caracter, procedimiento, regreso
    LOCAL siguiente
    cmp al, caracter
    jne siguiente
    call procedimiento
    jmp regreso
siguiente:
ENDM

;------------------------------------------------
; mSalirSiVacio: si no hay productos muestra el aviso y regresa (RET)
; Solo se usa dentro de un procedimiento.
; Modifica: EDX (si el inventario esta vacio)
;------------------------------------------------
mSalirSiVacio MACRO
    LOCAL hayProductos
    cmp numProductos, 0
    jne hayProductos
    mEscribir msgInventarioVacio
    ret
hayProductos:
ENDM

.data
    ; ---------- Catalogo ----------
    catalogo            BYTE MAX_PRODUCTOS * TAM_REGISTRO DUP(0)
    numProductos        DWORD 0
    cambiosSinGuardar   DWORD 0     ; 1 si hay cambios que no se han guardado

    ; ---------- Ventas ----------
    importeVenta        DWORD 0     ; total de la venta en centavos
    ingresosSesion      DWORD 0     ; dinero vendido en esta sesion, en centavos

    ; ---------- Resumen ----------
    unidadesTotales     DWORD 0     ; suma de las existencias de todos los productos
    valorInventario     DWORD 0     ; suma de precio * existencia, en centavos

    ; ---------- Archivo ----------
    nombreArchivo       BYTE "inventario.txt", 0
    manejadorArchivo    DWORD 0     ; handle que devuelve CreateOutputFile u OpenInputFile
    bytesPedidos        DWORD 0     ; bytes que se quieren escribir
    bytesLeidos         DWORD 0     ; bytes que realmente se leyeron
    conteoNuevo         DWORD 0     ; productos leidos del archivo hasta ahora
    bufferArchivo       BYTE TAM_BUFFER_ARCHIVO DUP(0)   ; texto del archivo
    catalogoNuevo       BYTE MAX_PRODUCTOS * TAM_REGISTRO DUP(0)  ; aqui se arma lo leido

    textoIngresado      BYTE 80 DUP(0)  ; lo que escribe el usuario
    textoNumero         BYTE 12 DUP(0)  ; un numero convertido a texto

    ; ---------- Menus ----------
    msgTitulo       BYTE "= TIENDA DE VIDEOJUEGOS: VENTAS E INVENTARIO =", 0Ah, 0

    msgMenuPrincipal BYTE 0Ah
                     BYTE "1. Registrar y consultar", 0Ah
                     BYTE "2. Recibir mercancia", 0Ah
                     BYTE "3. Vender", 0Ah
                     BYTE "4. Mostrar resumen", 0Ah
                     BYTE "5. Guardar y cargar", 0Ah
                     BYTE "6. Regla del negocio (alerta de existencia minima)", 0Ah
                     BYTE "0. Salir", 0Ah
                     BYTE "Elige una opcion (0-6): ", 0

    msgMenuRegistrar BYTE 0Ah
                     BYTE "- REGISTRAR Y CONSULTAR -", 0Ah
                     BYTE "1. Registrar videojuego", 0Ah
                     BYTE "2. Mostrar inventario", 0Ah
                     BYTE "3. Buscar por codigo", 0Ah
                     BYTE "0. Volver", 0Ah
                     BYTE "Elige una opcion (0-3): ", 0

    msgMenuArchivo   BYTE 0Ah
                     BYTE "- GUARDAR Y CARGAR -", 0Ah
                     BYTE "1. Guardar catalogo", 0Ah
                     BYTE "2. Cargar catalogo", 0Ah
                     BYTE "0. Volver", 0Ah
                     BYTE "Elige una opcion (0-2): ", 0

    msgOpcionInvalida  BYTE "Opcion invalida.", 0Ah, 0
    msgDespedida       BYTE "Hasta luego.", 0Ah, 0

    ; ---------- Mensajes de registro y consulta ----------
    msgPedirCodigo      BYTE "Codigo (formato ABC-123): ", 0
    msgPedirNombre      BYTE "Nombre del videojuego (1 a 25 caracteres): ", 0
    msgPedirPrecio      BYTE "Precio en MXN (0.01 a 9999.99): ", 0
    msgPedirExistencia  BYTE "Existencia inicial (0 a 100): ", 0
    msgRegistroExitoso  BYTE "Videojuego registrado correctamente.", 0Ah, 0

    msgDatoInvalido     BYTE "Dato invalido.", 0Ah, 0
    msgCodigoRepetido   BYTE "Ese codigo ya esta registrado. No se agrego el videojuego.", 0Ah, 0
    msgCatalogoLleno    BYTE "No hay espacio: el catalogo ya tiene 10 videojuegos.", 0Ah, 0
    msgInventarioVacio  BYTE "El inventario esta vacio.", 0Ah, 0
    msgCodigoNoExiste   BYTE "No existe un videojuego con ese codigo.", 0Ah, 0

    msgEncabezadoTabla  BYTE "CODIGO | NOMBRE | PRECIO | EXISTENCIA", 0Ah, 0
    msgSeparador        BYTE " | ", 0
    msgMoneda           BYTE " MXN", 0

    ; ---------- Mensajes de recibir mercancia ----------
    msgPedirCantidad     BYTE "Cantidad (1 a 100): ", 0
    msgExcedeCapacidad   BYTE "La existencia no puede pasar de 100. No se recibio la mercancia.", 0Ah, 0
    msgMercanciaRecibida BYTE "Mercancia recibida. Producto actualizado:", 0Ah, 0

    ; ---------- Mensajes de venta ----------
    msgSinExistencia     BYTE "Existencia insuficiente. No se realizo la venta.", 0Ah, 0
    msgDesbordamiento    BYTE "El importe es demasiado grande. No se realizo la venta.", 0Ah, 0
    msgVentaRealizada    BYTE "Venta realizada. Total a cobrar: ", 0

    ; ---------- Mensajes del resumen ----------
    msgResumenTitulo     BYTE 0Ah, "--- RESUMEN ---", 0Ah, 0
    msgResumenUnidades   BYTE "Unidades en inventario: ", 0
    msgResumenValor      BYTE "Valor del inventario: ", 0
    msgResumenIngresos   BYTE "Ingresos de la sesion: ", 0

    ; ---------- Mensajes de la regla del negocio ----------
    msgAlertaTitulo      BYTE 0Ah, "Productos con existencia baja (menos de 5 unidades):", 0Ah, 0
    msgSinAlertas        BYTE "Ningun producto tiene existencia baja.", 0Ah, 0
    msgAlertaVenta       BYTE "ALERTA: existencia baja, quedan menos de 5 unidades.", 0Ah, 0

    ; ---------- Mensajes de archivo ----------
    msgGuardado          BYTE "Catalogo guardado en inventario.txt.", 0Ah, 0
    msgCargado           BYTE "Catalogo cargado correctamente.", 0Ah, 0
    msgErrorCrear        BYTE "No se pudo crear el archivo. No se guardo nada.", 0Ah, 0
    msgErrorEscribir     BYTE "No se escribieron todos los datos. Intenta guardar otra vez.", 0Ah, 0
    msgArchivoNoExiste   BYTE "No existe el archivo inventario.txt. El catalogo no cambio.", 0Ah, 0
    msgArchivoInvalido   BYTE "El archivo esta danado o tiene un formato incorrecto. El catalogo no cambio.", 0Ah, 0
    msgAvisoSalir        BYTE "Hay cambios sin guardar. Salir de todos modos? (S/N): ", 0

.code
; ======================================================================
; PROGRAMA PRINCIPAL: solo expresa la secuencia general (menu principal)
; ======================================================================
main PROC
    mEscribir msgTitulo

menuPrincipal:
    mov edx, OFFSET msgMenuPrincipal
    mov bl, '6'
    call LeerOpcion                 ; AL = opcion valida ('0' a '6')

    mOpcion '1', MenuRegistrar,    menuPrincipal
    mOpcion '2', RecibirMercancia, menuPrincipal
    mOpcion '3', VenderJuego,      menuPrincipal
    mOpcion '4', MostrarResumen,   menuPrincipal
    mOpcion '5', MenuArchivo,      menuPrincipal
    mOpcion '6', ReglaAlertas,     menuPrincipal

    ; Opcion 0: salir (si hay cambios sin guardar, pregunta)
    call ConfirmarSalida
    jc menuPrincipal                ; CF = 1: el usuario decidio quedarse

    mEscribir msgDespedida
    exit
main ENDP

; ======================================================================
; MENUS
; ======================================================================

;------------------------------------------------
; LeerOpcion
; Muestra un menu y lo repite hasta que se elige una opcion valida
; (un solo caracter entre '0' y el maximo).
; Recibe:   EDX = direccion del texto del menu
;           BL  = opcion maxima (por ejemplo '6')
; Devuelve: AL  = opcion elegida
; Conserva: EBX, ECX, EDX, ESI
;------------------------------------------------
LeerOpcion PROC USES ebx ecx edx esi
    mov esi, edx                    ; ESI guarda el menu (EDX se reutiliza)
loMostrar:
    mov edx, esi
    call WriteString
    mLeerCadena textoIngresado      ; EAX = caracteres escritos
    cmp eax, 1
    jne loInvalida                  ; debe ser exactamente 1 caracter
    mov al, textoIngresado
    mFueraDeRango al, '0', bl, loInvalida
    ret                             ; AL = opcion valida
loInvalida:
    mEscribir msgOpcionInvalida
    jmp loMostrar
LeerOpcion ENDP

;------------------------------------------------
; MenuRegistrar: submenu 1 (registrar y consultar)
; Recibe: nada.  Devuelve: nada.
; Conserva: EAX, EBX, EDX
;------------------------------------------------
MenuRegistrar PROC USES eax ebx edx
mrMostrar:
    mov edx, OFFSET msgMenuRegistrar
    mov bl, '3'
    call LeerOpcion

    mOpcion '1', RegistrarJuego,    mrMostrar
    mOpcion '2', MostrarInventario, mrMostrar
    mOpcion '3', BuscarPorCodigo,   mrMostrar
    ret                             ; opcion 0: volver al menu principal
MenuRegistrar ENDP

;------------------------------------------------
; MenuArchivo: submenu 5 (guardar y cargar)
; Recibe: nada.  Devuelve: nada.
; Conserva: EAX, EBX, EDX
;------------------------------------------------
MenuArchivo PROC USES eax ebx edx
maMostrar:
    mov edx, OFFSET msgMenuArchivo
    mov bl, '2'
    call LeerOpcion

    mOpcion '1', GuardarCatalogo, maMostrar
    mOpcion '2', CargarCatalogo,  maMostrar
    ret                             ; opcion 0: volver al menu principal
MenuArchivo ENDP

;------------------------------------------------
; ConfirmarSalida
; Si hay cambios sin guardar pregunta si de verdad quiere salir.
; Recibe:   nada
; Devuelve: CF = 0 -> salir, CF = 1 -> quedarse en el programa
; Conserva: EAX, ECX, EDX
;------------------------------------------------
ConfirmarSalida PROC USES eax ecx edx
    cmp cambiosSinGuardar, 0
    je csSalir                      ; no hay nada pendiente

    mEscribir msgAvisoSalir
    mLeerCadena textoIngresado
    cmp eax, 1
    jne csQuedarse                  ; respuesta distinta de un caracter: no sale
    mov al, textoIngresado
    cmp al, 'S'
    je csSalir
    cmp al, 's'
    je csSalir
csQuedarse:
    stc
    ret
csSalir:
    clc
    ret
ConfirmarSalida ENDP

; ======================================================================
; CAPTURA Y VALIDACION DE DATOS
; ======================================================================

;------------------------------------------------
; ParsearNumero
; Convierte los digitos que hay en [ESI] a un numero y se detiene en el
; primer caracter que no sea digito (el llamador revisa ese caracter).
; Recibe:   ESI = direccion del texto
;           ECX = maximo de digitos permitidos
; Devuelve: EAX = numero
;           ECX = digitos leidos
;           ESI = direccion del primer caracter que no es digito
;           CF  = 1 si hay mas digitos que el maximo
; Conserva: EBX, EDX
;------------------------------------------------
ParsearNumero PROC USES ebx edx
    mov edx, ecx                    ; EDX = maximo de digitos
    mov eax, 0                      ; EAX = resultado
    mov ecx, 0                      ; ECX = digitos leidos
pnDigito:
    movzx ebx, BYTE PTR [esi]
    cmp bl, '0'
    jb pnFin                        ; no es digito: termina
    cmp bl, '9'
    ja pnFin
    cmp ecx, edx
    jae pnError                     ; demasiados digitos
    sub bl, '0'
    imul eax, 10                    ; resultado = resultado * 10 + digito
    add eax, ebx
    inc ecx
    inc esi
    jmp pnDigito
pnFin:
    clc
    ret
pnError:
    stc
    ret
ParsearNumero ENDP

;------------------------------------------------
; LeerEntero
; Lee del teclado un entero de 1 a 3 digitos (solo digitos).
; El rango lo revisa quien llama.
; Recibe:   nada
; Devuelve: EAX = numero leido
;           CF  = 1 si esta vacio, tiene otro caracter o mas de 3 digitos
; Conserva: ECX, EDX, ESI
;------------------------------------------------
LeerEntero PROC USES ecx edx esi
    mLeerCadena textoIngresado
    mov esi, OFFSET textoIngresado
    mov ecx, 3
    call ParsearNumero              ; EAX = numero, ECX = digitos
    jc leInvalido
    cmp ecx, 0
    je leInvalido                   ; vacio
    cmp BYTE PTR [esi], 0
    jne leInvalido                  ; quedo un caracter que no es digito
    clc
    ret
leInvalido:
    stc
    ret
LeerEntero ENDP

;------------------------------------------------
; LeerPrecio
; Lee un precio "185", "185.5" o "185.50" y lo convierte a centavos.
; Recibe:   nada (el mensaje lo muestra quien llama)
; Devuelve: EAX = precio en centavos (1 a 999999)
;           CF  = 1 si el formato o el rango no son validos
; Conserva: EBX, ECX, EDX, ESI
;------------------------------------------------
LeerPrecio PROC USES ebx ecx edx esi
    mLeerCadena textoIngresado
    mov esi, OFFSET textoIngresado

    ; Parte entera: de 1 a 4 digitos
    mov ecx, 4
    call ParsearNumero
    jc lpInvalido                   ; mas de 4 digitos: pasa de $9999
    cmp ecx, 0
    je lpInvalido                   ; vacio o ".50" sin pesos
    mov ebx, eax
    imul ebx, 100                   ; EBX = pesos en centavos

    mov al, [esi]
    cmp al, 0
    je lpRango                      ; termino sin punto decimal
    cmp al, '.'
    jne lpInvalido                  ; simbolo, espacio o coma: rechazado

    ; Parte decimal: 1 o 2 digitos
    inc esi                         ; salta el punto
    mov ecx, 2
    call ParsearNumero
    jc lpInvalido                   ; tercer decimal: rechazado
    cmp ecx, 0
    je lpInvalido                   ; "12." sin decimales
    cmp BYTE PTR [esi], 0
    jne lpInvalido                  ; algo despues de los decimales
    cmp ecx, 2
    je lpSumar
    imul eax, 10                    ; un solo decimal son decenas de centavo
lpSumar:
    add ebx, eax

lpRango:
    mov eax, ebx
    mFueraDeRango eax, 1, 999999, lpInvalido
    clc
    ret
lpInvalido:
    stc
    ret
LeerPrecio ENDP

;------------------------------------------------
; LeerCodigo
; Pide un codigo y valida el formato ABC-123 (3 mayusculas, guion,
; 3 digitos y nada mas). El codigo queda en textoIngresado.
; Recibe:   nada
; Devuelve: CF = 1 si el formato no es valido
; Conserva: EAX, EBX, ECX, EDX, ESI
;------------------------------------------------
LeerCodigo PROC USES eax ebx ecx edx esi
    mEscribir msgPedirCodigo
    mLeerCadena textoIngresado

    mov esi, OFFSET textoIngresado
    mov ecx, 3
lcLetras:
    mov bl, [esi]
    mFueraDeRango bl, 'A', 'Z', lcInvalido
    inc esi
    loop lcLetras

    cmp BYTE PTR [esi], '-'
    jne lcInvalido
    inc esi

    mov ecx, 3
lcDigitos:
    mov bl, [esi]
    mFueraDeRango bl, '0', '9', lcInvalido
    inc esi
    loop lcDigitos

    cmp BYTE PTR [esi], 0
    jne lcInvalido                  ; despues del ultimo digito debe terminar
    clc
    ret
lcInvalido:
    stc
    ret
LeerCodigo ENDP

;------------------------------------------------
; PedirCantidad
; Pide una cantidad de 1 a 100. Si no es valida muestra "Dato invalido".
; Recibe:   nada
; Devuelve: EAX = cantidad
;           CF  = 1 si no es valida (el mensaje ya se mostro)
; Conserva: EDX
;------------------------------------------------
PedirCantidad PROC USES edx
    mEscribir msgPedirCantidad
    call LeerEntero
    jc pcInvalido
    mFueraDeRango eax, 1, 100, pcInvalido
    clc
    ret
pcInvalido:
    mEscribir msgDatoInvalido
    stc
    ret
PedirCantidad ENDP

; ======================================================================
; BUSQUEDA
; ======================================================================

;------------------------------------------------
; BuscarCodigo
; Busca un codigo de 7 caracteres en el catalogo.
; Recibe:   EDX = direccion del codigo a buscar
; Devuelve: ESI = direccion del registro encontrado
;           CF  = 1 si el codigo no existe
; Conserva: EAX, EBX, ECX
;------------------------------------------------
BuscarCodigo PROC USES eax ebx ecx
    mov esi, OFFSET catalogo        ; ESI = primer registro
    mov ecx, numProductos
    cmp ecx, 0
    je bcNoExiste                   ; catalogo vacio
bcRegistro:
    mov eax, 0                      ; EAX = posicion del caracter
bcComparar:
    mov bl, [esi + eax]
    cmp bl, [edx + eax]
    jne bcSiguiente
    inc eax
    cmp eax, 7
    jb bcComparar
    clc                             ; los 7 caracteres coinciden
    ret
bcSiguiente:
    add esi, TAM_REGISTRO           ; siguiente registro
    loop bcRegistro
bcNoExiste:
    stc
    ret
BuscarCodigo ENDP

;------------------------------------------------
; PedirProductoExistente
; Pide un codigo, valida su formato y lo busca en el catalogo.
; Si algo falla muestra el mensaje correspondiente.
; Recibe:   nada
; Devuelve: ESI = direccion del registro
;           CF  = 1 si el codigo es invalido o no existe
; Conserva: EDX
;------------------------------------------------
PedirProductoExistente PROC USES edx
    call LeerCodigo
    jc ppInvalido
    mov edx, OFFSET textoIngresado
    call BuscarCodigo               ; ESI = registro
    jc ppNoExiste
    clc
    ret
ppInvalido:
    mEscribir msgDatoInvalido
    stc
    ret
ppNoExiste:
    mEscribir msgCodigoNoExiste
    stc
    ret
PedirProductoExistente ENDP

; ======================================================================
; SALIDA EN PANTALLA
; ======================================================================

;------------------------------------------------
; NumeroABuffer
; Convierte un numero a texto y lo escribe en [EDI].
; Divide entre 10, guarda los residuos en la pila para invertir su
; orden y les suma '0' (ASCII) al sacarlos.
; Recibe:   EAX = numero
;           EDI = donde escribir
; Devuelve: EDI = posicion siguiente al ultimo digito
; Conserva: EAX, EBX, ECX, EDX
;------------------------------------------------
NumeroABuffer PROC USES eax ebx ecx edx
    mov ebx, 10
    mov ecx, 0                      ; ECX cuenta los digitos
naExtraer:
    mov edx, 0
    div ebx                         ; EDX = digito, EAX = lo que falta
    push edx
    inc ecx
    cmp eax, 0
    jne naExtraer
naEscribir:
    pop eax                         ; un POP por cada PUSH: la pila queda equilibrada
    add al, '0'
    mov [edi], al
    inc edi
    loop naEscribir
    ret
NumeroABuffer ENDP

;------------------------------------------------
; EscribirNumero
; Muestra un numero sin signo en pantalla.
; Recibe:   EAX = numero
; Devuelve: nada
; Conserva: EDX, EDI (y EAX, porque NumeroABuffer lo conserva)
;------------------------------------------------
EscribirNumero PROC USES edx edi
    mov edi, OFFSET textoNumero
    call NumeroABuffer
    mov BYTE PTR [edi], 0           ; 00h al final del texto
    mEscribir textoNumero
    ret
EscribirNumero ENDP

;------------------------------------------------
; EscribirDinero
; Muestra un importe en centavos como $PESOS.CC MXN
; Recibe:   EAX = importe en centavos
; Devuelve: nada
; Conserva: EAX, EBX, EDX
;------------------------------------------------
EscribirDinero PROC USES eax ebx edx
    push eax
    mov al, '$'
    call WriteChar
    pop eax

    mov edx, 0
    mov ebx, 100
    div ebx                         ; EAX = pesos, EDX = centavos
    call EscribirNumero

    mov al, '.'
    call WriteChar
    mov eax, edx
    mov edx, 0
    mov ebx, 10
    div ebx                         ; EAX = decenas, EDX = unidades
    add al, '0'
    call WriteChar
    mov al, dl
    add al, '0'
    call WriteChar                  ; siempre 2 digitos: 5 se ve como 05
    mEscribir msgMoneda
    ret
EscribirDinero ENDP

;------------------------------------------------
; MostrarFila
; Muestra un registro: CODIGO | NOMBRE | PRECIO | EXISTENCIA
; Recibe:   ESI = direccion del registro
; Devuelve: nada
; Conserva: EAX, EDX
;------------------------------------------------
MostrarFila PROC USES eax edx
    mov edx, esi                    ; el codigo esta al inicio del registro
    call WriteString
    mEscribir msgSeparador

    mov edx, esi                    ; el nombre esta 8 bytes despues
    add edx, OFF_NOMBRE
    call WriteString
    mEscribir msgSeparador

    mov eax, [esi + OFF_PRECIO]     ; precio en centavos
    call EscribirDinero
    mEscribir msgSeparador

    mov eax, [esi + OFF_EXISTENCIA]
    call EscribirNumero
    call Crlf
    ret
MostrarFila ENDP

;------------------------------------------------
; MostrarTabla
; Muestra el encabezado y una fila por registro.
; Recibe:   ESI = primer registro
;           ECX = cuantos registros recorrer
;           EBX = 0 -> todos, 1 -> solo existencia menor a MIN_EXISTENCIA
; Devuelve: nada
; Conserva: ECX, EDX, ESI
;------------------------------------------------
MostrarTabla PROC USES ecx edx esi
    mEscribir msgEncabezadoTabla
mtFila:
    cmp ebx, 1
    jne mtMostrar
    cmp DWORD PTR [esi + OFF_EXISTENCIA], MIN_EXISTENCIA
    jae mtSiguiente                 ; la regla solo muestra los de existencia baja
mtMostrar:
    call MostrarFila
mtSiguiente:
    add esi, TAM_REGISTRO           ; siguiente registro
    loop mtFila
    ret
MostrarTabla ENDP

; ======================================================================
; OPCIONES DEL SUBMENU 1: REGISTRAR Y CONSULTAR
; ======================================================================

;------------------------------------------------
; RegistrarJuego
; Pide codigo, nombre, precio y existencia. El producto solo cuenta
; (numProductos + 1) si TODOS los datos son validos.
; Recibe: nada.  Devuelve: nada.
; Conserva: EAX, EBX, ECX, EDX, ESI, EDI
;------------------------------------------------
RegistrarJuego PROC USES eax ebx ecx edx esi edi
    cmp numProductos, MAX_PRODUCTOS
    jb rjHayEspacio
    mEscribir msgCatalogoLleno
    ret
rjHayEspacio:
    mDireccionRegistro numProductos, catalogo
    mov ebx, eax                    ; EBX = registro libre

    ; ---------- Codigo: formato ABC-123 y no repetido ----------
    call LeerCodigo
    jc rjInvalido
    mov edx, OFFSET textoIngresado
    call BuscarCodigo
    jnc rjRepetido                  ; CF = 0: ya existe

    mov esi, OFFSET textoIngresado
    mov edi, ebx
    mCopiarTexto esi, edi
    mov BYTE PTR [edi], 0

    ; ---------- Nombre: de 1 a 25 caracteres ----------
    mEscribir msgPedirNombre
    mLeerCadena textoIngresado      ; EAX = longitud
    mFueraDeRango eax, 1, 25, rjInvalido
    mov esi, OFFSET textoIngresado
    mov edi, ebx
    add edi, OFF_NOMBRE             ; el nombre va 8 bytes despues
    mCopiarTexto esi, edi
    mov BYTE PTR [edi], 0

    ; ---------- Precio ----------
    mEscribir msgPedirPrecio
    call LeerPrecio                 ; EAX = centavos
    jc rjInvalido
    mov [ebx + OFF_PRECIO], eax

    ; ---------- Existencia: de 0 a 100 ----------
    mEscribir msgPedirExistencia
    call LeerEntero
    jc rjInvalido
    mFueraDeRango eax, 0, 100, rjInvalido
    mov [ebx + OFF_EXISTENCIA], eax

    ; ---------- Todo es valido: ahora si cuenta como producto ----------
    inc numProductos
    mov cambiosSinGuardar, 1
    mEscribir msgRegistroExitoso
    ret

rjRepetido:
    mEscribir msgCodigoRepetido
    ret
rjInvalido:
    mEscribir msgDatoInvalido
    ret
RegistrarJuego ENDP

;------------------------------------------------
; MostrarInventario: muestra todo el catalogo en tabla
; Recibe: nada.  Devuelve: nada.
; Conserva: EBX, ECX, EDX, ESI
;------------------------------------------------
MostrarInventario PROC USES ebx ecx edx esi
    mSalirSiVacio
    mov esi, OFFSET catalogo
    mov ecx, numProductos
    mov ebx, 0                      ; sin filtro
    call MostrarTabla
    ret
MostrarInventario ENDP

;------------------------------------------------
; BuscarPorCodigo: pide un codigo y muestra ese producto
; Recibe: nada.  Devuelve: nada.
; Conserva: EBX, ECX, ESI
;------------------------------------------------
BuscarPorCodigo PROC USES ebx ecx esi
    call PedirProductoExistente     ; ESI = registro
    jc bpFin
    mov ecx, 1
    mov ebx, 0
    call MostrarTabla
bpFin:
    ret
BuscarPorCodigo ENDP

; ======================================================================
; OPCIONES DEL MENU PRINCIPAL
; ======================================================================

;------------------------------------------------
; RecibirMercancia
; Suma la cantidad a la existencia solo si el total no pasa de 100.
; Recibe: nada.  Devuelve: nada.
; Conserva: EAX, EBX, ECX, EDX, ESI
;------------------------------------------------
RecibirMercancia PROC USES eax ebx ecx edx esi
    mSalirSiVacio
    call PedirProductoExistente     ; ESI = registro
    jc rmFin
    call PedirCantidad              ; EAX = cantidad
    jc rmFin

    add eax, [esi + OFF_EXISTENCIA] ; EAX = existencia actual + cantidad
    cmp eax, 100
    ja rmExcede                     ; pasaria de 100: no se recibe nada
    mov [esi + OFF_EXISTENCIA], eax
    mov cambiosSinGuardar, 1

    mEscribir msgMercanciaRecibida
    mov ecx, 1
    mov ebx, 0
    call MostrarTabla               ; muestra el producto actualizado
    ret
rmExcede:
    mEscribir msgExcedeCapacidad
rmFin:
    ret
RecibirMercancia ENDP

;------------------------------------------------
; VenderJuego
; Vende solo si hay existencia suficiente y el importe cabe en 32 bits.
; Despues de vender aplica la regla del negocio: si quedan menos de
; MIN_EXISTENCIA unidades muestra la alerta.
; Recibe: nada.  Devuelve: nada.
; Conserva: EAX, EBX, ECX, EDX, ESI
;------------------------------------------------
VenderJuego PROC USES eax ebx ecx edx esi
    mSalirSiVacio
    call PedirProductoExistente     ; ESI = registro
    jc vjFin
    call PedirCantidad              ; EAX = cantidad
    jc vjFin

    cmp eax, [esi + OFF_EXISTENCIA]
    ja vjSinExistencia              ; piden mas unidades de las que hay
    mov ebx, eax                    ; EBX = cantidad

    ; Importe = precio * cantidad (si EDX no es 0, no cabe en 32 bits)
    mov eax, [esi + OFF_PRECIO]
    mul ebx
    cmp edx, 0
    jne vjDesbordamiento
    mov importeVenta, eax

    ; Ingresos de la sesion + esta venta (CF = 1 si se desborda)
    mov eax, ingresosSesion
    add eax, importeVenta
    jc vjDesbordamiento

    ; ---------- Todo es valido: ahora si se modifican los datos ----------
    mov ingresosSesion, eax
    sub [esi + OFF_EXISTENCIA], ebx
    mov cambiosSinGuardar, 1

    mEscribir msgVentaRealizada
    mov eax, importeVenta
    call EscribirDinero
    call Crlf

    mov ecx, 1
    mov ebx, 0
    call MostrarTabla               ; producto con su nueva existencia

    ; Regla del negocio despues de la venta
    cmp DWORD PTR [esi + OFF_EXISTENCIA], MIN_EXISTENCIA
    jae vjFin
    mEscribir msgAlertaVenta
    ret

vjSinExistencia:
    mEscribir msgSinExistencia
    ret
vjDesbordamiento:
    mEscribir msgDesbordamiento
vjFin:
    ret
VenderJuego ENDP

;------------------------------------------------
; MostrarResumen
; Suma las unidades y el valor del inventario y muestra los ingresos.
; Recibe: nada.  Devuelve: nada.
; Conserva: EAX, EBX, ECX, EDX, ESI
;------------------------------------------------
MostrarResumen PROC USES eax ebx ecx edx esi
    mov unidadesTotales, 0
    mov valorInventario, 0
    mov esi, OFFSET catalogo        ; ESI = primer registro
    mov ecx, numProductos
    cmp ecx, 0
    je mrEscribir                   ; sin productos: todo queda en 0
mrCiclo:
    mov eax, [esi + OFF_EXISTENCIA]
    add unidadesTotales, eax
    mov ebx, [esi + OFF_PRECIO]
    mul ebx                         ; EDX:EAX = existencia * precio
    cmp edx, 0
    jne mrDesbordamiento
    add valorInventario, eax
    jc mrDesbordamiento             ; CF = 1: la suma no cabe en 32 bits
    add esi, TAM_REGISTRO           ; siguiente registro
    loop mrCiclo

mrEscribir:
    mEscribir msgResumenTitulo
    mEscribir msgResumenUnidades
    mov eax, unidadesTotales
    call EscribirNumero
    call Crlf

    mEscribir msgResumenValor
    mov eax, valorInventario
    call EscribirDinero
    call Crlf

    mEscribir msgResumenIngresos
    mov eax, ingresosSesion
    call EscribirDinero
    call Crlf
    ret

mrDesbordamiento:
    mEscribir msgDesbordamiento
    ret
MostrarResumen ENDP

;------------------------------------------------
; ReglaAlertas (regla del negocio)
; Cuenta los productos con menos de MIN_EXISTENCIA unidades; si hay
; alguno, muestra la tabla solo con esos.
; Recibe: nada.  Devuelve: nada.
; Conserva: EBX, ECX, EDX, ESI
;------------------------------------------------
ReglaAlertas PROC USES ebx ecx edx esi
    mSalirSiVacio
    mov esi, OFFSET catalogo
    mov ecx, numProductos
    mov ebx, 0                      ; EBX = productos en alerta
raContar:
    cmp DWORD PTR [esi + OFF_EXISTENCIA], MIN_EXISTENCIA
    jae raSiguiente
    inc ebx                         ; existencia menor al minimo
raSiguiente:
    add esi, TAM_REGISTRO
    loop raContar

    cmp ebx, 0
    jne raMostrar
    mEscribir msgSinAlertas         ; ninguno en alerta
    ret
raMostrar:
    mEscribir msgAlertaTitulo
    mov esi, OFFSET catalogo
    mov ecx, numProductos
    mov ebx, 1                      ; filtrar: solo existencia baja
    call MostrarTabla
    ret
ReglaAlertas ENDP

; ======================================================================
; ARCHIVO inventario.txt
; Formato de cada linea: CODIGO|NOMBRE|PRECIO_EN_CENTAVOS|EXISTENCIA
; ======================================================================

;------------------------------------------------
; GuardarCatalogo
; Arma el texto en bufferArchivo (ESI recorre los registros, EDI es
; donde se escribe) y luego lo escribe en el archivo de una sola vez.
; Recibe: nada.  Devuelve: nada.
; Conserva: EAX, ECX, EDX, ESI, EDI
;------------------------------------------------
GuardarCatalogo PROC USES eax ecx edx esi edi
    mov edi, OFFSET bufferArchivo
    mov esi, OFFSET catalogo
    mov ecx, numProductos
    cmp ecx, 0
    je gcEscribir                   ; sin productos: el archivo queda vacio

gcRegistro:
    mov edx, esi                    ; EDX = codigo
    mCopiarTexto edx, edi
    mAgregarByte '|'

    mov edx, esi
    add edx, OFF_NOMBRE             ; EDX = nombre
    mCopiarTexto edx, edi
    mAgregarByte '|'

    mov eax, [esi + OFF_PRECIO]
    call NumeroABuffer
    mAgregarByte '|'

    mov eax, [esi + OFF_EXISTENCIA]
    call NumeroABuffer
    mAgregarByte 0Dh                ; fin de linea de Windows
    mAgregarByte 0Ah

    add esi, TAM_REGISTRO           ; siguiente registro
    dec ecx                         ; (dec/jnz porque el ciclo es largo para LOOP)
    jnz gcRegistro

gcEscribir:
    mov eax, edi
    sub eax, OFFSET bufferArchivo
    mov bytesPedidos, eax           ; bytes de texto que se armaron

    mov edx, OFFSET nombreArchivo
    call CreateOutputFile           ; EAX = handle
    cmp eax, INVALID_HANDLE_VALUE
    je gcErrorCrear
    mov manejadorArchivo, eax

    mov edx, OFFSET bufferArchivo
    mov ecx, bytesPedidos
    call WriteToFile                ; EAX = bytes realmente escritos
    cmp eax, bytesPedidos
    jne gcFallo                     ; no se escribio todo

    mov eax, manejadorArchivo
    call CloseFile
    mov cambiosSinGuardar, 0
    mEscribir msgGuardado
    ret

gcFallo:
    mov eax, manejadorArchivo
    call CloseFile                  ; se cierra el archivo aunque haya fallado
    mEscribir msgErrorEscribir
    ret
gcErrorCrear:
    mEscribir msgErrorCrear
    ret
GuardarCatalogo ENDP

;------------------------------------------------
; CopiarCampo
; Copia un campo de texto del archivo hasta el '|'.
; Recibe:   ESI = inicio del campo
;           EDI = destino
;           ECX = maximo de caracteres
; Devuelve: ECX = caracteres copiados
;           ESI = posicion despues del '|'
;           CF  = 1 si hay fin de linea antes del '|' o es muy largo
; Modifica: EDI (queda en el 00h que se agrega al final)
; Conserva: EAX, EDX
;------------------------------------------------
CopiarCampo PROC USES eax edx
    mov edx, ecx                    ; EDX = maximo
    mov ecx, 0
ccCaracter:
    mov al, [esi]
    cmp al, '|'
    je ccFin
    cmp al, ' '
    jb ccError                      ; fin de linea o de texto antes de tiempo
    cmp ecx, edx
    jae ccError                     ; demasiado largo
    mov [edi], al
    inc edi
    inc esi
    inc ecx
    jmp ccCaracter
ccFin:
    mov BYTE PTR [edi], 0           ; 00h al final del campo
    inc esi                         ; salta el '|'
    clc
    ret
ccError:
    stc
    ret
CopiarCampo ENDP

;------------------------------------------------
; CargarCatalogo
; Lee el archivo y arma los registros en catalogoNuevo. Solo si TODAS
; las lineas son validas se copia al catalogo; si algo falla, el
; catalogo no cambia.
; Recibe: nada.  Devuelve: nada.
; Conserva: EAX, EBX, ECX, EDX, ESI, EDI
;------------------------------------------------
CargarCatalogo PROC USES eax ebx ecx edx esi edi
    mov edx, OFFSET nombreArchivo
    call OpenInputFile              ; EAX = handle
    cmp eax, INVALID_HANDLE_VALUE
    je caNoExiste
    mov manejadorArchivo, eax

    mov edx, OFFSET bufferArchivo
    mov ecx, TAM_BUFFER_ARCHIVO - 1 ; deja 1 byte para el 00h
    call ReadFromFile               ; EAX = bytes leidos, CF = 1 si hubo error
    mov bytesLeidos, eax            ; MOV no cambia CF
    jc caFalloLectura

    mov eax, manejadorArchivo
    call CloseFile
    mov esi, OFFSET bufferArchivo
    add esi, bytesLeidos
    mov BYTE PTR [esi], 0           ; 00h despues del ultimo byte leido

    cmp bytesLeidos, 480
    ja caInvalido                   ; mas grande que cualquier inventario valido

    mov conteoNuevo, 0
    mov esi, OFFSET bufferArchivo   ; ESI recorre el texto del archivo

    ; ---------- Una vuelta por linea ----------
caLinea:
    mov al, [esi]
    cmp al, 0
    je caCopiar                     ; fin del texto: todo salio bien
    cmp al, 0Dh
    je caSaltar                     ; las lineas en blanco se ignoran
    cmp al, 0Ah
    je caSaltar
    cmp conteoNuevo, MAX_PRODUCTOS
    jae caInvalido                  ; hay mas de 10 productos

    mDireccionRegistro conteoNuevo, catalogoNuevo
    mov ebx, eax                    ; EBX = registro nuevo

    ; Codigo: exactamente 7 caracteres antes del |
    mov edi, ebx
    mov ecx, 7
    call CopiarCampo
    jc caInvalido
    cmp ecx, 7
    jne caInvalido

    ; Nombre: de 1 a 25 caracteres antes del |
    mov edi, ebx
    add edi, OFF_NOMBRE
    mov ecx, 25
    call CopiarCampo
    jc caInvalido
    cmp ecx, 1
    jb caInvalido

    ; Precio: solo digitos (centavos), de 1 a 999999, termina en |
    mov ecx, 6
    call ParsearNumero
    jc caInvalido
    cmp ecx, 0
    je caInvalido
    cmp BYTE PTR [esi], '|'
    jne caInvalido
    mFueraDeRango eax, 1, 999999, caInvalido
    mov [ebx + OFF_PRECIO], eax
    inc esi                         ; salta el '|'

    ; Existencia: solo digitos, de 0 a 100, hasta el fin de la linea
    mov ecx, 3
    call ParsearNumero
    jc caInvalido
    cmp ecx, 0
    je caInvalido
    mov dl, [esi]
    cmp dl, 0Dh
    je caExistenciaOk
    cmp dl, 0Ah
    je caExistenciaOk
    cmp dl, 0
    jne caInvalido
caExistenciaOk:
    mFueraDeRango eax, 0, 100, caInvalido
    mov [ebx + OFF_EXISTENCIA], eax
    inc conteoNuevo                 ; esta linea ya es un producto del catalogo nuevo
    jmp caLinea

caSaltar:
    inc esi
    jmp caLinea

    ; ---------- Todo es valido: ahora si reemplaza el catalogo ----------
caCopiar:
    mov esi, OFFSET catalogoNuevo
    mov edi, OFFSET catalogo
    mov ecx, conteoNuevo
    imul ecx, TAM_REGISTRO          ; ECX = bytes por copiar
    cmp ecx, 0
    je caListo                      ; archivo vacio: no hay nada que copiar
caCopiarByte:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    loop caCopiarByte
caListo:
    mov eax, conteoNuevo
    mov numProductos, eax
    mov cambiosSinGuardar, 0
    mEscribir msgCargado
    ret

caFalloLectura:
    mov eax, manejadorArchivo
    call CloseFile
caInvalido:
    mEscribir msgArchivoInvalido
    ret
caNoExiste:
    mEscribir msgArchivoNoExiste
    ret
CargarCatalogo ENDP

END main
