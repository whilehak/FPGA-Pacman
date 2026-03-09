// Top-Level Module: pacman
module pacman (
    input wire clk,
    input btnU, btnD, btnL, btnR,
    output wire Hsync, Vsync,
    output wire [3:0] vgaRed, vgaGreen, vgaBlue
);

    wire clk25, video_on, wall, pellet;
    wire [9:0] x, y;

    reg [9:0] sx = 32, sy = 32;
    reg [19:0] m_cnt = 0;
    reg lose_active = 0;
    reg blackout = 0;
    reg [25:0] lose_cnt = 0;

    localparam [25:0] LOSE_WAIT_CYCLES = 26'd50000000; // 2 seconds at 25MHz

    //// --- CHANGE: pellet state memory ---
    reg pellet_map [0:19][0:14];

    //// --- CHANGE: track remaining pellets and win state ---
    reg [8:0] pellet_count = 0;
    wire win_active;
    assign win_active = (pellet_count == 0);

    integer i, j;
    integer pellet_init_count;
    reg [19:0] wall_map [0:14];
    initial begin
        //// --- CHANGE: local copy of wall map for pellet initialization ---
        wall_map[0]  = 20'b11111111111111111111;
        wall_map[1]  = 20'b10000000000000000001;
        wall_map[2]  = 20'b10111011101111011101;
        wall_map[3]  = 20'b10100011101000011101;
        wall_map[4]  = 20'b10111011101011011101;
        wall_map[5]  = 20'b10100010001001010101;
        wall_map[6]  = 20'b10100010001111010101;
        wall_map[7]  = 20'b10000000000000000001;
        wall_map[8]  = 20'b10111101100110111101;
        wall_map[9]  = 20'b10000101000010100001;
        wall_map[10] = 20'b10110101111110101101;
        wall_map[11] = 20'b10010000000000001001;
        wall_map[12] = 20'b10010111100111101001;
        wall_map[13] = 20'b10000000000000000001;
        wall_map[14] = 20'b11111111111111111111;

        //// --- CHANGE: initialize pellets and count them ---
        pellet_init_count = 0;
        for (i = 0; i < 20; i = i + 1) begin
            for (j = 0; j < 15; j = j + 1) begin
                pellet_map[i][j] = !wall_map[j][19-i];
                if (!wall_map[j][19-i])
                    pellet_init_count = pellet_init_count + 1;
            end
        end
        pellet_count = pellet_init_count;
    end

    // Clock Divider
    clk_divider pclk (.clk_in(clk), .clk_out(clk25));

    // VGA Controller
    vga_controller vga (
        .clk25(clk25),
        .Hsync(Hsync),
        .Vsync(Vsync),
        .video_on(video_on),
        .x(x),
        .y(y)
    );

    //// --- CHANGE: render normal map during play, win map after all pellets are collected ---
    map_data render_map (
        .x(x),
        .y(y),
        .win_active(win_active),
        .wall(wall)
    );

