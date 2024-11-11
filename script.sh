#!/usr/bin/expect -f

proc check_mac_address {mac_address} {
    set url "https://api.macvendors.com/$mac_address"
    set response ""
    after 800
    set response [exec curl -s $url]
    puts "Response for MAC address $mac_address: $response"
    if {[string match "*Routerboard.com*" $response]} {
        set mk_mac_file "macs_mk.txt"
        set mk_mac_id [open $mk_mac_file "a"]
        puts $mk_mac_id $mac_address
        close $mk_mac_id
    }
}

set switch_username "brunovsky"
set switch_password ""
set enable_password "3tch"
set log_dir "logs"

exec mkdir -p $log_dir
set switch_file [open "switches.txt" r]
set switches [split [read $switch_file] "\n"]
close $switch_file
set output_file "macs.txt"
set output_id [open $output_file "a"]

foreach switch_ip $switches {
    set switchname [string map {.net.e-net.sk ""} $switch_ip]
    set log_file "$log_dir/$switchname.log"

    spawn ssh -o StrictHostKeyChecking=no $switch_username@$switch_ip

    expect {
        "Password:" {
            send "$switch_password\r"
            exp_continue
        }
        "ssh: connect to host $switch_ip port 22: Network is unreachable" {
            puts "Error: Unable to connect to $switch_ip. Skipping..."
            continue
        }
        -re {[>#]} {
            log_file -a $log_file
            send "enable\r"
            expect {
                "Password:" {
                    send "$enable_password\r"
                    exp_continue
                }
                -re {[>#]} {
                    send "terminal length 0\r"
                    expect -re {[>#]}
                    send "show ip dhcp snooping binding vlan 60\r"
                    expect {
                        -re {(\S\S:\S\S:\S\S:\S\S:\S\S:\S\S)} {
                            set mac_address $expect_out(1,string)
                            puts $output_id $mac_address
                            exp_continue
                        }
                        -re {--More--} {
                            send " "
                            exp_continue
                        }
                        -re "Total number of bindings: (\d+)" {
                            break
                        }
                    }
                }
            }
        }
    }
    log_file
    send "exit\r"
    expect eof
}
close $output_id

set macs_file [open "macs.txt" r]
while {[gets $macs_file mac_address] != -1} {
    check_mac_address $mac_address
}
close $macs_file
