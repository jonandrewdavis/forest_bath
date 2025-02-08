
# ForestBath Tech Demo

### ForestBath is a multiplayer souls-ish game about pulling a cart through a forest.

It is personal project, not intended for distribution. It's for learning purposes and to play with friends.

- Procedually generated terrain / forest
- A shop with a wide arrange of weapons with combo attacks
- Enemies & encounters!

![A character standing in the forest bath game](ForestBath1.png)

#### Videos

- [ForestBath Playtest Video 1 (30s)](https://www.youtube.com/watch?v=_oQAMMXPlEU)
- [ForestBath Playtest Video 2 (1 min)](https://www.youtube.com/watch?v=scz4cNi1vlI) 

Note: My capture settings were wrong, resulting in very low-res gameplay. Network settings were poor too.

### Assets Used & Open Source projects referenced

This project is cobbled together from a number of open source projects & assets. This is a non-comprehensive list of major influences or sources:

- [Cat's Godot 4 Souls-Like Template & Asset Pack](https://github.com/catprisbrey/Cats-Godot4-Modular-Souls-like-Template)
    - An incredible starter kit. Includes the foundational player controller, weapon system, animations, enemy logic. 
    - I heavily modified this and converted to multiplayer.
- [2Retr0's GodotGrass](https://github.com/2Retr0/GodotGrass)
- [Traveling Trees - Explaining My Multimesh Instancer / Godot 4 Tutorial ](https://www.youtube.com/watch?v=79sgK0rxNwk)
- [netfox - A set of addons for responsive online games](https://github.com/foxssake/netfox)

Assets:

- Character models are from Mixamo (eww adobe) https://www.mixamo.com/
- Character animations are from Mixamo 
   - Converted with much effort to root motion
- Environment assets:
    - Grass is [2Retr0's GodotGrass](https://github.com/2Retr0/GodotGrass)
    - Trees are Arboles from [elbolilloduro](https://elbolilloduro.itch.io/)'s itch.io
- Weapons / Objects:
    - Too many to list right now, but most are from [itch](https://itch.io/) and [cgtrader](https://www.cgtrader.com) or https://poly.pizza/


TODO: Will do a more comprehensive thanks and acknowledgement when complete. 

### Instructions:

Clone the project git or download the windows release. NOTE: Host is render disabled!!! Run a second copy to join on the same machine you host from.

- Host:
    - In the Remote tab:
    - Click Connect (connects to noray)
    - Copy the id (send to friends)  
    - Click Host

- Join:
    - In the Remote tab:
    - Click Connect (connects to noray)
    - Paste the id (from above)
    - Click Join

Can also debug -> two local instances and do Local, host on 1, join on the other (Remember: the host will disable rendering)

Hit "ESC" or "TAB" to see controls.
