# Toggle, run something, hide, come back instantly, zoom.
# Alt+<key> is Escape then the key: VHS's own Alt+ drops the Escape on macOS.
Output assets/hero.gif
Source demo/tapes/_settings.tape

Hide
Type "cd ~/app && nvim -u $GLASSTERM_ROOT/demo/init.lua server.lua" Enter
Sleep 2.5s
Show

Sleep 1.2s
Escape
Type@1ms "t"
Sleep 900ms
Type "./test.sh" Sleep 400ms Enter
Sleep 1.6s
Escape
Type@1ms "t"
Sleep 1.4s
Escape
Type@1ms "t"
Sleep 1.2s
Escape
Type@1ms "z"
Sleep 1.4s
Escape
Type@1ms "z"
Sleep 900ms
Escape
Type@1ms "t"
Sleep 1.2s
