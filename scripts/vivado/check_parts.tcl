puts "TOTAL PARTS COUNT: [llength [get_parts]]"
set families [lsort -unique [get_property FAMILY [get_parts]]]
puts "INSTALLED FAMILIES: $families"
puts "ALL BOARDS COUNT: [llength [get_board_parts]]"
if {[llength [get_board_parts]] > 0} {
    puts "SAMPLE BOARDS: [lrange [get_board_parts] 0 20]"
}
puts "PARTS MATCHING *zynq*: [get_parts *zynq*]"
puts "PARTS MATCHING *zu*: [get_parts *zu*]"
puts "PARTS MATCHING *7z*: [get_parts *7z*]"
puts "PARTS MATCHING *xc*: [lrange [get_parts *xc*] 0 20]"
exit
