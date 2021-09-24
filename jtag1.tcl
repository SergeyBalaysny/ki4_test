# получение подключенного blaster-a
set usb [lindex [get_hardware_names] 0]
set device_name [lindex [get_device_names -hardware_name $usb] 0]
puts "*************************"
puts "programming cable:"
puts $usb

#всего предусмотерно засылание дл 8 различный команд, а также 8 битный рагистр данныз для 
#каждой команды

#IR scan codes:  001 -> push (на той стороне по появлению кода комнады 001 происходит считываение данных из dr)

# процедура засылания команды команды (в ir) и данных (в dr) по интерфесу jtag  
proc push {value} {
    global device_name usb
    open_device -device_name $device_name -hardware_name $usb
   
	#преобразование параметра процедуры в набор массив бит
    if {$value > 256} {
        return "value entered exceeds 8 bits" }

    set push_value [int2bits $value]
    set diff [expr {8 - [string length $push_value]%8}]
    
    if {$diff != 8} {
        set push_value [format %0${diff}d$push_value 0] }

    puts $push_value

	 # передача команды 001 и байта данных по jtag в плис
    device_lock -timeout 10000
    #
    device_virtual_ir_shift -instance_index 0 -ir_value 1 -no_captured_ir_value             
    device_virtual_dr_shift -instance_index 0 -dr_value $push_value -length 8 -no_captured_dr_value
    device_unlock
    close_device
}


proc int2bits {i} {    
    set res ""
    while {$i>0} {
        set res [expr {$i%2}]$res
        set i [expr {$i/2}]}
    if {$res==""} {set res 0}
        return $res
}

puts "write board LEDs:"
push 0x00
push 0x01