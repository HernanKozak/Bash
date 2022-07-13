#!/bin/bash


ayuda(){
	echo "Argumentos:"
	echo ""
	echo " --dir [DIRECTORIO] --porc [NUMERO_ENTERO] --salida [ARCHIVO] --ext [ARCHIVO_CONFIG] [--comment | --sincom]"
	echo ""
	echo 'Este script comprueba la similitud entre archivos. Para eso compara el archivo contra el resto corroborando que si la similitud en número de líneas es mayor o igual al número pasado por parámetros el archivo se considera similar al otro.'
	echo ''
	echo 'Parametros:'
	echo ''
	echo '-h|--help|-? ----------------------- Muestra la ayuda'
	echo ''
	echo '--dir [DIRECTORIO]-----------------  Especifica el directorio a analizar (obligatorio)'
	echo ''
	echo '--porc ----------------------------  Porcentaje de similitud mínimo entre archivos'
	echo ''
	echo '--salida [ARCHIVO] ----------------  La información se guarda en el archivo especificado'
	echo ''
	echo '--ext -----------------------------  Archivo donde se encuentran las extensiones a comparar'
	echo ''
	echo '--coment --------------------------  Considera las líneas comentadas'
	echo ''
	echo '--sincoment ------------------------ No considera las lineas comentadas'

}


archivo_configuracion=""
directorio=""
con_lineas_comentadas=0
porcentaje=0
salida=""

if [[ $1 == "--help" ]]; then
	ayuda
	exit 1;
fi

if [[ $1 == "-h" ]]; then
	ayuda
	exit 1;
fi

if [[ $1 == "-?" ]]; then
	ayuda
	exit 1;
fi

i=0
argumentos=( "$@" )

while [[ "$i" -le "$#" ]];do
	case "${argumentos[$i]}" in
	  	"--dir") directorio="${argumentos[$i+1]}";;
	    "--coment") con_lineas_comentadas=1;;
	    "--sincom") if [[ "$con_lineas_comentadas" -eq 1 ]]; then
						echo "No pueden darse los parámetros --coment y --sincom a la vez"
						exit 1
					fi;;
	    "--porc") porcentaje="${argumentos[$i+1]}";;
		"--salida") salida="${argumentos[$i+1]}";;
		"--ext") extensiones="${argumentos[$i+1]}";;
  	esac
  	((i++))
done

if [[ ! -e "$directorio" ]]; then 
	echo "Escribe un directorio válido"
	exit 1;
fi

if [[ ! -d "$directorio" ]]; then 
	echo "No existe el directorio especificado"
	exit 1;
fi

if [[ ! -r "$directorio" ]]; then
	echo "No posee permisos de lectura"
	exit 1;
fi

reg_numeros='^[0-9]+$'
if ! [[ $porcentaje =~ $reg_numeros ]] ; then
   	echo "Debe ser un numero válido"
	exit 1;
fi

if [[ $porcentaje -gt 100 ]]; then
	echo "El porcentaje debe ser menor o igual que 100"
	exit 1;
fi

if [[ ! -f "$extensiones" ]]; then 
	echo "No existe el archivo de extensiones"
	exit 1;
fi

readPerExt=`stat -c %A "$extensiones" | sed 's/.\(.\).\+/\1/'`

if [[ "$readPerExt" == "-" ]]; then
	echo "No se tienen permiso de lectura sobre el archivo de extensiones"
	exit 1;
fi


declare -A cantidad_lineas_archivo
declare -A porcentajes_archivos
listadoCompleto=(`find $directorio -maxdepth 1 -type f`)

if [[ ! "$salida" == "" ]];then
	echo "" > "$salida"
else
	salida=/dev/stdout
fi

IFS=";"
exten=$(cat $extensiones)
declare -a extensionesArray=($exten)
unset IFS

declare -a listado

for x in ${extensionesArray[@]}; do
	listado+=()
	for archivo_actual in ${listadoCompleto[@]}; do
		if [[ $archivo_actual == *.$x ]]; then
			listado+=($archivo_actual)	
		fi
	done
	i=0
	echo "Comparamos los archivos con la extensión $x">>"$salida"
	for archivo_actual in ${listado[@]}; do

		#Si es el último elemento en el array salgo
		if [[ ! ${listado[$i+1]} ]]; then  
			unset 'listado[$i]'
			((i++))
			break
		fi

		if [[ "$con_lineas_comentadas" -eq 1 ]]; then
			cantidad_lineas_archivo_actual=$((`grep ^ "$archivo_actual" | wc -l`))
		else
			cantidad_lineas_archivo_actual=$((`grep ^[^#][^"//"] "$archivo_actual" | wc -l`))
		fi

		echo "#############################################################">>"$salida"
		echo "Archivo actual: "$archivo_actual"">>"$salida"
		echo "Cantidad de lineas: "$cantidad_lineas_archivo_actual"">>"$salida"
		echo "#############################################################">>"$salida"
		echo "Archivos similares: ">>"$salida"

		cantidad_informados=0
		for archivo_comparado in ${listado[@]};do
			if [[ ! "$archivo_actual" == "$archivo_comparado"  ]]; then

				if [[ "$con_lineas_comentadas" -eq 1 ]]; then
					cantidad_lineas_archivo_comparado=$((`grep ^ "$archivo_comparado" | wc -l`))
					diferencia=(`diff -a -B --suppress-common-lines -y "$archivo_actual" "$archivo_comparado" | wc -l`)
					
				else
					cantidad_lineas_archivo_comparado=$((`grep ^[^#][^"//"] "$archivo_comparado" | wc -l`))
					diferencia=(`diff -a -B --suppress-common-lines -y <(grep ^[^\#][^"//"] "$archivo_actual") <(grep ^[^\#][^"//"] "$archivo_comparado") | wc -l`)
				fi

				porcentaje_calculado=$(( ( $cantidad_lineas_archivo_actual-$diferencia )*100/$cantidad_lineas_archivo_actual))

				if [[ "$porcentaje_calculado" -ge "$porcentaje" ]];then
					echo "Archivo analizado: "$archivo_comparado"">>"$salida"
					echo "Cantidad de líneas de archivo: "$cantidad_lineas_archivo_comparado"">>"$salida"
					echo "Porcentaje de similitud: "$porcentaje_calculado"">>"$salida"
					echo "------------------------------------------------------------">>"$salida"
					((cantidad_informados++))
				fi
			fi
		done;
			if [[ "$cantidad_informados" -eq 0 ]];then
				echo "No hay archivos similares">>"$salida"
			fi
		unset 'listado[$i]'
		((i++))
	done
	echo "">>"$salida"
done

