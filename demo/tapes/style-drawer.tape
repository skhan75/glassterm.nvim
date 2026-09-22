# The drawer style: open, run the tests, hide.
# Alt+<key> is Escape then the key: VHS's own Alt+ drops the Escape on macOS.
Output assets/style-drawer.gif
Source demo/tapes/_settings.tape
Set Width 1000
Set Height 600
Set FontSize 15

Hide
Type "cd ~/app && GLASSTERM_DEMO_STYLE=drawer nvim -u $GLASSTERM_ROOT/demo/init.lua server.lua" Enter
Sleep 2.5s
Show

Sleep 900ms
Escape
Type@1ms "t"
Sleep 700ms
Type "./test.sh" Sleep 300ms Enter
Sleep 1.8s
Escape
Type@1ms "t"
Sleep 1.2s
