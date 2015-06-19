More : https://forums.alliedmods.net/showthread.php?t=264581

Description:
[*]WARMUP TIME
-Player on spawn give Ak-47, m4a1, awp and deagle
-Auto Re-spawn
-Unlimited Clip Ammo
-No bomb
-Score every 0
[*]LIVE
10 players on server.
- Vote Map
PHP Code:
new const Change[][] = {  
    "de_dust2",  
    "de_inferno",  
    "de_nuke",  
    "de_train",  
    "de_tuscan",  
    "de_mirage" 
}  
-Change map and for 15 seconds start match.
-Balance team with skillpoints.(eg. CT= Rank#2#4#6#8#10 T=Rank #1#3#5#7#9)
*exec esl.cfg
-Team tag for CT=A T=B and skillpoints on name, if user admin put on name <a>.
- Hostname scores:
- Hud score every round first 10 seconds:

-2 Half auto start
-Automatic swapping of the teams.
-Automatic screenshots with scoreboard on half and end match.
-Logged in files: Team on Start and end Match, all activities.
Command (all command on say) : 
Player's commands:
.score -> Displays the team score.
.teams -> Displays team's.
.demome -> Start recording demo.
.skill -> Shows your Skillpoints.
.rankskill -> Show your current rank.
.topskill -> Show the Top15 players with the highest SkillPoints.
.add -> Adds yourself to a match.
.remove -> Remove yourself to a match.
.info [name] [command] -> Request player informations.(eg say .info player rate)
.ratio -> Shows your ratio.
Mini menu on M(Team Join):

Admin's Commands
.ready -> Start match.
.stop -> Stop match.
.pass [password] -> Set password server.
.map [mapname] -> Change map.
.restart -> Restart server.
.rr -> Round restart.
.pause -> Pause server/Unpause server.
.ff on -> Friendlyfire is ON!
.ff off -> Friendlyfire is OFF!
.ban [name] [time] -> Ban the user from the server.
.kick [name] [reason] -> Kick the user from the server.
.demo [name] [demoname] -> Start demo from a player.
