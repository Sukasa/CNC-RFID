module CoverPlateHole(x, y) {
  translate([x, y, 17])
    union() {
      
      difference() {
        translate([-1, -1, -13])
          cube([8, 8, 15]);
        translate([3, 3, -17])
        cylinder(h=19, d=4, $fn=32);
      }  
    }
}

module CoverPlatePunch(x, y) {
  translate([x + 3, y + 3, 0]) 
    union() {
    cylinder(h=15, d=4, $fn=32);
    cylinder(h=3.5, d1 = 8, d2 = 4, $fn = 32);  
  }
}

module MountingHole(x, y) {
    translate([x, y, 0])
    cylinder(h=4, d1 = 4, d2 = 8, $fn = 32);  
}

translate([15, 33, 0]){
CoverPlateHole(52, -17);
CoverPlateHole(-12, -17);
CoverPlateHole(52, 67);
CoverPlateHole(-12, 67);
}

difference() {
cube([76, 120, 4]);
  
    CoverPlatePunch(67, 16);
    CoverPlatePunch(3, 16);
    CoverPlatePunch(67, 100);
    CoverPlatePunch(3, 100);

    MountingHole(10, 6);
    MountingHole(65, 6);
    MountingHole(10, 114);
    MountingHole(65, 114);
  
}
translate([0, 12, 4])

difference() {
  cube([76, 96, 15]);
  translate([3, 3, 0])
    cube([70, 90, 15]);
}

//translate([8, 16, 0])
//cylinder(h = 30, d = 4, $fn = 32);