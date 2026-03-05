module elevator_TEST10(
input wire clk,
input wire reset,
input wire emergency,            // Emergency switch input (active high)
input wire [4:0] btn,            // Push buttons for floors 0-4 (active high)

output reg [2:0] current_floor,
output reg door,                 // 1: open, 0: closed
output reg [4:0] floor_req,      // Internal request register
output reg direction,            // 1: up, 0: down
output reg priority              // 1: floor 2 request active
);

// Edge-detected button pulses
reg [4:0] btn_sync_0, btn_sync_1, btn_rising;
reg [4:0] btn_prev;

// FSM states
localparam IDLE         = 3'd0,
           MOVING_UP    = 3'd1,
           MOVING_DOWN  = 3'd2,
           DOOR_OPENING = 3'd3,
           DOOR_CLOSING = 3'd4,
           EMERGENCY    = 3'd5,
           RETURN_TO_F1 = 3'd6;

reg [2:0] state, next_state;
reg [2:0] target_floor, next_target_floor;
reg next_direction;

reg post_emergency;
integer i;

// Door timing
reg [23:0] door_timer;

parameter DOOR_OPEN_TIME  = 24'd10000000;
parameter DOOR_CLOSE_TIME = 24'd10000000;


// Button edge detection
always @(posedge clk or posedge reset) begin
    if (reset) begin
        btn_sync_0 <= 0;
        btn_sync_1 <= 0;
        btn_rising <= 0;
        btn_prev   <= 0;
    end
    else begin
        btn_sync_0 <= btn;
        btn_sync_1 <= btn_sync_0;
        btn_rising <= (~btn_prev) & btn_sync_1;
        btn_prev   <= btn_sync_1;
    end
end


// Floor 2 priority indicator
always @(*) begin
    priority = floor_req[2];
end


// Request register
always @(posedge clk or posedge reset) begin
    if (reset)
        floor_req <= 5'b0;

    else if (state != EMERGENCY && state != RETURN_TO_F1) begin
        floor_req <= (floor_req | btn_rising);

        if (state == DOOR_OPENING)
            floor_req <= floor_req & ~(5'b1 << current_floor);
    end
end


// FSM next-state logic
always @(*) begin

    next_state = state;
    next_target_floor = target_floor;
    next_direction = direction;
    door = 0;

    case(state)

        EMERGENCY: begin
            door = 1;
            next_state = (emergency) ? EMERGENCY : RETURN_TO_F1;
            next_target_floor = 3'd1;
        end


        RETURN_TO_F1: begin

            if (current_floor == 3'd1) begin
                door = 1;
                next_state = DOOR_CLOSING;
            end
            else begin
                door = 0;
                next_target_floor = 3'd1;

                if (current_floor < 3'd1) begin
                    next_direction = 1'b1;
                    next_state = MOVING_UP;
                end
                else begin
                    next_direction = 1'b0;
                    next_state = MOVING_DOWN;
                end
            end

        end


        IDLE: begin

            if (emergency)
                next_state = EMERGENCY;

            else if (floor_req[2] && current_floor != 3'd2) begin

                next_target_floor = 3'd2;
                next_direction = (current_floor < 3'd2);
                next_state = (current_floor < 3'd2) ? MOVING_UP : MOVING_DOWN;

            end

            else if (floor_req[current_floor]) begin
                next_state = DOOR_OPENING;
            end

            else if (|floor_req) begin

                next_target_floor = current_floor;

                for (i = 0; i < 5; i = i + 1)
                    if ((i > current_floor) && floor_req[i])
                        next_target_floor = i;

                if (next_target_floor != current_floor) begin
                    next_direction = 1'b1;
                    next_state = MOVING_UP;
                end

                else begin

                    for (i = 4; i >= 0; i = i - 1)
                        if ((i < current_floor) && floor_req[i])
                            next_target_floor = i;

                    if (next_target_floor != current_floor) begin
                        next_direction = 1'b0;
                        next_state = MOVING_DOWN;
                    end
                end

            end

        end


        MOVING_UP: begin
            next_direction = 1'b1;

            if (emergency)
                next_state = EMERGENCY;

            else if (current_floor + 1 == target_floor)
                next_state = DOOR_OPENING;

            else
                next_state = MOVING_UP;
        end


        MOVING_DOWN: begin
            next_direction = 1'b0;

            if (emergency)
                next_state = EMERGENCY;

            else if (current_floor - 1 == target_floor)
                next_state = DOOR_OPENING;

            else
                next_state = MOVING_DOWN;
        end


        DOOR_OPENING: begin

            door = 1;

            if (emergency)
                next_state = EMERGENCY;

            else if (door_timer < DOOR_OPEN_TIME)
                next_state = DOOR_OPENING;

            else
                next_state = DOOR_CLOSING;

        end


        DOOR_CLOSING: begin

            door = 0;

            if (emergency)
                next_state = EMERGENCY;

            else if (door_timer < DOOR_CLOSE_TIME)
                next_state = DOOR_CLOSING;

            else if (post_emergency && current_floor == 3'd1)
                next_state = IDLE;

            else if (floor_req[2] && current_floor != 3'd2) begin

                next_target_floor = 3'd2;
                next_direction = (current_floor < 3'd2);
                next_state = (current_floor < 3'd2) ? MOVING_UP : MOVING_DOWN;

            end

            else if (|floor_req)
                next_state = MOVING_UP;

            else
                next_state = IDLE;

        end

        default: next_state = IDLE;

    endcase

end



// FSM sequential update
always @(posedge clk or posedge reset) begin

    if (reset) begin

        state <= IDLE;
        current_floor <= 0;
        target_floor <= 0;
        direction <= 1'b1;
        post_emergency <= 0;
        door_timer <= 0;

    end

    else begin

        if (state != EMERGENCY && next_state == EMERGENCY)
            post_emergency <= 1;

        if ((state == RETURN_TO_F1 || state == DOOR_CLOSING) && current_floor == 3'd1)
            post_emergency <= 0;

        state <= next_state;
        target_floor <= next_target_floor;
        direction <= next_direction;

        if ((state == DOOR_OPENING && next_state == DOOR_OPENING) ||
            (state == DOOR_CLOSING && next_state == DOOR_CLOSING))
            door_timer <= door_timer + 1;
        else
            door_timer <= 0;


        case(state)

            MOVING_UP:
                if (current_floor < 4)
                    current_floor <= current_floor + 1;

            MOVING_DOWN:
                if (current_floor > 0)
                    current_floor <= current_floor - 1;

        endcase

    end

end

endmodule