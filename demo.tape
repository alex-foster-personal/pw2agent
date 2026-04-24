Output demo.gif
Set FontSize 14
Set Width 800
Set Height 420
Set Theme "Catppuccin Frappe"
Set WindowBar Colorful
Set Padding 20

Type "pw2agent --help"
Sleep 300ms
Enter
Sleep 2000ms

Hide
Type "printf '%s' 'hunter2' | base64 > ~/.demo_pw && chmod 600 ~/.demo_pw"
Enter
Sleep 300ms
Show

Sleep 500ms
Type "# secret stashed — clipboard NOTE:"
Enter
Sleep 300ms
Type "cat << 'NOTE'"
Enter
Type "NOTE FOR AGENT — secret handoff"
Enter
Type "  Label:   demo"
Enter
Type "  File:    ~/.demo_pw    (mode 600, base64-encoded)"
Enter
Type "  Read:    PWB64=$(base64 -d < ~/.demo_pw | tr -d '\n')"
Enter
Type "  Delete:  rm -f ~/.demo_pw"
Enter
Type "NOTE"
Enter
Sleep 2500ms

Hide
Type "rm -f ~/.demo_pw"
Enter
Show
