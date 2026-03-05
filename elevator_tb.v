module elevator_tb;

// Inputs
reg clk;
reg reset;
reg emergency;
reg [4:0] btn;

// Outputs
wire [2:0] current_floor;
wire door;
wire [4:0] floor_req;
wire direction;
wire priority;

// Instantiate the Unit Under Test (UUT)
elevator_TEST10 uut (
    .clk(clk),
    .reset(reset),
    .emergency(emergency),
    .btn(btn),
    .current_floor(current_floor),
    .door(door),
    .floor_req(floor_req),
    .direction(direction),
    .priority(priority)
);

// Clock generation
always #1 clk = ~clk;

initial begin

// Initialize Inputs
clk = 0;
reset = 1;
emergency = 0;
btn = 5'b00000;

// Wait for reset
#20;
reset = 0;

// Step 1: Request to floor 1, 2, 4
#10 btn = 5'b10110;
#100 btn = 5'b00000;

// Wait enough time for requests to be served
#200;

// Step 2: Request to floor 2 and 3
#10 btn = 5'b01100;
#100 btn = 5'b00000;

// Wait enough time for requests to be served
#300;

// Step 3: Emergency trigger
#10 emergency = 1;
#50 emergency = 0;

// Wait to observe return to floor 1
#200;

$stop;

end

endmodule