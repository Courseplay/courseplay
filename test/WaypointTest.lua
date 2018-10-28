package.path = package.path .. ";../?.lua"
package.path = package.path .. ";../course-generator/?.lua"
require("Waypoint")
require("geo")
require("courseGenerator")

waypoints = {{posX = 0, posZ = 0}, {posX = 2, posZ = 0}, {posX = 2, posZ = 2}}
course = Course:new(waypoints)
course:print()




