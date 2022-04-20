#!/bin/sh
# inspired by https://interface31.ru/tech_it/2019/09/sozdanie-inkremental-nyh-i-differencial-nyh-arhivov-pri-pomoshhi-tar.html

# если нет параметров то берём текущюю дату
if [[ $# = 0 ]]; then
 DAY=$(date +%d)
 MONTH=$(date +%m)
 YEAR=$(date +%Y)
else
# иначе, принимаем разбираем значения, от
 while getopts d:m:y:htcA:F:v ARG
 do
 	case "${ARG}" in
		A) ARCHPATH=${OPTARG};;
		F) DEST=${OPTARG};;
		d) DAY=${OPTARG};;
		m) MONTH=${OPTARG};;
		y) YEAR=${OPTARG};;
		v) FLAG_VERBOSE=TRUE;;
		c) echo Create full backup; FLAG_FULL_BACKUP="TRUE";;
		t) echo "* Еmulation of archive creation"; FLAG_TEST="TRUE";;
		h) echo "Command help info"; exit 0;
	esac
 done
 if [[ -z $DAY ]]; then DAY=$(date +%d); fi
 if [[ -z $MONTH ]]; then MONTH=$(date +%m); fi
 if [[ -z $YEAR ]]; then YEAR=$(date +%Y); fi
fi

if [[ !( -d $ARCHPATH ) ]]; then
 >&2 echo "Directory for archivation $ARCHPATH is not found"
 echo "Try -h key for command help"
 exit 1
fi
if [[ !( -d $DEST ) ]]; then
 >&2 echo "Archive directory $DEST is not found"
 echo "Try -h key for command help"
 exit
fi

SDDIR=$DEST/.sync-data
DNAME=$(basename $DEST) 

if [[ (-n $FLAG_FULL_BACKUP) ]]; then
 rm $SDDIR/*;
fi

# удаляем все временные архивные данные
rm $SDDIR/*.snar-tmp 2>/dev/null

# проверка корректности данных и унификация формата
# подставляем ввод, вывод вместе с ошибками убираем
DAY=$(date +%d -d "$MONTH/$DAY/$YEAR")
MONTH=$(date +%m -d "$MONTH/$DAY/$YEAR")
YEAR=$(date +%Y -d "$MONTH/$DAY/$YEAR")
NUMWEEK=$(( ($(date +%-d -d "$MONTH/$DAY/$YEAR")-1)/7+1 )) #расчётно, приблизительно
date -d "$MONTH/$DAY/$YEAR" >/dev/null 2>&1
# проверяем результат выполения команды
if [[ $? != 0 ]]; then
 # print error message
 >&2 echo Date input incorrect
 exit 1
fi

echo "Using date: $DAY - $MONTH - $YEAR"

if [[ !(-d $DEST/.sync-data) ]]; then
 echo create archives data folder
 mkdir $DEST/.sync-data
fi

# если не существует годового инкрементного файла
if [[ !(-f $SDDIR/$DNAME-$YEAR.snar) ]]; then
 INC_FILE="$DNAME-$YEAR"
 # если существует инкрементный файла с прошлого года используем его
 if [[ -f $SDDIR/$DNAME-$(($YEAR-1)).snar ]]; then
  echo "copy last year list"
  cp "$SDDIR/$DNAME-$(( $YEAR-1 )).snar"  "$SDDIR/$INC_FILE.snar-tmp"
 fi
 rm $SDDIR/$DNAME-m*.snar 2>/dev/null
 echo "Creation of an annual backup"
elif [[ !(-f $SDDIR/$DNAME-m$MONTH.snar) ]]; then
 INC_FILE="$DNAME-m$MONTH"
 #проверка наличия месячного инкрементного файла
 FILE_MONTH=$(ls -1 $SDDIR/$DNAME-m*.snar 2>/dev/null |tail -n 1)
 if [[ -f $FILE-MONTH ]]; then
  echo "copy \"$FILE_MONTH\" month encrement list file"
  cp $FILE_MONTH $SDDIR/$INC_FILE.snar-tmp
 else
  # если нет месячного файла копируем его из годового
  echo "copy year encrement list file to month"
  cp $SDDIR/$DNAME-$YEAR.snar $SDDIR/$INC_FILE.snar-tmp
 fi
 rm $SDDIR/$DNAME-w*.snar 2>/dev/null
 echo "Creation of a monthly backup"
else
 INC_FILE="$DNAME-w$NUMWEEK"
 #проверка наличия недельного инкрементного файла
 FILE-WEEK=$(ls -1 $SDDIR/$DNAME-w*.snar 2>/dev/null |tail -n 1)
 if [[ $FILE_WEEK != $SDDIR/$INC_FILE.snar ]]; then
  if [[ -f $FILE-WEEK ]]; then
   echo "copy some week encrement list file"
   cp $FILE-WEEK $SDDIR/$INC_FILE.snar-tmp
  else
   # если нет недельного файла копируем его из месячного
   echo "copy month encrement list file to week"
   cp $SDDIR/$DNAME-m$MONTH.snar $SDDIR/$INC_FILE.snar-tmp
  fi
 fi
 echo "Creation of a weekly backup"
fi

# создаём архив
if [[ $FLAG_TEST = "TRUE" ]]; then
 echo tar --create \
 --absolute-names \
 --gzip \
 --file=$ARCHPATH/$INC_FILE.tgz-tmp \
 --ignore-failed-read \
 --listed-incremental=$SDDIR/$INC_FILE.snar-tmp \
 $DEST
 exit 0
elif [[ $FLAG_VERBOSE = "TRUE" ]]; then
 tar --create \
 --absolute-names \
 --verbose \
 --gzip \
 --file=$ARCHPATH/$INC_FILE.tgz-tmp \
 --ignore-failed-read \
 --listed-incremental=$SDDIR/$INC_FILE.snar-tmp \
 $DEST 
 FCREATE="TRUE"
else
 tar --create \
 --absolute-names \
 --gzip \
 --file=$ARCHPATH/$INC_FILE.tgz-tmp \
 --ignore-failed-read \
 --listed-incremental=$SDDIR/$INC_FILE.snar-tmp \
 $DEST
 FCREATE="TRUE"
fi

if [[ $FCREATE="TRUE" ]]; then
 echo "Backup was successfully created"
 mv -fv $SDDIR/$INC_FILE.snar-tmp $SDDIR/$INC_FILE.snar
 mv -fv $ARCHPATH/$INC_FILE.tgz-tmp $ARCHPATH/$INC_FILE.tgz
fi