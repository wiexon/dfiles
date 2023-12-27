parse_args() {
  while getopts ":s:" opt; do
    case $opt in
      s)
        VARIABLE_INPUT="$OPTARG"
        echo $VARIABLE_INPUT
        ;;
      \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
      :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    esac
  done

  shift $((OPTIND-1))
}

parse_args "$@"
parse_args "$@"