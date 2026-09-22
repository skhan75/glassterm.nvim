# Shell integration: the title follows cd, a failure turns the border red,
# and a re-run from the code reports its result without opening the float.
# Alt+<key> is Escape then the key: VHS's own Alt+ drops the Escape on macOS.
Output assets/shell.gif
Source demo/tapes/_settings.tape

Hide
Type "cd ~/app && nvim -u $GLASSTERM_ROOT/demo/init.lua server.lua" Enter
Sleep 2.5s
Show

Sleep 900ms
Escape
Type@1ms "t"
Sleep 700ms
Type "cd src" Sleep 300ms Enter
Sleep 1.2s
Type "cd .." Sleep 300ms Enter
Sleep 700ms
Type "./test.sh --fail" Sleep 300ms Enter
Sleep 2.4s
Type "./test.sh" Sleep 300ms Enter
Sleep 1.6s
Escape
Type@1ms "t"
Sleep 900ms
Type ":Glassterm rerun" Sleep 400ms Enter
Sleep 2.5s
