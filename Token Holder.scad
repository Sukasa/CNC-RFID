module Peg() {
polyhedron([[0, -5, 0],  [4, -5, 0],  [0, 15, 0],  [4, 20, 0],
    
            [4, -5, 40], [4, 0, 50], [4, 5, 50], [4, 15, 40],
            [0, -5, 35], [0, 0, 45], [0, 5, 45], [0, 10, 35]],
    
            [[0,  1,  3,  2],[1,  4,  5,  6,  7,  3],[0, 2, 11, 10,  9,  8],
            [1,  0,  8,  4], [4,  8,  9,  5], [5,  9, 10,  6], [6, 10, 11,  7],
            [2,  3,  7, 11],], 10);
}

//MountStrut(0, -10);
//MountStrut(45, -10);

difference() {
    union() {
        difference(){
translate([-2, 2.5, 0])
    cube([6, 61, 14]);
translate([17, 32.5, 9])
    rotate([0, -20, 00])
            translate([0, 0, -10])
        cylinder(h=26, d=28, $fn=64);
        }

translate([4, 7.5, 0])
    Peg();
    
translate([4, 58.5, 0])
    mirror([0, 1, 0])
    Peg();
}

translate([-6, 10, 6])
    rotate([0, 90, 00])
        cylinder(h=20, d=5, $fn=32);

translate([-6, 55, 6])
    rotate([0, 90, 00])
        cylinder(h=20, d=5, $fn=32);

translate([5, 55, 6])
    rotate([0, 90, 0])
    cylinder(h=3.1, d1 = 5, d2 = 8, $fn = 32);

translate([5, 10, 6])
    rotate([0, 90, 0])
    cylinder(h=3.1, d1 = 5, d2 = 8, $fn = 32);
}

