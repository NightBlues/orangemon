open Lwt

let temp_path = "/sys/class/hwmon/hwmon1/temp1_input"
(* let temp_path = "/sys/class/hwmon/hwmon0/temp1_input" *)

external start_worker: unit -> unit = "start_worker_ml"
external get_times: unit -> int = "get_times_ml"

type temp_t = {
    at: float;
    temp: int;
  } [@@deriving yojson]

let temp_data () =
  let time = Unix.time () in
  Lwt_io.with_file ~mode:Lwt_io.Input temp_path
                   (Lwt_io.read ~count:7)
  >>= fun temp ->
  let temp = int_of_string (String.trim temp) in
  let data = {at=time;temp=temp} in
  temp_t_to_yojson data |> Yojson.Safe.to_string |> return

let ping_data () =
  let time = Unix.time () in
  let ping = get_times () in
  `Assoc ["at", (`Float time); "delay", (`Int ping)]
  |> Yojson.Safe.to_string |> return

let converter_temp temp =
  let temp = Yojson.Safe.from_string temp |> temp_t_of_yojson in
  match temp with
  | Ok temp -> `List [`Float temp.at; `Int temp.temp]
  | Error e -> failwith ("Error in temp data: " ^ e)

let converter_ping ping =
  match Yojson.Safe.from_string ping with
  | `Assoc ["at", (`Float at); "delay", (`Int delay)] -> `List [`Float at; `Int delay]
  | _ -> failwith ("Error in ping data " ^ ping)

let collector redis_conn () =
  start_worker ();
  let rec loop () =
    let%lwt () = Lwt_unix.sleep 30. in
    let%lwt data = temp_data () in
    let%lwt _ = Lwt_pool.use redis_conn (fun conn ->
                               Redis_lwt.Client.lpush conn "temp" data) in
    let%lwt data = ping_data () in
    let%lwt _ = Lwt_pool.use redis_conn (fun conn ->
                               Redis_lwt.Client.lpush conn "pings" data) in
    loop ()
  in
  loop ()
