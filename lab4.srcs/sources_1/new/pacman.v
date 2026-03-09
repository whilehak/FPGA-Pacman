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

    //// --- CHANGE: pellet state memory ---
    reg pellet_map [0:19][0:14];

    integer i,j;
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

        //// --- CHANGE: place pellets ONLY where there are no walls ---
        for(i=0;i<20;i=i+1) begin
            for(j=0;j<15;j=j+1) begin
                pellet_map[i][j] = !wall_map[j][19-i];
            end
        end
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

    map_data render_map (.x(x), .y(y), .wall(wall));

/////////////////////////////////////////////////////////
//// PACMAN COLLISION (HITBOX REDUCED)
/////////////////////////////////////////////////////////

    wire can_move_up, can_move_down, can_move_left, can_move_right;
    wire move_u1, move_u2, move_d1, move_d2, move_l1, move_l2, move_r1, move_r2;

    //// --- CHANGE: collision reduced from 31/32 -> 27/28

    map_data p_up1 (.x(sx),      .y(sy - 1),  .wall(move_u1));
    map_data p_up2 (.x(sx + 27), .y(sy - 1),  .wall(move_u2));
    assign can_move_up = !move_u1 && !move_u2;

    map_data p_dn1 (.x(sx),      .y(sy + 28), .wall(move_d1));
    map_data p_dn2 (.x(sx + 27), .y(sy + 28), .wall(move_d2));
    assign can_move_down = !move_d1 && !move_d2;

    map_data p_lf1 (.x(sx - 1),  .y(sy),      .wall(move_l1));
    map_data p_lf2 (.x(sx - 1),  .y(sy + 27), .wall(move_l2));
    assign can_move_left = !move_l1 && !move_l2;

    map_data p_rt1 (.x(sx + 28), .y(sy),      .wall(move_r1));
    map_data p_rt2 (.x(sx + 28), .y(sy + 27), .wall(move_r2));
    assign can_move_right = !move_r1 && !move_r2;

/////////////////////////////////////////////////////////
//// GHOST
/////////////////////////////////////////////////////////

    reg [9:0] gx = 320, gy = 320;
    wire is_ghost;

    wire g_can_move_up, g_can_move_down, g_can_move_left, g_can_move_right;
    wire gm_u1, gm_u2, gm_d1, gm_d2, gm_l1, gm_l2, gm_r1, gm_r2;

    map_data g_up1 (.x(gx),      .y(gy - 1),  .wall(gm_u1));
    map_data g_up2 (.x(gx + 27), .y(gy - 1),  .wall(gm_u2));
    assign g_can_move_up = !gm_u1 && !gm_u2;

    map_data g_dn1 (.x(gx),      .y(gy + 28), .wall(gm_d1));
    map_data g_dn2 (.x(gx + 27), .y(gy + 28), .wall(gm_d2));
    assign g_can_move_down = !gm_d1 && !gm_d2;

    map_data g_lf1 (.x(gx - 1),  .y(gy),      .wall(gm_l1));
    map_data g_lf2 (.x(gx - 1),  .y(gy + 27), .wall(gm_l2));
    assign g_can_move_left = !gm_l1 && !gm_l2;

    map_data g_rt1 (.x(gx + 28), .y(gy),      .wall(gm_r1));
    map_data g_rt2 (.x(gx + 28), .y(gy + 27), .wall(gm_r2));
    assign g_can_move_right = !gm_r1 && !gm_r2;

/////////////////////////////////////////////////////////
//// MOVEMENT
/////////////////////////////////////////////////////////

    reg [1:0] ghost_tick = 0;

    always @(posedge clk25) begin

        m_cnt <= m_cnt + 1;
        ghost_tick <= ghost_tick + 1;

        if (m_cnt == 300000) begin
            m_cnt <= 0;

            if (btnU && sy > 0   && can_move_up)    sy <= sy - 1;
            if (btnD && sy < 448 && can_move_down)  sy <= sy + 1;
            if (btnL && sx > 0   && can_move_left)  sx <= sx - 1;
            if (btnR && sx < 608 && can_move_right) sx <= sx + 1;

            //// --- CHANGE: pellet eating ---
            pellet_map[(sx+16)>>5][(sy+16)>>5] <= 0;

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

/////////////////////////////////////////////////////////
//// PACMAN DRAW (RADIUS REDUCED)
/////////////////////////////////////////////////////////

    //// --- CHANGE: radius 16 -> 14

    wire [9:0] dist_x = (x >= sx + 16) ? (x - (sx + 16)) : ((sx + 16) - x);
    wire [9:0] dist_y = (y >= sy + 16) ? (y - (sy + 16)) : ((sy + 16) - y);

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

    assign vgaRed =
        (video_on && (is_pacman || is_ghost)) ? 4'b1111 : 4'b0000;

    assign vgaGreen =
        (video_on && is_pacman) ? 4'b1111 :
        (video_on && pellet_pixel) ? 4'b1111 :
        4'b0000;

    assign vgaBlue =
        (video_on && wall) ? 4'b1111 : 4'b0000;

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
    output wire wall
);

    reg [19:0] map [0:14];

    initial begin
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
    end

    assign wall = (x < 640 && y < 480) ?
                  map[y >> 5][19 - (x >> 5)] :
                  1'b0;

endmodule