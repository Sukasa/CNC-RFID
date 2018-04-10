ScrewDiameter = 2;
ScrewWallThickness = 2;
ScrewHeight = 10;

module ScrewHole(x, y, z) {
translate([x, y, z])
difference() {
    cylinder(ScrewHeight, d=ScrewDiameter + (2 * ScrewWallThickness), $fn=128);
    translate([0, 0, -1])
        cylinder(ScrewHeight + 2, d=ScrewDiameter, $fn = 128);
};
}


module MountStrut(x, y) {
  translate([x, y, 0])
    difference() {
      cylinder(h=8, d=6, $fn=128);
      translate([0, 0, -1])
        cylinder(h=8, d=3, $fn=128);
    }    
}

module CoverPlateHole(x, y) {
  translate([x, y, 17])
    union() {
      
      difference() {
        translate([-1, -1, -17])
          cube([8, 8, 23]);
        translate([3, 3, -1])
        cylinder(h=8, d=4, $fn=128);
      }  
    }
}

// Mounting holes for electronics board
ScrewHole(0, 0);
ScrewHole(46, 0);
ScrewHole(0, 66);
ScrewHole(46, 66);

// Shell
translate([-15, -20, -2]) {
  difference() {
    union() {
      cube([76, 96, 25]);
    }
    
    translate([3, 3, 2])
      cube([70, 90, 25]);
      
    translate([15, 10, -2])
      cylinder(h=5, d=4, $fn=128);
    
    translate([60, 10, -2])
      cylinder(h=5, d=4, $fn=128);
    
    // Cable Entry
    translate([28, -3, 17])
    rotate([0, 90, 90])
    cylinder(h=7, d=5.6, $fn=8);
   
    translate([64, 50, -4])
      cylinder(h=15 , d=1.5, $fn=16);
  }
};

// Token Clip mounting holes
MountStrut(0, -10);
MountStrut(45, -10);

// Cable strain relief
translate([30, -17, 0])
  difference() {
    cube([6, 7, 22]);
    translate([-1, 0, 10])
      cube([8, 5.3, 10]);
    translate([-1, 0, 10])
      cube([8, 4, 13]);
  }


// Mounting bracket for RFID coil
translate([8, 4, 0])
    difference() {
        cube([31, 43, 4]);
        translate([2, 2, -1])
            cube([27, 39, 6]);
    };

// Cover plate screw holes
CoverPlateHole(52, -17);
CoverPlateHole(-12, -17);
CoverPlateHole(52, 67);
CoverPlateHole(-12, 67);