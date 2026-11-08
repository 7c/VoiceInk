# No Python or Xcode needed to read the command list.
BEGIN {
    color = ENVIRON["NO_COLOR"] == "" && \
        (ENVIRON["COLOR"] == "always" || \
         (ENVIRON["COLOR"] != "never" && ENVIRON["TERM"] != "dumb" && system("test -t 1") == 0))
    if (color) {
        title = "\033[1;35m"
        target = "\033[36m"
        dim = "\033[2m"
        reset = "\033[0m"
    }
    printf "\n%sVoiceInk · offline development%s\n", title, reset
    print "Usage: make <action>"
}
/^##@ / {
    printf "\n%s%s%s\n", title, substr($0, 5), reset
}
/^[a-zA-Z0-9_-]+:.*## / {
    split($0, parts, /:.*## /)
    printf "  %s%-16s%s %s\n", target, parts[1], reset, parts[2]
}
END {
    printf "\n%sColor: automatic in terminals; COLOR=always, COLOR=never, or NO_COLOR=1.%s\n\n", dim, reset
}
