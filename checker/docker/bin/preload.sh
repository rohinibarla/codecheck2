#!/bin/bash

# TODO get env dynamically
JAVA_HOME=/opt/jdk1.8.0
CODECHECK_HOME=/opt/codecheck
PATH=$PATH:$JAVA_HOME/bin
MAXOUTPUTLEN=10000

BASE=$(pwd)

# args: dir sourceDir sourceDir ...
function prepare {
  cd $BASE
  mkdir $1
  cd $1
  shift
  for d in $@ ; do cp -R $BASE/$d/* . 2>/dev/null ; done  
}

# args: dir language sourcefiles
function compile {
  DIR=$1
  shift  
  LANG=$1
  shift
  cd $BASE/$DIR
  mkdir -p $BASE/out/$DIR  
  case _"$LANG" in 
    _C)
      gcc -std=c99 -g -o prog -lm $@ > $BASE/out/$DIR/_compile 2>&1
      ;;
    _Cpp)
      g++ -std=c++17 -Wall -Wno-sign-compare -g -o prog $@ 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$DIR/_compile
      ;;
    _CSharp)
      mcs -o Prog.exe $@  > $BASE/out/$DIR/_compile 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$DIR/_compile
      ;;
    _Haskell)
      ghc -o prog $@ > $BASE/out/$DIR/_compile 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$DIR/_compile
      ;;
    _Java)
      javac -cp .:$BASE/use/\*.jar $@ > $BASE/out/$DIR/_compile 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$DIR/_compile
      ;;
    _JavaScript|_Matlab|_Racket)
      touch $BASE/out/$DIR/_compile
      ;;
    _Python)
      python3 -m py_compile $@ 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$DIR/_compile
      ;;
    _Scala)
      PATH=$PATH:$JAVA_HOME/bin $SCALA_HOME/bin/scalac $@ 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$DIR/_compile   
      ;;
    _SML)
      polyc -o prog $1 > $BASE/out/$DIR/_compile 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$DIR/_compile
      ;;
    *)  
      echo Unknown language $LANG > $BASE/out/$DIR/_errors 
      ;;                      
  esac 
  if [[ ${PIPESTATUS[0]} != 0 ]] ; then
    mv $BASE/out/$DIR/_compile $BASE/out/$DIR/_errors
    find -name *.class -exec rm {} \;
  fi  
}

# args: dir id timeout interleaveio language module arg1 arg2 ...
function run {
  DIR=$1
  shift
  ID=$1
  shift
  TIMEOUT=$1
  shift
  MAXOUTPUTLEN=$1
  shift  
  INTERLEAVEIO=$1
  shift  
  LANG=$1
  shift  
  MAIN=$1
  shift
  cd $BASE/$DIR
  mkdir -p $BASE/out/$ID
  case _"$LANG" in 
    _C|_Cpp|_Haskell|_SML)
      ulimit -d 100000 -f 1000 -n 100 -v 100000
      if [[ -e prog ]] ; then
        if [[ $INTERLEAVEIO == "true" ]] ; then
           timeout -v -s 9 ${TIMEOUT}s ${CODECHECK_HOME}/interleaveio.py ./prog $@ < $BASE/in/$ID 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$ID/_run
        else 
           timeout -v -s 9 ${TIMEOUT}s ./prog $@ < $BASE/in/$ID > $BASE/out/$ID/_run 2>&1
        fi
      fi
      ;;
    _Java)
      # ulimit -d 1000000 -f 1000 -n 100 -v 10000000
      if [[ -e  ${MAIN/.java/.class} ]] ; then
        if [[ $INTERLEAVEIO == "true" ]] ; then
          timeout -v -s 9 ${TIMEOUT}s ${CODECHECK_HOME}/interleaveio.py java -ea -Dcom.horstmann.codecheck -cp .:$BASE/use/\*.jar ${MAIN/.java/} $@ < $BASE/in/$ID 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$ID/_run
          cat hs_err*log >> $BASE/out/$ID/_run 2> /dev/null
          rm -f hs_err*log
        else
          timeout -v -s 9 ${TIMEOUT}s java -ea -Dcom.horstmann.codecheck -cp .:$BASE/use/\*.jar ${MAIN/.java/} $@ < $BASE/in/$ID 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$ID/_run
          cat hs_err*log >> $BASE/out/$ID/_run 2> /dev/null
          rm -f hs_err*log          
        fi
      fi
      ;;
    _CSharp)
      ulimit -d 10000 -f 1000 -n 100 -v 100000 
      if [[ -e Prog.exe ]] ; then    
        timeout -v -s 9 ${TIMEOUT}s mono Prog.exe $@  < $BASE/in/$ID 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$ID/_run
      fi
      ;;
    _JavaScript)
      # sed -i -e 's/^const //g' *CodeCheck.js # TODO Horrible hack for ancient node version--remove
      # TODO Check if still nodejs or node with Ubuntu 20.04
      ulimit -d 100000 -f 1000 -n 100 -v 1000000      
      timeout -v -s 9 ${TIMEOUT}s node $MAIN $@ < $BASE/in/$ID 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$ID/_run    
      ;;
    _Matlab)
      ulimit -d 10000 -f 1000 -n 100 -v 1000000
      NO_AT_BRIDGE=1 timeout -v -s 9 ${TIMEOUT}s octave --no-gui $MAIN $@ < $BASE/in/$ID 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$ID/_run    
      ;;
    _Python)
      ulimit -d 100000 -f 1000 -n 100 -v 100000
      if [[ -n $BASE/out/$DIR/_errors ]] ; then
        if [[ $INTERLEAVEIO == "true" ]] ; then
           timeout -v -s 9 ${TIMEOUT}s ${CODECHECK_HOME}/interleaveio.py python3 $MAIN $@ < $BASE/in/$ID 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$ID/_run
        else 
           timeout -v -s 9 ${TIMEOUT}s python3 $MAIN $@ < $BASE/in/$ID 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$ID/_run
        fi
      fi
      ;;
    _Racket)
      ulimit -d 100000 -f 1000 -n 100 -v 1000000 
      if grep -qE '\(define\s+\(\s*main\s+' $MAIN ; then
        timeout -v -s 9 ${TIMEOUT}s racket -tm $MAIN $@ < $BASE/in/$ID 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$ID/_run
      else
        timeout -v -s 9 ${TIMEOUT}s racket -t $MAIN $@ < $BASE/in/$ID 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$ID/_run
      fi    
      ;;
    _Scala)
      ulimit -d 1000000 -f 1000 -n 100 -v 10000000
      timeout -v -s 9 ${TIMEOUT}s $SCALA_HOME/bin/scala ${MAIN/.scala/} $@ < $BASE/in/$ID 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$ID/_run
      ;;
    *)  
      echo Unknown language $LANG > $BASE/out/$ID/_run 
      ;;                
  esac 
}

# args: dir timeout lang mainsource source2 source3 ... 
function unittest {
  DIR=$1
  shift
  TIMEOUT=$1
  shift  
  LANG=$1
  shift  
  MAIN=$1
  shift
  mkdir -p $BASE/$DIR
  mkdir -p $BASE/out/$DIR
  cd $BASE/$DIR
  case _"$LANG" in 
    _Java)
      javac -cp .:$BASE/use/\*:$CODECHECK_HOME/lib/* $MAIN $@ 2>&1 | head --lines $MAXOUTPUTLEN> $BASE/out/$DIR/_compile
      if [[ $? != 0 ]] ; then
        mv $BASE/out/$DIR/_compile $BASE/out/$DIR/_errors
      else
        ulimit -d 1000000 -f 1000 -n 100 -v 10000000
        timeout -v -s 9 ${TIMEOUT}s java -cp .:$BASE/use/\*:$CODECHECK_HOME/lib/\* org.junit.runner.JUnitCore ${MAIN/.java/} 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$DIR/_run
      fi
      ;;
    _Python)
      ulimit -d 100000 -f 1000 -n 100 -v 100000      
      timeout -v -s 9 ${TIMEOUT}s python3 -m unittest $MAIN 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$DIR/_run    
      ;;
    _Racket)
      ulimit -d 100000 -f 1000 -n 100 -v 1000000       
      timeout -v -s 9 ${TIMEOUT}s racket $MAIN 2>&1 | head --lines $MAXOUTPUTLEN > $BASE/out/$DIR/_run
      ;;
  esac     
}

function process {
  DIR=$1
  shift
  CMD=$1
  shift
  ARGS=$@
  cd $BASE/$DIR
  mkdir -p $BASE/out/$DIR
  case _"$CMD" in 
    _CheckStyle)
      java -cp $CODECHECK_HOME/lib/\* com.puppycrawl.tools.checkstyle.Main -c checkstyle.xml $ARGS > $BASE/out/$DIR/_run 2>&1
    ;;
  esac 
}

# args: runID file1 file2 ...
function collect {
  DIR=$1
  shift
  cd $BASE/$DIR
  cp $@ $BASE/out/$DIR
}
