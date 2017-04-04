open Lwt


let temp_data () =
  let time = Unix.time () in
  Lwt_io.with_file ~mode:Lwt_io.Input "/sys/class/hwmon/hwmon1/temp1_input"
                  (Lwt_io.read ~count:7)
  >>= fun temp ->
  let temp = int_of_string (String.trim temp) in
  `O [("at", (`Float time)); ("temp", (Ezjsonm.int temp))]
  |> Ezjsonm.to_string |> return


let collector () =
  let open Redis_lwt.Client in
  let connection = connect {host="localhost";port=6379} in
  let rec temp_col conn =
    temp_data ()
    >>= fun data -> lpush conn "temp" data
    >>= fun _ -> Lwt_unix.sleep 30.
    >>= fun () -> temp_col conn
  in
  bind connection temp_col


let () =
  Lwt_main.run (collector ())