/////////////////////////////////////////////////////////
//// PACMAN COLLISION (HITBOX REDUCED)
/////////////////////////////////////////////////////////

    wire can_move_up, can_move_down, can_move_left, can_move_right;
    wire move_u1, move_u2, move_d1, move_d2, move_l1, move_l2, move_r1, move_r2;

    //// --- CHANGE: collision reduced from 31/32 -> 27/28
    //// --- CHANGE: collision checks always use the normal gameplay map ---

    map_data p_up1 (.x(sx),      .y(sy - 1),  .win_active(1'b0), .wall(move_u1));
    map_data p_up2 (.x(sx + 25), .y(sy - 1),  .win_active(1'b0), .wall(move_u2));
    assign can_move_up = !move_u1 && !move_u2;

    map_data p_dn1 (.x(sx),      .y(sy + 26), .win_active(1'b0), .wall(move_d1));
    map_data p_dn2 (.x(sx + 25), .y(sy + 26), .win_active(1'b0), .wall(move_d2));
    assign can_move_down = !move_d1 && !move_d2;

    map_data p_lf1 (.x(sx - 1),  .y(sy),      .win_active(1'b0), .wall(move_l1));
    map_data p_lf2 (.x(sx - 1),  .y(sy + 25), .win_active(1'b0), .wall(move_l2));
    assign can_move_left = !move_l1 && !move_l2;

    map_data p_rt1 (.x(sx + 26), .y(sy),      .win_active(1'b0), .wall(move_r1));
    map_data p_rt2 (.x(sx + 26), .y(sy + 25), .win_active(1'b0), .wall(move_r2));
    assign can_move_right = !move_r1 && !move_r2;

/////////////////////////////////////////////////////////
//// GHOST
/////////////////////////////////////////////////////////

    reg [9:0] gx = 320, gy = 320;
    wire is_ghost;

    wire g_can_move_up, g_can_move_down, g_can_move_left, g_can_move_right;
    wire gm_u1, gm_u2, gm_d1, gm_d2, gm_l1, gm_l2, gm_r1, gm_r2;

    //// --- CHANGE: ghost collision checks always use the normal gameplay map ---
    map_data g_up1 (.x(gx),      .y(gy - 1),  .win_active(1'b0), .wall(gm_u1));
    map_data g_up2 (.x(gx + 27), .y(gy - 1),  .win_active(1'b0), .wall(gm_u2));
    assign g_can_move_up = !gm_u1 && !gm_u2;

    map_data g_dn1 (.x(gx),      .y(gy + 28), .win_active(1'b0), .wall(gm_d1));
    map_data g_dn2 (.x(gx + 27), .y(gy + 28), .win_active(1'b0), .wall(gm_d2));
    assign g_can_move_down = !gm_d1 && !gm_d2;

    map_data g_lf1 (.x(gx - 1),  .y(gy),      .win_active(1'b0), .wall(gm_l1));
    map_data g_lf2 (.x(gx - 1),  .y(gy + 27), .win_active(1'b0), .wall(gm_l2));
    assign g_can_move_left = !gm_l1 && !gm_l2;

    map_data g_rt1 (.x(gx + 28), .y(gy),      .win_active(1'b0), .wall(gm_r1));
    map_data g_rt2 (.x(gx + 28), .y(gy + 27), .win_active(1'b0), .wall(gm_r2));
    assign g_can_move_right = !gm_r1 && !gm_r2;

/////////////////////////////////////////////////////////
//// MOVEMENT
/////////////////////////////////////////////////////////

    reg [1:0] ghost_tick = 0;
    wire ghost_hits_pacman;

    assign ghost_hits_pacman =
        (sx < gx + 28) &&
        (sx + 28 > gx) &&
        (sy < gy + 28) &&
        (sy + 28 > gy);

    always @(posedge clk25) begin
        //// --- CHANGE: freeze everything on the win screen ---
        if (win_active) begin
            m_cnt <= m_cnt;
            ghost_tick <= ghost_tick;
            sx <= sx;
            sy <= sy;
            gx <= gx;
            gy <= gy;
            lose_active <= 0;
            blackout <= 0;
            lose_cnt <= 0;
        end
        else if (!blackout && !lose_active && ghost_hits_pacman) begin
            lose_active <= 1;
            lose_cnt <= 0;
        end
        else if (lose_active) begin
            if (lose_cnt == LOSE_WAIT_CYCLES - 1) begin
                lose_active <= 0;
                blackout <= 1;
            end
            else begin
                lose_cnt <= lose_cnt + 1;
            end
        end
        else if (!blackout) begin
            m_cnt <= m_cnt + 1;
            ghost_tick <= ghost_tick + 1;

            if (m_cnt == 300000) begin
                m_cnt <= 0;

                if (btnU && sy > 0   && can_move_up)    sy <= sy - 1;
                if (btnD && sy < 448 && can_move_down)  sy <= sy + 1;
                if (btnL && sx > 0   && can_move_left)  sx <= sx - 1;
                if (btnR && sx < 608 && can_move_right) sx <= sx + 1;

                //// --- CHANGE: pellet eating + win tracking ---
                if (pellet_map[(sx+16)>>5][(sy+16)>>5]) begin
                    pellet_map[(sx+16)>>5][(sy+16)>>5] <= 0;
                    if (pellet_count > 0)
                        pellet_count <= pellet_count - 1;
                end

                if (ghost_tick != 0) begin
                    if (g_can_move_up && (gy > sy))
                        gy <= gy - 1;
                    else if (g_can_move_down && (gy < sy))
                        gy <= gy + 1;
                    else if (g_can_move_right && (gx < sx))
                        gx <= gx + 1;
                    else if (g_can_move_left && (gx > sx))
                        gx <= gx - 1;
                end
            end
        end
    end

/////////////////////////////////////////////////////////
//// PACMAN DRAW (RADIUS REDUCED)
/////////////////////////////////////////////////////////

    //// --- CHANGE: radius 16 -> 14

    wire [9:0] dist_x = (x >= sx + 16) ? (x - (sx + 16)) : ((sx + 16) - x);
    wire [9:0] dist_y = (y >= sy + 16) ? (y - (sy + 16)) : ((sy + 16) - y);

    wire is_pacman;
    assign is_pacman = (dist_x*dist_x + dist_y*dist_y <= 196);

/////////////////////////////////////////////////////////
//// PELLET RENDER
/////////////////////////////////////////////////////////

    //// --- CHANGE: pellet tile detection ---

    wire [4:0] tile_x = x >> 5;
    wire [3:0] tile_y = y >> 5;

    wire pellet_here = pellet_map[tile_x][tile_y];

    //// pellet center inside tile
    wire pellet_pixel =
        pellet_here &&
        ((x & 31) > 14 && (x & 31) < 18) &&
        ((y & 31) > 14 && (y & 31) < 18);

/////////////////////////////////////////////////////////
//// GHOST DRAW
/////////////////////////////////////////////////////////

    assign is_ghost = (x >= gx) && (x < gx + 32) && (y >= gy) && (y < gy + 32);

/////////////////////////////////////////////////////////
//// COLOR LOGIC
/////////////////////////////////////////////////////////

    //// --- CHANGE: when win_active, only the win map is shown ---
    assign vgaRed =
        (video_on && !blackout && !win_active && (is_pacman || is_ghost)) ? 4'b1111 :
        (video_on && !blackout && !win_active && pellet_pixel) ? 4'b1111 :
        4'b0000;

    assign vgaGreen =
        (video_on && !blackout && !win_active && is_pacman) ? 4'b1111 :
        (video_on && !blackout && !win_active && pellet_pixel) ? 4'b1111 :
        4'b0000;

    assign vgaBlue =
        (video_on && !blackout && wall) ? 4'b1111 :
        (video_on && !blackout && !win_active && pellet_pixel) ? 4'b1111 :
        4'b0000;

endmodule

/////////////////////////////////////////////////////////
//// CLOCK DIVIDER
/////////////////////////////////////////////////////////

module clk_divider (
    input wire clk_in,
    output wire clk_out
);
    reg [1:0] clk_div = 0;
    always @(posedge clk_in) clk_div <= clk_div + 1;
    assign clk_out = clk_div[1];
endmodule

/////////////////////////////////////////////////////////
//// VGA CONTROLLER
/////////////////////////////////////////////////////////

module vga_controller (
    input wire clk25,
    output wire Hsync, Vsync, video_on,
    output wire [9:0] x, y
);

    parameter H_VISIBLE = 640, H_FRONT = 16, H_SYNC = 96, H_BACK = 48, H_TOTAL = 800;
    parameter V_VISIBLE = 480, V_FRONT = 10, V_SYNC = 2, V_BACK = 33, V_TOTAL = 525;

    reg [9:0] h_count = 0, v_count = 0;

    always @(posedge clk25) begin
        if (h_count == H_TOTAL - 1) begin
            h_count <= 0;
            if (v_count == V_TOTAL - 1)
                v_count <= 0;
            else
                v_count <= v_count + 1;
        end
        else
            h_count <= h_count + 1;
    end

    assign Hsync = ~((h_count >= H_VISIBLE + H_FRONT) &&
                     (h_count < H_VISIBLE + H_FRONT + H_SYNC));

    assign Vsync = ~((v_count >= V_VISIBLE + V_FRONT) &&
                     (v_count < V_VISIBLE + V_FRONT + V_SYNC));

    assign video_on = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);

    assign x = h_count;
    assign y = v_count;

endmodule

/////////////////////////////////////////////////////////
//// MAP DATA
/////////////////////////////////////////////////////////

module map_data (
    input wire [9:0] x, y,
    //// --- CHANGE: select between gameplay map and win map ---
    input wire win_active,
    output wire wall
);

    reg [19:0] map [0:14];
    reg [19:0] win_screen[0:14];

    initial begin
        //// --- CHANGE: normal gameplay map ---
        map[0]  = 20'b11111111111111111111;
        map[1]  = 20'b10000000000000000001;
        map[2]  = 20'b10111011101111011101;
        map[3]  = 20'b10100010101000010101;
        map[4]  = 20'b10111011101011011101;
        map[5]  = 20'b10100010001001010101;
        map[6]  = 20'b10100010001111010101;
        map[7]  = 20'b10000000000000000001;
        map[8]  = 20'b10111101100110111101;
        map[9]  = 20'b10000101000010100001;
        map[10] = 20'b10110101111110101101;
        map[11] = 20'b10010000000000001001;
        map[12] = 20'b10010111100111101001;
        map[13] = 20'b10000000000000000001;
        map[14] = 20'b11111111111111111111;

        //// --- CHANGE: win screen map ("YOU WIN") using 1s as letters ---
        win_screen[0]  = 20'b11111111111111111111;
        win_screen[1]  = 20'b00000000000000000000;
        win_screen[2]  = 20'b01000101111101000100;
        win_screen[3]  = 20'b00101001000101000100;
        win_screen[4]  = 20'b00010001000101000100;
        win_screen[5]  = 20'b00010001000101000100;
        win_screen[6]  = 20'b00010001111101111100;
        win_screen[7]  = 20'b00000000000000000000;
        win_screen[8]  = 20'b01000101111101000100;
        win_screen[9]  = 20'b01010100010001100100;
        win_screen[10] = 20'b01010100010001010100;
        win_screen[11] = 20'b01101100010001001100;
        win_screen[12] = 20'b01000101111101000100;
        win_screen[13] = 20'b00000000000000000000;
        win_screen[14] = 20'b11111111111111111111;
    end
    
    //// --- CHANGE: use win_screen only after all pellets are collected ---
    assign wall = (x < 640 && y < 480) ?
                  (win_active ? win_screen[y >> 5][19 - (x >> 5)] :
                                map[y >> 5][19 - (x >> 5)]) :
                  1'b0;

endmodule