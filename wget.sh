function __wget() {
    : ${DEBUG:=0}
    local URL=$1
    local tag="Connection: close"

    if [ -z "${URL}" ]; then
        printf "Usage: %s \"URL\" [e.g.: %s http://www.google.com/]" \
               "${FUNCNAME[0]}" "${FUNCNAME[0]}"
        return 1;
    fi  
    read proto server path <<<$(echo ${URL//// })
    local SCHEME=${proto//:*}
    local PATH=/${path// //} 
    local HOST=${server//:*}
    local PORT=${server//*:}
    if [[ "$SCHEME" != "http" ]]; then
        printf "sorry, %s only support http\n" "${FUNCNAME[0]}"
        return 1
    fi  
    [[ x"${HOST}" == x"${PORT}" ]] && PORT=80
    [[ $DEBUG -eq 1 ]] && echo "SCHEME=$SCHEME" >&2
    [[ $DEBUG -eq 1 ]] && echo "HOST=$HOST" >&2
    [[ $DEBUG -eq 1 ]] && echo "PORT=$PORT" >&2
    [[ $DEBUG -eq 1 ]] && echo "PATH=$PATH" >&2

    exec 3<>/dev/tcp/${HOST}/$PORT
    if [ $? -ne 0 ]; then
        return $?
    fi  
    echo -en "GET ${PATH} HTTP/1.1\r\nHost: ${HOST}\r\n${tag}\r\n\r\n" >&3
    if [ $? -ne 0 ]; then
        return $?
    fi  
    # 0: at begin, before reading http response
    # 1: reading header
    # 2: reading body
    local state=0
    local num=0
    local code=0
    while read line; do
        num=$(($num + 1))
        # check http code
        if [ $state -eq 0 ]; then
            if [ $num -eq 1 ]; then
                if [[ $line =~ ^HTTP/1\.[01][[:space:]]([0-9]{3}).*$ ]]; then
                    code="${BASH_REMATCH[1]}"
                    if [[ "$code" != "200" ]]; then
                        printf "failed to wget '%s', code is not 200 (%s)\n" "$URL" "$code"
                        exec 3>&-
                        return 1
                    fi
                    state=1
                else
                    printf "invalid http response from '%s'" "$URL"
                    exec 3>&-
                    return 1
                fi
            fi
        elif [ $state -eq 1 ]; then
            if [[ "$line" == $'\r' ]]; then
                # found "\r\n"
                state=2
            fi
        elif [ $state -eq 2 ]; then
            # redirect body to stdout
            # TODO: any way to pipe data directly to stdout?
            echo "$line"
        fi
    done <&3
    exec 3>&-
}