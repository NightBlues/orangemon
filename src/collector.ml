open Lwt

let temp_path = "/sys/class/hwmon/hwmon1/temp1_input"
(* let temp_path = "/sys/class/hwmon/hwmon0/temp1_input" *)

external start_worker: unit -> unit = "start_worker_ml"
external get_times: unit -> int32 = "get_times_ml"

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
  let ping = get_times () |> Int32.to_int in
  `Assoc ["at", (`Float time); "delay", (`Int ping)]
  |> Yojson.Safe.to_string |> return

let converter temp =
  let temp = Yojson.Safe.from_string temp |> temp_t_of_yojson in
  match temp with
  | Ok temp -> `List [`Float temp.at; `Int temp.temp]
  | Error e -> failwith ("Error in temp data: " ^ e)

let collector redis_conn () =
  let conn = match !redis_conn with
    | None -> failwith "Connection to redis disappeared."
    | Some conn -> conn
  in
  start_worker ();
  let rec temp_col conn =
    temp_data ()
    >>= fun data -> Redis_lwt.Client.lpush conn "temp" data
    >>= fun _ -> return_unit
    >>= ping_data
    >>= fun data -> Redis_lwt.Client.lpush conn "pings" data
    >>= fun _ -> Lwt_unix.sleep 30.
    >>= fun () -> temp_col conn
  in
  temp_col conn
