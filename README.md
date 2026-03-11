# FPGA Pac-Man
Developed with Ronit

We designed a simplified Pac-Man game using the VGA (Video Graphics Array) interface and user input from the buttons on the Basys 3 board (btnU, btnD, btnR, btnL). The user controls the yellow circular Pac-Man sprite using these 4 buttons representing the 4 directions. In addition, there is a red ghost sprite that chases the Pac-man. The goal of the game is to collect all power pellets (represented as white dots) on the map without being caught by the ghost.

## Design
1. pacman - The main control module for the entire design; it integrates the other modules and implements the full game.
    1. Integration of Other Modules
        1. Pixel Clock Divider is instantiated; its output is passed into vga_controller
        2. vga_controller is instantiated; it outputs video_on, Hsync, Vsync.
        3. map_data is instantiated; win_active is passed in and the wall variable (storing wall placements) is outputted
    2. Game Logic
        *  Movement (25 MHz)
            1. Pac-Man
                * Checks for input from the buttons and if the desired movement is possible (there are no obstructing walls). If so, moves Pac-man in that direction
            2. Ghost
                * Measure L1 distance to Pac-Man and take any non-obstructed step to decrease this distance. If it’s not possible to decrease the distance, move in any other possible direction
            3. Pellet Collection
                * As the pacman moves into coordinates occupied by the power pellets, the pellets are removed from the screen and an internal pellet counter is incremented.
            4. Win State
                * If the pellet counter reaches the initial pellet count (at game start), then the game ends, and a screen displaying the text “YOU WIN” is shown.
            5. Lose State
                * If the Ghost occupies the same space as the Pac-Man sprite at any time, the game freezes for 2 seconds and a black screen is displayed.
2. clk_divider
    * Outputs a clock that is ¼ the frequency of the input clock. In our case, the output clk is clk_25 (25 MHz) which is the clock that controls the update frequency of the VGA output.
3. vga_controller
    * Takes in clk_25 and outputs video_on, Hsync, Vsync. These outputs are used to display the game screen on the monitor and correctly place the sprites, walls, and pellets.
4. map_data
    * Stores the placement of the walls for the normal map and the win screen. Takes in the win_active variable; if true, the walls are assigned in accordance with the win screen array instead of the map array.

The red ghost sprite chases the Pac-man sprite by moving in a way to decrease the L1 distance (Manhattan distance) between it and Pac-man. Power pellets are represented as small white dots spaced out in reachable areas without

## Features
- Movement through button controls
- Wall collision detection for both sprites
- Red ghost autonomously chasing based on Pac-Man’s position
- Black screen when loss (ghost touches Pac-Man)
- Win screen when Pac-Man eats all the pellets
- Custom map!

## Demo Videos
- [Loss](https://drive.google.com/file/d/1runJoe3bCNemUorgy1mmqrUTU6B6BOLP/view?usp=drive_link)
- [Win](https://drive.google.com/file/d/1NtsWWGm1ZMho-HwlkcEurhe9tqG1jUOu/view?usp=drive_link)
